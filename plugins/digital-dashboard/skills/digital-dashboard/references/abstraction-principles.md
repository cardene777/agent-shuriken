# Design principles

Why a dashboard is designed the way the guidebook asks, in one file.
Each section names the section of the Digital Agency's "Practical guidebook for dashboard design" (edition of 2026-03-31) it rests on, written as §X.Y.
Quotes from the guidebook are translated from Japanese for this file; the guidebook itself is the PDF that `scripts/fetch_official.py` downloads.

## 1. What a dashboard is (§1.1)

### The guidebook's definition

> The functions and performance a dashboard needs depend on who looks at it, in what environment, and what they do next.

A dashboard design that has not settled who looks at it, where, and what they do next is wrong from the start.

### Two kinds (§1.1)

| Kind | Use | In this skill |
|---|---|---|
| Presentation | Spotting anomalies and deciding the next action, with general knowledge and simple operations | The target |
| Exploration | Detailed analysis, with domain knowledge and complex operations | Out of scope |

The guidebook itself centers on the presentation kind as the first step toward a design system for dashboards (§1.1).

## 2. The three-step design process (§1.3)

The guidebook's process has three steps, in this order. Skipping a step leaves the guidebook's process.

```
1. Requirements (§2) ──> 2. Prototyping (§3) ──> 3. Implementation (§5)
        ^                        |   ^                     |
        └──── feedback ──────────┘   └──── checklist ──────┘
```

| Step | Input | Output | Guidebook |
|---|---|---|---|
| 1. Requirements | Who, what, when, where, why, and how, asked of the users | A statement of purpose and the constraints | §2.1-§2.3 |
| 2. Prototyping | The statement of purpose | A prototype that reflects the feedback | §3.1-§3.5 |
| 3. Implementation | The prototype and a template | The dashboard, with the checklist passed | §5.1-§5.5 |

## 3. The four design principles (§3.2 and §4.4)

The guidebook says these must always hold. A design that breaks any of them fails.

### 3.1 Convey the structure (§3.2)

> Arrange the information from the whole to the parts, as a hierarchy. Design the layout and the paths so the viewer first gets the information that shows the whole and then reaches its details.

In practice: the headline KPIs that show the whole sit top left, and the details (charts and tables) toward the bottom right.

### 3.2 Keep the amount of information right (§3.2)

> Take care that too much information does not wear down the wish to keep using the dashboard.

In practice: at most 6 KPIs and at most 4 kinds of chart on one dashboard, with all the main information inside the first screen.

### 3.3 Do not demand complex operations (§3.2 and §5.4)

> Let the viewer get the information they need without operating anything, or with few operations.
> Do you ask more operations of the viewer than needed? Is the viewer's goal reached in a few operations?

In practice: counts, percentages, and units sit in the legend itself, never only in a tooltip; a drill-down goes at most one level deep; and at least 80% of the information is visible in the default state.

### 3.4 Give something to compare with (§3.2 and §5.4)

> For data that is hard to decide on from the amount alone, show a target, an average, or last year's value beside it, or show the data as a ratio to last year.
> When the amount alone is hard to judge, is a value to compare with shown to help understanding?

In practice: every KPI carries a supplement such as "+N pt month over month", "last period X against this period Y", or "margin to the threshold".

## 4. The four principles for choosing information (§3.2)

These decide what goes on the dashboard. The design principles of section 3 decide how it is shown once it is there; these come before them.

### 4.1 Fit the purpose (§3.2)

From the data available, keep only what fits the purpose and remove the rest, so the distance from the data to the decision is short.
Test: each KPI and chart can be explained in one sentence against the purpose of the dashboard.
In practice: list the candidate KPIs and charts, note in one sentence what each adds to the purpose, and remove every candidate without a note.

### 4.2 Can be broken down (§3.2)

Keep the finest grain (daily values, single records), and let the whole break down into its parts in at most three levels.
Test: each headline KPI has a path down, across filters and through the hierarchy.
In practice: each KPI card links to a detailed chart or table, and the detail links one step further to the single records.

### 4.3 Differences stand out (§3.2)

Outliers and turning points over time can be seen.
Test: every KPI and chart has at least one of an average line, a target line, or a comparison with the previous period.
In practice: charts draw reference lines (target, average, threshold) dashed, and KPI cards carry a change badge and the ratio to the previous period.

### 4.4 The data is fresh (§3.2)

The latest data arrives through the data pipeline, and the footer shows when it is from.
Test: the allowed delay between the data and its display is stated.
In practice: the footer says `As of YYYY-MM-DD HH:MM (updated every N minutes)`. The usual refresh rates by field are in `conventions/<domain>.md`: medical every 30 seconds to 5 minutes, SaaS every minute to hour, finance the next day or live, and public sector daily to monthly.

### Do not mix the two sets

- The design principles of section 3 (structure, amount, operations, comparison) decide how the chosen information is shown
- The principles of section 4 (purpose, breakdown, differences, freshness) decide what is chosen

