# Layout rules (drawn from defects that were pointed out)

Check the slides against this list before building them and after rendering them.
Every item is a defect that was pointed out in a real deck; none was written by guess.

`scripts/audit.mjs` checks the items a machine can see. Items it cannot see say "by eye".

**When a section is added, add a check to `audit.mjs` in the same change for whatever a machine can see.**
A rule without a check is pointed out again next time: commas in headings, spaces around Latin letters, small text, and small screenshots were written as rules and not one was stopped until checks existed.

| Section | Check |
|---|---|
| Text size | `text is too small` |
| Headings (punctuation) | `heading punctuation` |
| No spaces around Latin letters and digits | `space around Latin letters and digits` |
| Fit an svg in its frame | `outside the slide` |
| Frames and text | `text is cut off` |
| Cards that do not fit their container | `text and screenshots overlap` |
| Empty space in a card | `uses only N% of the height` |
| Show only the main part of a screenshot, enlarged | `screenshot is too small` (the scale and the direction to leave the slide are by eye) |
| Render the sources of screenshots at 4x | `screenshot is too coarse` |
| Do not stick text to the bottom edge | `text sits on the bottom margin` |
| `writing-rules.md`, "Do not call one thing by different words" | `banned word` |
| `writing-rules.md`, "End explanations as sentences" | `explanation does not end as a sentence` |
| `writing-rules.md`, "Do not leave one letter on the last line" | `last line of a wrapped explanation is too short` and `katakana word split across lines` |
| Make icons parts that take no coordinates | By eye |
| Take icons from a free icon set | By eye |
| Enlarge only the container of an icon | `icon spills out of its card` (the room comes from a formula) |
| Do not put a figure inside a figure | By eye |
| Icon frames, the center of a figure, the role of a figure | By eye |
| The gap below an icon for its name | By eye (the gap comes from a formula) |
| Add a screenshot to a slide of text only | By eye |
| Match a figure's viewBox to its frame | By eye (measure the height left over) |
| Measure what grows when a slide has height left over | By eye (measure the flex-grow of the frame's children) |
| Center a frame's name on its width | By eye |
| Center the content of a card | By eye |
| Text in a figure stays in its box, and text stays above its rule | `text in a figure spills out of its box` and `text runs below its rule` |

## Text size

Slides are 1920 x 1080. At that size, text under 22px cannot be read.

| Use | Minimum |
|---|---|
| Explanations, bullets, table cells | 22px |
| Small labels, numbers, units | 21px |
| Small labels above headings | 21px |

Write nothing at 20px or less.

## Headings

In Japanese headings, put no period at the end and **no comma (、) inside**.
The checks read the Japanese marks.

A comma is wanted when one heading holds two things.
If the heading does not read without the comma, shorten it or split it into two lines.

| Before | After |
|---|---|
| "Three things signing needs, all outside the company" | "Everything signing needs is outside the company" |
| "Whether to connect this app, decided once by a person" | "A person decides once whether to connect this app" |

Split a heading into lines **only when two sentences stand side by side**. Do not cut one sentence in the middle: the first line then ends half said and floats.

| Form | Example | Lines |
|---|---|---|
| Two sentences | "Two entrances / One check" | 2 |
| A pair of contrasting phrases | "Write what may pass first / Pass nothing that is not written" | 2 |
| One sentence | "Let the agent sign without handing over the key" | 1 |
| One sentence cut | "Let the agent sign / without handing over the key" | Wrong |

When a line runs over 26 Japanese characters, first see whether it can become two sentences, and use two lines only when it cannot.
At 62px on a 1920px slide, 24 characters fit on one line at about 1500px; do not split mechanically because a reference deck uses two lines.

## No spaces around Latin letters and digits

In Japanese text, put no space before or after Latin letters and digits: on a slide the text looks scattered, and fewer characters fit on a line.

Spaces stay in two places only: between two Latin words (`Turnkey CDP`), and around the middle dot that lists items in parallel.

## Fit an svg in its frame

An `svg` given only a width takes its height from the `viewBox`'s aspect ratio. When it is taller than its frame, the picture is cut. `height: auto` does not help, for the same reason.

Do both of these:

- Place it in the frame with `position: absolute`, and give `top` and `height` explicitly (`height: calc(100% - margin)`)
- Give the `svg` `preserveAspectRatio="xMidYMid meet"`

Take the frame's height from the `viewBox`'s ratio. With a `viewBox` of 322 x 216 and a frame 500px wide, the frame needs at least 336px of height.

The check is "svg runs below its parent" under `outside the slide`.

## Make icons parts that take no coordinates

An icon written as a function of x and y makes every caller set coordinates by hand. They drift whenever a container's size changes and land on labels and frames; three slides overlapped that way.

Draw each icon once in one coordinate system, as an independent `svg` with a `viewBox`.
From an icon set, use the set's coordinate system (24 x 24 for `lucide`).
The container (`flex` or `grid`) decides the place; the caller passes only the size and the color.

```
mark("key", color, 78)          // Right: no coordinates
MARKS.key(73, 100, color, 3.4)  // Wrong: the caller sets coordinates
```

A figure of boxes and lines drifts less when the boxes are HTML (`flex` / `grid`) than when they are placed by coordinates in an `svg`. Make only the lines `svg`.

## Take icons from a free icon set

Do not draw `path`s by hand: across 15 icons the stroke widths and corner radii drift, and the icons alone look amateur.

**Look at the product's `package.json` first.** When the screens already use a set, use it: the deck's pictures then match the product's screens.

Otherwise take a set with a permissive license.

| Set | License | Form |
|---|---|---|
| `lucide` | ISC | 24 x 24 line icons, more than 1,500 |
| `feather` | MIT | 24 x 24 line icons, the origin of `lucide` |
| `tabler` | MIT | 24 x 24 line icons |
| `heroicons` | MIT | 24 x 24 line and solid icons |

Take only the `path`s, so the deck has no runtime dependency and stays one file.
Keep the copyright notice as a comment at the top of the place that lists the icons.

When an icon does not map one to one to a meaning, **write down what the original icon stood for before choosing**.
When one key is used for two meanings, a picture that fits one does not fit the other (one key stood for both a gate in a flow and the joining of two paths, and the picture for joining made the gate meaningless).

## Shrink the shared icons inside figures

Drawing icons anew for each figure makes their lines thin and small, and they look cheap.
Shrink the icon vocabulary decided once for the deck.

```
glyphAt("key", x, y, 52, color, 3)   // Right: shrink the vocabulary
FIGURE_MARKS.key(x, y, color)        // Wrong: icons of its own for each figure
```

**Divide the stroke width by the scale.** Placed with `scale(0.52)`, the stroke is 0.52 times too, and a width chosen for 100 x 100 becomes a hair.

```
stroke-width="${(weight / k).toFixed(2)}"   // k = size / side of the icon's coordinate system
```

**Compute the point to place it from the face's center.** Placed by eye, it straddles the edge between the top and the side of a box and looks half placed (one was 20px off). When an icon looks like it floats, suspect the coordinates first.

```
const TOP = 190 - 62;          // the bottom's y minus the height is the center of the top face
glyphAt(glyph, 80, TOP, 52, color)
```

## Do not put a figure inside a figure

Pasting another `svg`'s content into an `svg` with `transform` shifts the coordinates and overlaps things; on two slides icons overlapped their labels.

To line up small icons, draw them directly in that `svg`'s coordinate system, or replace the icons with framed labels or dots, which read better.

## Frames and text

Text out of its frame is never acceptable. SVG `text` does not wrap, so count whether the characters fit the frame's width before drawing.

When they do not fit, take one of three: fewer characters, a wider frame, or several `text` lines.

## Empty space in a card

When a card is stretched to the slide's height and holds only text, its lower half is empty.
Fill it with a picture or a cutout of a screen, not with more text.
Enlarging the text is the last resort.

**Center the content of a card left to right.** Pushed to the left, the right half is empty and the card alone looks big.
In a card that stacks an icon, a heading, and an explanation, center all three.

## Cards that do not fit their container

When more cards are placed than the container holds, **the layout breaks in one of two ways**.

A layout that shrinks its rows (`1fr` rows) gives the cards too little height, and their content is drawn outside them.
A layout that keeps its rows (`align-content: center`) lets the whole row of cards overflow the container onto the note below.

In both, **the text is not cut, does not leave the slide, and the slide's height is filled**, so no other check catches them. Seven cards in three columns overflowing into three rows hid two identifiers and a note while all 69 slides passed with 0 flagged.

The check is `text and screenshots overlap`: it compares the rectangles of texts and flags pairs that overlap both ways.
Panel colors are not used, because in some layouts a card's background is 4% opaque and cannot count as covering.

**Screenshots count as something text must not sit on.** A screenshot declares that it runs to the slide's edge (`bleed`), which means it may leave the slide, not that text may sit on it (the last line of a list sat 5px on a screenshot, and a check of text alone missed it).

**Add columns, not rows, when adding cards.** Seven cards go in four columns and two rows; three columns and three rows fall into the breaks above.

## Show only the main part of a screenshot, enlarged

A whole screen fitted on a slide has text too small to say what screen it is. Letting part of the screen leave the slide does not help while the scale stays the same.

**Do not shrink the screen; cut out its main part and place it large.** Three steps:

1. Cut the main part out of the source. Write the cutting frames in a script and run it (do not run an image tool by hand)
2. Place it on the right of the slide. Drop the left part of the screen (navigation, margins, header bands) when cutting
3. Let it leave the slide to the right or the bottom, which shows that it continues and tightens the slide's edge

The scale to aim for: **the screen's text measures 22 to 30px on the slide.** About twice the design's 1x gives this range (the design's body text is 11 to 13px). Larger, the screen's text is bigger than the deck's body and looks like a sign, not a picture.

The size it can take depends on the source's pixels; see "Render the sources of screenshots at 4x".

**Only the displayed width decides the size.** A screenshot is given a width and takes its height from its aspect ratio, so trimming the cutout's height does not enlarge the text by a pixel. There are two ways up: widen the displayed width, or narrow the cutout.

**First see whether the cutout can be narrowed**, which leaves the layout as it is. A focused cutout is often packed to its edges, and narrowing it drops what the slide needs (in one deck, ten cutouts measured 0 to 2% margin in width, and not one could be narrowed).

When it cannot, widen the displayed width and let the right side leave the slide. Nothing is lost, but the screen grows on the slide and shifts the balance with the column of text on the left. A tall screen leaves at the bottom, so render it and check that what the slide is about is in its upper part.

Measure with the deck's `build/measure-shot-glyph.mjs`: the design's text size times the ratio of the displayed width to the cutout's width. The text is inside an image, so `audit.mjs` cannot see it.

**The cutout's shape decides where it leaves the slide**: a tall one at the bottom, a wide one to the right. Cutting a meaningful part (a table's column, a risk label) to make the directions match removes what the slide says.

**When a screen has little content, change the material, not the placement.** A card with a few rows looks like a sign when enlarged and leaves the slide empty when reduced; it cannot be helped by scale, and trying only goes back and forth.

There are two places to change to. **A screen taken on a development machine often has little data**, so first look for the same screen with full data among the design tool's exports. If there is none, change the slide to use another screen.

**When changing to other material, cut off the parts that disagree with other slides.** A design export may name devices and keys differently from the real machine; leaving the parts with names (the right end of a list, filter chips) out of the cutting frame keeps the names consistent across the deck.

**Show a whole screen on one slide of the deck only**: the slide whose claim is the whole view ("one screen tells you"). Use focused cutouts elsewhere. On that slide, keep the full width and cut, if at all, only at the bottom.

## Do not stick text to the bottom edge

Slides have a bottom margin, and text that runs into it looks stuck to the bottom edge.
**Up to half the margin is allowed as part of the design; beyond that it is flagged.** A slide that ran 59px into a 96px margin was called cramped at the bottom, with 37px left.

The cause is nearly always one: **a grid or flex cell does not shrink below its content.** The default `min-height` is `auto`, so when a figure inside takes its height from its aspect ratio, the cell grows into the margin.

| Before | After |
|---|---|
| No `min-height` on the cell | `min-height: 0` on the cell |
| A width only on the figure | Put the figure in a `flex: 1` frame and let it shrink with `preserveAspectRatio="xMidYMid meet"` |
| The explanation pushed to the bottom with `margin-top: auto` | Put it right after the figure, and let the figure take the height left over |

The third is the hardest to find: pushing the explanation down leaves a gap only between the figure and the explanation, so **the slide seems to have room while the text sticks to the bottom**.

The check is `text sits on the bottom margin`. Screenshots, decoration, and text inside an `svg` leave the slide by design and are not counted.

## Render the sources of screenshots at 4x

A design tool's exports are often at 2x, and cutting from them leaves **some cutouts with fewer source pixels than their size on the slide** (three of sixteen fell below 1x, and only the screen's text blurred). The more focused a cutout, the larger it is placed, and the more it blurs.

