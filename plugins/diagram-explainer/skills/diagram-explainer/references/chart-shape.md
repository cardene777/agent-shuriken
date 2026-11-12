# Charts

Charts are drawn inside the document from a `chart` block.
`render.py` places an `<svg data-chart>` and the block's `spec` as JSON in the page; `assets/charts.js` draws the chart when the page opens (or when its page is first shown).
Nothing is loaded from outside, so the document stays one file.

```json
{"type": "chart", "kind": "timeband", "id": "a-hours", "caption": "Figure 3 When each service runs during a weekday", "spec": {...}}
```

| Block field | Required | Meaning |
|---|---|---|
| `id` | yes | Unique id. `render.py` also uses `<id>-spec` (and `<id>-say` with `views`) |
| `kind` | yes | `timeband`, `capbar`, `bars`, or `period` |
| `caption` | yes | Caption starting with the figure number; also the chart's `aria-label` |
| `spec` | yes | What to draw: the fields below for each kind |
| `views` | no | `timeband` only: buttons above the chart, see below |

Put example numbers and short notes inside the chart, and longer explanations in `tip` (shown when the pointer is over a dot, band, or bar).
Colors are the names `gray`, `blue`, `orange`, `violet`, `violet2`, `green`, `red`, or any CSS color value.
Axis units and default button names follow the document language: hours as `3:00`, years as `2024`, and capped-bar buttons `Before` / `After` in English; Japanese documents use the Japanese hour and year suffixes and button names.

On screens narrower than 860 px a chart keeps a 720 px minimum width and scrolls sideways inside its frame.

## Time bands (`timeband`)

Lanes with bands for the hours something is open and dots for moments in the day.

| Field | Meaning |
|---|---|
| `from` / `to` / `step` | Start, end, and tick interval of the axis in hours (default 0 / 24 / 3) |
| `gap` / `labelWidth` | Distance between lanes (default 64) and width of the lane name column (default 120), in chart units of a 1000-wide drawing |
| `lanes[]` | Lanes: `key` (name used by `views`), `name`, `bands[]`, `dots[]`, `spans[]` |
| `bands[]` | `from` / `to` / `label` / `color` / `tip`. `labelPad` moves the label away from the band start |
| `dots[]` | `at` / `label` / `color` / `tip`. `pos: "down"` puts the label below; `align: "start"` or `"end"` shifts it sideways |
| `spans[]` | Dashed line between two hours: `from` / `to` / `label` / `color` / `dy` (vertical offset, default 20) |

`views` on the block adds buttons above the chart.
Each view has `label`, `lanes` (lane keys to keep; empty keeps all), and `say` (a sentence shown above the chart).
The chosen lanes stay at full strength and the others fade.
On paper the buttons are replaced by a list of each view's label and sentence.

## Capped bar (`capbar`)

One bar against a limit, with buttons that switch between before and after trimming to it.

| Field | Meaning |
|---|---|
| `cap` / `capLabel` | The limit in percent, and the label under the limit line (default `<cap>%`) |
| `held` | The part already taken: `label` / `value` (percent) / `tip` |
| `items[]` | Parts added after it: `label` / `before` / `after` (percent) / `color` / `tip` |
| `buttons` | Names of the two buttons (before, after). Default `Before` / `After` (Japanese words in Japanese documents) |
| `beforeSay` / `afterSay` | Short sentence under the limit line for each state |

Keep item labels short: each label is centered on its segment.
On paper, where buttons cannot be pressed, a copy showing the after state is printed below.

## Bar chart (`bars`)

| Field | Meaning |
|---|---|
| `max` / `step` / `unit` / `yLabel` | Top of the vertical axis, tick interval, unit appended to tick labels, and axis name |
| `bars[]` | `label` / `value` / `text` (shown above the bar, default the value) / `color` / `tip` |

## Period chart (`period`)

A year axis with a cut-off line, a faded span leading up to it, and a highlighted span.

| Field | Meaning |
|---|---|
| `from` / `to` | First and last year of the axis |
| `cut` | The cut-off line: `at` (year; fractions mark months) / `label` (above the line) |
| `learn` | The faded span from the start of the axis to the cut: `label` (right-aligned at the cut) / `tip` |
| `test` | The highlighted span: `from` / `to` / `label` (inside) / `sub` (below) / `tip` |
| `note` | Short text to the left of the highlighted span; keep it clear of the cut line |