Filter the candidates with section 4 first; a candidate that does not meet all four is left out. Section 3 applies when the screens are drawn.

## 5. The two principles of chart design (§4.4)

### 5.1 The viewer can learn what they want to know (§4.4)

- **Simple**: no decoration, no unneeded elements
- **Meaningful order**: by size, by time, or alphabetically
- **Emphasis**: important information is larger, bolder, and in a stronger color
- **No waiting**: the largest content appears within 2.5 seconds, and responses take under 100 ms

### 5.2 No misunderstanding (§4.4)

- **Clear labels**: units and series names, kept short
- **Data definitions**: what was counted, when it was updated, and notes
- **No distortion**: no arbitrary axis ranges, and bars start at 0
- **Meta information**: source, the date the data is from, and disclaimers

## 6. The path of the eye (§3.4)

```
┌─────────────────────┬─────────────────────┐
│ 1. Overall figures  │ 2. Overview chart   │  <- start top left
│    (headline KPIs)  │    (donut and such) │
├─────────────────────┼─────────────────────┤
│ 3. Detailed chart   │ 4. Detailed table   │  <- move toward the bottom right
│    (bars, lines)    │    (47 rows, say)   │
└─────────────────────┴─────────────────────┘
          v summary paragraph (full width)
```

The guidebook (§3.4) asks to adjust the presentation so the top left draws the eye most, and to show the order of importance with background colors and emphasized regions.

## 7. A 16:9 screen with a six-part grid (§3.4 and §5.2)

> The templates are for a 16:9 screen with a layout grid that divides it into six both across and down.

In practice: a 1600 by 900 viewport (16:9) with a 12-column grid (6 times 2), placing the main regions in combinations of 3, 4, and 5 columns.

## 8. Accessibility (§5.5)

> When a dashboard publishes data handled by public or quasi-public bodies, make sure everyone can read the information equally.

| Rule | In practice |
|---|---|
| §4.3 colored areas of charts at 3:1 | Use colors of step 600 or darker |
| §4.3 numbers at 4.5:1 | Numbers meet WCAG AA 4.5:1; the large-text exception applies only to 18 pt or 14 pt bold |
| §5.5 alternative text | Every chart has `role="img"` and an `aria-label` |
| §5.5 published data | The data can be downloaded as CSV or Excel |
| §5.5 text summary | A summary paragraph under the dashboard, for people who cannot see it |
| §4.5 no meaning by color alone | Color is paired with a shape or a label |

## 9. What not to do (§4.5)

| Item | Why | How to find it |
|---|---|---|
| Bars that start above 0 | Exaggerates or shrinks the amounts | Set the domain to start at 0 |
| 3D and drop shadows | Decoration unrelated to the values | Search for `box-shadow` and `perspective` |
| Animation (pulse, fade, spin) | Delays reading the values | Search for `animate-` and `animation:` |
| Lines for comparing amounts that are not over time | The wrong kind of chart | See `chart-decision-tree.md` |
| Pie charts with five or more series | The shares are hard to read | Count the series |
| Misused dual axes | Two value axes invite misreading | Check that both axes measure the same event at different grains (section 10.2) |
| Categories told apart by color alone | Fails viewers with color vision differences | Add labels or patterns |
| Automatic ticks on the value axis | Irregular ticks | Set the ticks explicitly |

## 10. Two points that are often misread

### 10.1 "One to five colors" means within one chart (§5.4)

The guidebook asks: "Are the colors of the chart limited to about one to five?"
This counts the fills inside one chart, not the color tokens of the whole dashboard. A palette with five steps does not break the limit.

### 10.2 The guidebook's finished dashboard uses a bar and line combination (§4.2)

The guidebook says to use a line chart to convey change and trend over time, and a bar chart to compare amounts.
Its finished example on page 11 shows the monthly trend as bars for the count on the left axis and a line for the rate on the right axis, with a third series drawn as a line on top.
So showing a count and a rate together over time on two axes follows the guidebook.

| Use | Chart | Basis |
|---|---|---|
| A monthly count alone | Bars, kept simple | §4.2, short form for the first screen |
| A monthly count with a rate | Bars and a line on two axes (count on bars, main axis; rate on the line, second axis) | The finished example on page 11 |
| Several series over time (four measures, say) | Small multiples, one line chart each | §4.2 |
| One series over time | A line | §4.2 |
| Amounts compared, not over time | Bars | §4.2 |

Dual axes are still wrong when they distort (§4.5):

- The two axes measure unrelated things, such as counts and temperature
- The second axis has a far different range, such as 0-100 against 0-100,000, so it dominates the main one
- Use two axes only to look at one event at two grains, such as a count and its rate

## 11. Related files

- `chart-decision-tree.md` chooses the kind of chart (§4.2)
- `color-palette.md` holds the official colors (§4.3)
- The guidebook's checklist (§5.4) is `checklist.xlsx`, downloaded by `scripts/fetch_official.py`