Render the sources at 4x: with 4x, the layout stays and only the pixels double (4x reduced to 2x differed from the existing export by 0.6%). The deck's `build/shoot-4x.mjs` does this.

**Do not render an exported HTML again with another tool.** Its fonts are not all on hand, and another font changes the line heights and moves every cutting frame (comparing two 2x renders, 11% of the pixels differed and lines dropped by one row). Use the same renderer as the original.

The check is `screenshot is too coarse`: a source with fewer than 1.5 pixels per pixel of its size on the slide is flagged.

## Enlarge only the container of an icon

**Do not enlarge an icon and its container by the same ratio.** The ratio stays, and room never appears. When it looks tight, enlarge only the container and leave the icon's size alone.

Going back and forth three times showed this: shrink the icon, hear it is too small, enlarge both, still touching the edge. As long as the icon's size moves, it is not solved.

The same happens when a container's height is reduced from outside: setting a row to 330px to fit a screenshot below it pushed icons 24 to 58px into their cards' inner padding. **Restore what was reduced** (at 450px every card kept, below its icon, a gap as large as its inner padding).

The check is `icon spills out of its card`: an icon whose bottom passes the card's inner edge (the frame minus its padding) is flagged, also when the card does not clip (`overflow: visible`).

Compute the room with a formula, not by eye.

