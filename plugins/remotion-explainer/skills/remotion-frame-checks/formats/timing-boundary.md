# Timing boundary

A line, a dot, a piece of text, a shadow, or a mask edge that shows for one frame where an element starts or ends breaks the picture and its meaning, even when nobody notices it at normal speed.
This contract checks those frames by machine.

## Every timed element starts and ends at zero

Give every path, connector, mask, text, badge, and scene layer that comes and goes an ID and the frames it shows.
At a progress of 0, its opacity, drawn length, mask opening, and visible pixels are all 0.
A progress of 0 with another SVG attribute or a shadow still showing is not allowed.

## Render the frames around each boundary

For each frame `F` where an element starts or ends, render at least `F-2`, `F-1`, `F`, `F+1`, and `F+2` in a row.
The entry, turn, and exit of the whole scene do not replace them.
Keep the list of boundary frames and element IDs, with the results, in `out/review/temporal-boundary-audit.json`.

Render each element alone on the background when you can, so its pixels are the only ones that differ from the background.
When you cannot, compare the region of the element with the frame just before and count the pixels that changed without being allowed to.

## What counts as an issue

| Rule | Means |
|---|---|
| `premature-visible-pixels` | Pixels show at or before the start frame |
| `late-visible-pixels` | Pixels show at or after the end frame |
| `short-lived` | The element shows for three frames or fewer and hides again, with no meaning |
| `flicker` | The element hides and shows again while it enters or exits |
| `missing-boundary-frame` | One of the frames from `F-2` to `F+2` was not given |

Also look for a filter, a shadow, or a pseudo-element that stays after the layer's opacity reaches 0, and for the end of a dashed path that shows when the dash offset wraps around.

## Running the check

Run the `check-timing-boundary` check of this skill with the background color, the boundary, and the frames:

```bash
node <check-timing-boundary> --background '#F4F5F1' --start 267 --element parcel-path \
  --out out/review/temporal-boundary-audit.json \
  265=out/review/temporal/frame-0265.png 266=out/review/temporal/frame-0266.png \
  267=out/review/temporal/frame-0267.png 268=out/review/temporal/frame-0268.png \
  269=out/review/temporal/frame-0269.png
```

Give `--end` instead of `--start` for the frame where an element ends.
A pixel counts as visible when its alpha is above 0.02 and one of its channels differs from the background by more than 3.
The check reads 8-bit, non-interlaced PNGs, which is what Remotion renders, and records the SHA-256 of the frames it read.

## SVG paths that draw in

Do not combine a fixed pixel `strokeDasharray` with a guessed path length.
Use `pathLength="1"` with dashes from 0 to 1, or the real length from `@remotion/paths`.
At a progress of 0, set the opacity to 0 as well instead of relying on the dashes, and show the whole path only at a progress of 1.

## Before showing a candidate

Show a video as a candidate only when `temporal-boundary-audit.json` belongs to the current source and every boundary reports no issue.
Watching the video adds to this check; it does not replace it.
