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

A chart is drawn at the width of its frame in pixels, so its text keeps its size, 12px or more, at every screen width.
Each chart also measures the narrowest width at which its own words fit: hour and year labels apart, a band's or a part's name inside it, and a band's name ending before a dot on the band.
A chart that fits its frame fills it.
On a narrower frame, such as a phone, the chart keeps that narrowest width and scrolls sideways inside its frame: the page fades the edge where it continues and shows a line under it that says it scrolls.
A chart is drawn again when its section opens and when the window changes width.
On paper a chart shrinks to the width of the sheet.

Lines are drawn under the text: bars are opaque, so a grid line never shows through a bar, and text on the background of the chart has an outline in the background color, so a grid line stops at the text.

## Time bands (`timeband`)

Lanes with bands for the hours something is open and dots for moments in the day.

| Field | Meaning |
|---|---|
| `from` / `to` / `step` | Start, end, and tick interval of the axis in hours (default 0 / 24 / 3) |
| `gap` / `labelWidth` | Distance between lanes (default 64, more when a lane's dots and spans need it) and width of the lane name column (default 120, wider when a name needs it), in pixels |
| `lanes[]` | Lanes: `key` (name used by `views`), `name`, `bands[]`, `dots[]`, `spans[]` |
| `bands[]` | `from` / `to` / `label` / `color` / `tip`. The band is filled with its color and the label is written on it in the text color for colored bars, so use a named color to keep both readable in light and dark. `labelPad` moves the label away from the band start |
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

Keep item labels short: each label is centered on its part, and goes on two lines (the name over the percent) when one line does not fit.
The limit line is drawn over the parts.
On paper, where buttons cannot be pressed, a copy showing the after state is printed below.

## Bar chart (`bars`)

| Field | Meaning |
|---|---|
| `max` / `step` / `unit` / `yLabel` | Top of the vertical axis, tick interval, unit appended to tick labels, and axis name |
| `bars[]` | `label` / `value` / `text` (shown above the bar, default the value) / `color` / `tip` |

## Period chart (`period`)

A year axis with a cut-off line, an outlined span leading up to it, and a highlighted span.

| Field | Meaning |
|---|---|
| `from` / `to` | First and last year of the axis |
| `cut` | The cut-off line: `at` (year; fractions mark months) / `label` (above the line) |
| `learn` | The outlined span from the start of the axis to the cut: `label` (right-aligned at the cut) / `tip` |
| `test` | The highlighted span: `from` / `to` / `label` (inside) / `sub` (below) / `tip` |
| `note` | Short text to the left of the highlighted span; keep it clear of the cut line |