```
radius the icon reaches = 0.42 x icon size + half the stroke
room = radius the icon reaches / radius the container allows
```

`0.42` is how far an icon reaches in its box, as measured; it differs per set, so measure it.

```js
/* Put the icon in a 24 x 24 svg, take getBBox(), and see the farthest reach from the center */
const half = Math.max(Math.abs(bb.x - 12), Math.abs(bb.x + bb.width - 12),
                      Math.abs(bb.y - 12), Math.abs(bb.y + bb.height - 12));
```

Fifteen `lucide` icons reach 75 to 84% of the box, and `key` reaches farthest.

`scripts/glyph-fit.mjs` does the measuring. Export the icons as `{ "key": "<path .../>", ... }` and pass them; it prints the reach, the room, and the container size that gives 0.73.

```
PLAYWRIGHT_FROM=<project with Playwright> node scripts/glyph-fit.mjs <icons JSON> \
  --diamond <half width>x<half height> --glyph <icon size> --stroke <stroke width>
```

The radius a container allows depends on its shape.

| Container | Radius allowed |
|---|---|
| Top face of an isometric box (a diamond) | half width x half height / (half width + half height) |
| Circle | radius / square root of 2 |
| Square | half the side |

**Aim for 0.73.** Above 0.95 it looks like it touches the edge.

**Drop the icon only when the container cannot grow.** On a slide with three figures in a row, widening the boxes closed the gaps between them and the arrows became unreadable, so that slide alone dropped its icons. Measure what surrounds the container before deciding.

## Icon frames

When a circle or a rounded square frames an icon, make the frame clearly larger than the icon; at the same size, the frame looks crushed.

Make a circle's diameter at least 1.8 times the icon.

**Measure that the ratio holds.** The CSS that carried this rule in a comment put a 26px icon in a 40px circle, only 1.5 times, and nobody noticed until it was pointed out.

## The gap below an icon for its name

A name placed right below an icon can look as if it touches it; one was called "almost stuck together" with a 3px gap.

**Compute the baseline with a formula, not by eye.**

```
baseline = icon center + 0.42 x icon size + 1.33 x text size
```

`0.42` is how far an icon reaches in its box, the same value as in "Enlarge only the container of an icon".
`1.33` is a gap of 0.6 plus a glyph height of 0.73, both relative to the text size.

With an icon of 46 and text of 25, that is `center + 19 + 33 = center + 52`; the defect above used 42, and the top of the glyphs came 3px below the icon.

**Center the group on the frame again.** Moving the name down extends the icon-and-name group downward, so place the icon's center again so that the midpoint of the group's top and bottom is at the frame's vertical center. Moving only the name puts the group low in the frame.

## Center a frame's name on its width

When a frame (such as "on the company's machine" and "outside") has a name, do not push it to the left: place it at the center of the frame's width with `text-anchor="middle"`. As with centering a card's content, a name on the left leaves the right half empty and makes the frame look big.

## Add a screenshot to a slide of text only

A slide that explains things one by one becomes a list of rows when left alone; it was called "all text and dull".

**Find a screen that shows what the slide explains, and place it on the right**, as in "Show only the main part of a screenshot, enlarged" (a focused cutout on the right, leaving to the right or the bottom).

**Put the rows on the left, and stack the term and its explanation.** Giving width to the screenshot narrows the explanation column below 350px, and it wraps every two words. Use three columns (number, term, explanation) only when there is width.

**When no screen fits, cut text and reduce the rows instead.** A loosely related screen placed as filler makes the reader stop to match it against the body.

## Match a figure's viewBox to its frame

An `svg` with `width: 100%`, `height: 100%`, and a `viewBox` keeps its aspect ratio by default and fits the smaller way. When the ratio differs from the frame, the difference is left empty above and below (or left and right), and the figure shrinks to the center.

**Four slides wasted 21 to 26% of their height this way**, pointed out as "squeezed into the middle; use the whole space".

Measure the frame's size and set the `viewBox`'s height to `viewBox width x frame height / frame width`.
The frame's height differs per slide (a one-line or two-line heading), so measure and decide per slide.

**The width is already full, so use the added height for spacing, not for enlarging**: make the boxes a little larger, separate names from explanations, and add space between rows. Stretching the height while keeping the content leaves the figure at the top and the bottom empty.

**Enlarge a box keeping its proportions.** An isometric box stops looking solid when the ratio of its half width to its projected half height changes, so do not stretch y alone.

Write the measuring tool yourself: from the frame (`getBoundingClientRect`) and the `viewBox`, `Math.min(frame width / vb width, frame height / vb height)` is the scale, and `frame height - vb height x scale` is the height left over.

## Measure what grows when a slide has height left over

When the bottom of a slide is empty, there are two causes, and the eye cannot tell them apart.

| Cause | How to tell |
|---|---|
| The figure's `viewBox` ratio differs from its frame | Measure the height left over as in "Match a figure's viewBox to its frame" |
| The rule that grows the height applies to another child | List every child of the frame with its height and `flex-grow` |

The second comes from rules that grow the last child, such as `.pad > *:last-child { flex: 1 }`. Adding one sentence below the figure **makes that sentence the last child**, and the figure and the sentence split the height left over (294px each, with the figure packed in the upper half).

Give `flex: 0 0 auto` to children that should not grow. Put the rule in the CSS loaded later (the style's own CSS); changing the base CSS spreads to the other styles.

**Measure every child of the frame.** Listing each child's `className`, height, `flex-grow`, and `flex-basis` shows at once which one grows; suspecting them one at a time goes back and forth until the right one is found.

## The center of a figure

In a figure with several arrows or lines, align the vertical center of the bundle of lines with the vertical center of the figure. When the boxes' centers and the lines' height differ, the figure looks tilted.

For two arrows going back and forth, place them so that their midpoint is at the boxes' center.

**Place an arrow between isometric boxes at the vertical middle of the facing edges.** The outer edge of the side of `isoBox(x, y, halfWidth, projectedHalfHeight, height)` runs from `y - height` to `y`, so the arrow goes at `y - height / 2`. Placed low on the box, the figure looks sunk (one was at 68% of the height and was pointed out).

**Derive the vertical positions from constants with formulas.** Otherwise every change of a box's size means placing the arrows and names again by hand, and fixing one moves another.

## The role of a figure

A figure does not just line things up: what is where, and what passes and what stops, should be clear from the figure alone.

Within a deck, draw the same thing with the same shape and the same color.
Decide the icon once for things that recur (such as keys, checks, and records), and use it on every slide.

## No backticks inside template strings

The CSS is written inside JavaScript template strings, which are enclosed in backticks.
A backtick in a comment inside them closes the string there, and the build fails.
In CSS comments, do not enclose identifiers in backticks.

## Order of checking

**Run until nothing is flagged.** Do not stop after one round.

1. Render again (do not judge by an old image after fixing)
2. Run `scripts/audit.mjs`
3. Fix the flagged slides
4. **Go back to 1** until it prints `flagged 0 slides`
5. When nothing is flagged, render each slide at full size (900px or more) and look at it
6. Check against each section of this file. Sections a machine cannot see stop nowhere else

Do not skip 5: slides judged fine in the overview always show defects later.

**An icon touching its container passes even at full size if you are careless.** For every slide with a figure, compute the room with the formula in "Enlarge only the container of an icon", and enlarge the container when it is above 0.73. "Just fits" by eye does not fit.

**Do not call it finished when nothing is flagged.** The checks see only the sections above that have a check name; the rest can only be seen by eye. Nothing flagged is the starting point, not the goal.

There are three tools, and each takes the path of a project with Playwright in `PLAYWRIGHT_FROM`.

**Pass a style name exactly as the viewer shows it.** The viewer chooses the style by name and keeps showing the first one when the name is not found; `audit.mjs` and `shoot.mjs` stop at that point and list the names they can open.

```
PLAYWRIGHT_FROM=<project with Playwright> node scripts/audit.mjs <viewer HTML> <style> [style ...]
PLAYWRIGHT_FROM=<project with Playwright> node scripts/shoot.mjs <viewer HTML> <style> <output folder> [slide number ...]
PLAYWRIGHT_FROM=<project with Playwright> node scripts/glyph-fit.mjs <icons JSON> --diamond WxH --glyph N --stroke N
```

`audit.mjs` exits 1 when any slide is flagged. Given slide numbers, `shoot.mjs` renders only those slides again, which makes the round trip of one fix fast.

The cover gathers its content in the middle by design, so its height used is not measured. A style that cuts screenshots at the slide's edge (a class with `bleed` in its name) and the round background of the cover (`.blobs`) leave the slide by design and do not count as breaks.
