# Choosing a chart

A decision tree that settles which chart shows a piece of data, following §4.1, §4.2, and §4.5 of the Digital Agency's "Practical guidebook for dashboard design" (edition of 2026-03-31).
The guidebook names the sections; the trees, tables, and values below are this skill's own rules built on them.

## 0. Figure, table, or chart (§4.1)

Before choosing the kind of chart, decide whether the information is a figure, a table, or a chart.

### Terms

- A **figure** in the guidebook is a KPI card
- A **table** is a data table
- A **chart** is a chart

### Tree

```
Show a piece of information
  └─ What kind of value is it?
       ├─ A single value that drives a decision or an action ──> Figure (KPI card)
       └─ Several related values in rows and columns
            └─ Should the viewer compare amounts or see a trend?
                 ├─ Yes ──> Chart (section 1)
                 └─ No, only look things up ──> Table
```

### How to choose

| Choice | When | Examples |
|---|---|---|
| **Figure (KPI card)** | One or a few (at most 6) important values, totals that drive a decision or an action | Headline KPIs (total assets, total sales, utilization) and their supplements (month over month, year over year) |
| **Table** | Many (10 or more) related values, where comparing the list is the main goal and the trend is secondary | The 47 prefectures, a customer ranking, a history log |
| **Chart** | Comparing amounts, a trend over time, shares, or a relation, seen at a glance | Bars, lines, areas, pies (chosen with the tree in section 1) |

### 0.1 Combinations

The guidebook treats the three apart, but real dashboards combine them.

- **Figure and chart**: KPIs for the whole and a chart of the detailed trend (the guidebook's "do" in §4.5: show the overall figures and the detailed charts)
- **Table with data bars**: a table of 47 rows with a data bar in each row's count column (the finished example on page 11 of the guidebook, a mix of table and chart)
- **Figure and table**: headline KPIs and a detail table for drilling down

### 0.2 Mistakes

- **A single value drawn as a chart**: make it a figure (KPI card) (§4.5, no decoration)
- **A trend listed as a table**: make it a chart (§4.5, a meaningful order shown visually)
- **Many values laid out as figures**: make them a table (§3.2, the right amount of information, at most 6 KPIs)

## 1. The tree

```
Visualize the data
  └─ What should it convey?
       ├─ Change and trend over time
       │    ├─ Presentation dashboard, monthly ──> Bars (§4.2, page 11)
       │    └─ Several series at once ──> Lines as small multiples
       ├─ Comparing amounts ──> Bars (§4.2)
       ├─ Shares of a whole
       │    ├─ Total is clear, compact ──> Pie (§4.2)
       │    ├─ Total is clear, over time ──> Area (§4.2)
       │    └─ Total is unclear, or 6 or more series ──> Bars
       ├─ A relation between two axes ──> Scatter plot (exploration dashboards only)
       └─ A distribution by position ──> Heat map (exploration dashboards)
```

## 2. Which chart for which use

| Use | Right | Wrong |
|---|---|---|
| A monthly count (presentation) | **Bars** (as in the finished example on page 11) | A line alone |
| A monthly count with a rate (public sector presentation) | **Bars and a line on two axes** (count on bars, main axis; rate on the line, second axis; the pattern of page 11) | The count as bars and the rate in a separate KPI |
| Several measures over time (exploration) | Small multiples (four line charts side by side) | Five lines in one chart |
| Counts of the 47 prefectures | **Bars** (as data bars), or a table with bars | 47 lines |
| Shares (in use, considering, not in use) | A donut with nothing in the center, and a legend | A pie with an emphasized center label |
| Allocation by department (5 segments) | A donut with the counts in the legend | A pie with 7 or more segments |
| Processing time by prefecture and month | A heat map (exploration, an exception) | 47 lines |
| Income and expenses | **Two series of bars** (grouped bars) | Lines on two axes (both are money, so no combination is needed) |
| A relation between two measures | A scatter plot (exploration, an exception) | Bars |
| **Change over time, shares, and the absolute amounts** (§4.2) | **Stacked area** | Stacked bars (they break the continuity of time) |
| **Change over time and shares only, without the amounts** (§4.2) | **100% stacked area** | Stacked area (the amounts make the change in shares hard to read) |
| **Shares without time** (§4.2) | A donut, or bars when there are 6 or more series | 100% stacked area (meaningless without time) |

Between stacked area and 100% stacked area, ask whether the viewers decide anything from the rise and fall of the amounts: if they do, stacked area; if not, 100%.
Settle this with the users when the requirements are worked out.

### When two axes are right

- **Right**: a monthly count (bars) with a rate (line), as on page 11, where one event is shown at two grains
- **Wrong**, because it distorts (§4.5):
  - The two axes measure unrelated things, such as a count drawn over revenue
  - The second axis has an extreme range, such as 0-100 against 0-10,000,000
  - The two series are not one event at two grains, such as time mixed with another dimension

## 3. One chart, one role (§4.4, simplicity)

| Role | Chart | Why |
|---|---|---|
| The whole | Headline KPIs and a donut | Seen at a glance |
| The trend | Bars (presentation) or lines (exploration, small multiples) | Over time |
| The comparison | Bars (counts), or a table with data bars | Differences in amount |
| The composition | A donut with the counts in the legend | The breakdown |
| The relation | A scatter plot (exploration) | Correlation of two axes |
| The distribution | A heat map (exploration) | Density in several dimensions |

## 4. How many series (§4.5)

| Chart | Recommended | At most | When there are more |
|---|---|---|---|
| Grouped bars | 1-3 | 5 | Stacked bars, or small multiples |
| Lines | 1-3 | 5 | Split into small multiples |
| Donut or pie | 3-5 | 5, or 7 when every segment meets 3:1, the legend gives the counts, and the field needs it | Gather the rest into "other" and give the details in a table |
| Scatter plot | 1-3 (by color) | 5 (by region color) | Split into separate charts |

## 5. Colors (§4.3)

### 5.1 Colors in one chart

The guidebook (§5.4) asks: "Are the colors of the chart limited to about one to five?"
One chart has **one to five fill colors**. This counts per chart, not across the whole palette of a theme.

### 5.2 Which step for what

| Step | Contrast on white | Use |
|---|---|---|
| 50 and 200 | under 3:1 | Backgrounds and decoration; never the only carrier of meaning |
| 400 | under 3:1 (cyan 2.00, blue 2.91) | Next to a legend, always with the number; avoid alone |
| 600 | 3:1 to 5:1 | The main colored areas of charts (recommended by the guidebook; 536 for SolidGray only) |
| 900 | 5:1 to 11:1 | Text, emphasis, and the main areas of pale themes |

### 5.3 State colors

| Use | Color | Note |
|---|---|---|
| Positive (better) | blue-600 to blue-900 | Text in blue-900 (contrast 11.10) |
| Negative (worse) | red-600 to red-900 | Text in red-900 (contrast 5.79) |
| Neutral (flat) | gray-536 | Contrast 4.54 on white |

### 5.4 Colors follow roles

Give the primary color only to the one series or segment to emphasize, and the neutral steps to the rest.
Do not tell segments apart with shades of the primary color.

The steps of section 5.2 are a guide for the official palette.
With a theme, give the theme's primary and neutral steps the same roles.

## 6. As few chart elements as possible (§4.5)

| Element | The guidebook's view | In practice |
|---|---|---|
| Background grid | Not needed, hidden | Remove the grid component |
| Axis lines | A thin X axis only, no Y axis line | A gray-400 X axis line, no Y axis line |
| Tick marks | Not needed | Hide the tick marks |
| Legend | None for one series; beside the chart for several | Build the legend beside the chart rather than the library's default |
| Data labels | Always shown on the bars, never only in a tooltip | Draw the labels on the bars |
| Y axis ticks | Domain and ticks set explicitly | Set the domain from 0 and list the ticks |
| Dates on the X axis | `25/6` (year/month); the month alone is wrong | Format the ticks |

## 7. Wrong patterns at a glance

| Wrong | Breaks | Instead |
|---|---|---|
| A monthly trend as a line | §4.2, bars for presentation | One series of bars |
| Misused dual axes (unrelated units, an extreme second range) | §4.5, no distortion | Two axes only for one event at two grains, otherwise separate charts with one axis each |
| The default background grid | §5.4, as few elements as possible | Remove the grid |
| An added breadcrumb | §5.4, remove unneeded elements | Remove it |
| "N in total" emphasized in a donut's center | §4.5, unneeded decoration | An empty center, or a small, quiet label |
| A table's data bar on top of its number | §5.4, cognitive load | Two cells, one for the bar and one for the value |
| A fixed reference line on bars | §4.5, distortion | A KPI and the summary instead |

## 8. Where data labels go

How to place labels so they do not collide in a bar and line combination on two axes, in grouped bars, and with reference lines.

### 8.1 Bars and a line on two axes (the pattern of page 11)

| Element | Place | Why |
|---|---|---|
| The bar's value (count) | **Inside the bar at its top, in white, 14 px below the top** | Clears the line and its points; only when the shortest bar is about 50% of the plot height |
| The line's value (rate) | **Right above the point, 10 px up** | At least 24 px apart from the labels inside the bars |
| The reference line's label (target) | **Outside the plot, in the left margin (x = left margin - 56) or the right margin (x = left margin + plot width + 8)** | Fully apart from the bars and the line; pick the side that does not hit the axis tick labels |
| Legend | **Outside the plot, above or to the right** | Never inside the plot area |

When a month's bar is under 30% of the plot height, the label cannot go inside it.
Put only the count above the bar (y - 6) and the rate above the line's point (y - 14), and set the axis ranges so the top of the bar and the point are at least 24 px apart.

#### Ranges of the Y axes

Do not end the Y axes right at the largest value. Leave room so the bars, the line, and the dashed target line sit apart vertically.

| Axis | Range | Share taken | Why |
|---|---|---|---|
| Count (bars, main axis) | **1.4 to 1.6 times** the largest value, rounded to a round number | Bars at most 60-65% of the plot height | The top 35-40% is left for the line and the dashed target |
| Rate (line, second axis) | The target plus 5-10% | The end of the line at most 80% of the plot height | The end of the line stays at least 20 px from the dashed target at the top |

An example:

- The largest count is 58,305, so the count axis ends at **100,000** (1.45 times, ticks 0, 25K, 50K, 75K, 100K)
  - The tallest bar is 58,305 / 100,000 = 58% of the plot height, which leaves the top 42% for the line and the target
- The largest rate is 70.2% and the target is 80%, so the rate axis runs from 50 to **90** (ticks 50, 60, 70, 80, 90)
  - The end of the line sits at (70.2 - 50) / (90 - 50) = 50.5% of the plot height
  - The dashed target sits at (80 - 50) / (90 - 50) = 75%, 24.5% of the plot height above the end of the line, which is more than 20 px

Wrong:

- A count axis ending at 60K for a largest value of 58K: the top of the bar is at 97% of the plot height, with no room for the line or the target
- A rate axis ending at 80, right at the target: the dashed target lies on the axis tick, and without a legend the word "target" cannot be read
- A count axis less than 1.3 times the largest value: the label of the tallest month lands on the axis

### 8.2 One series of bars

| Element | Place |
|---|---|
| Value label | Above the bar (y - 6), or inside its top, depending on the bar's height |
| X axis label | Below the X axis line (top margin + plot height + 18) |
| Y axis tick label | Left of the Y axis line (left margin - 8) |

### 8.3 Donut

| Element | Place |
|---|---|
| Legend | A column on the right, each row a swatch, the name, the count, and the share. The swatch has the color of its arc |
| Center | **Empty** (§4.5, no emphasized center label) |
| Segment label | The name and the share outside the ring, on a leader line (§4.5, never by color alone, as in `dos-donts.md` item 10) |

When the only colors available leave neighboring segments less than 3:1 apart in lightness, drop the donut even with five or fewer segments, and use horizontal bars with the numbers written on them.
Do not solve it by adding colors.

### 8.4 Table with data bars

| Element | Place |
|---|---|
| Data bar | Its own cell, apart from the number |
| Value | Another cell, aligned right |
| Shape marks (▲, ▼) | Before the value (never by color alone, §4.5, two cues) |

### 8.5 Finding collisions

Look at a screenshot of the drawn chart and check:

1. Whether two or more texts sit at the same x (within 30 px) inside the plot area
2. Whether those texts are less than 12 px apart vertically
3. Whether, under the same test, a reference line's label overlaps a bar or the line

Any one of these is a collision to fix.

### 8.6 Labels on a waterfall chart

A waterfall chart lines up rising bars, falling bars, a start, and a total, so labels collide more easily than on plain bars.
Place them by the bar's height.

#### 8.6.1 By the bar's height

| Bar height | Label | Text color |
|---|---|---|
| 40 px or more | **Inside the bar, in white (top + 16)** | White (the bar's color gives at least 4.5:1) |
| 20 to 40 px | **Outside the bar (rising: top - 6; falling: bottom + 14)** | The bar's hue (rising blue-900, falling red-900) |
| under 20 px | **In the legend** (no label on the bar; the legend gives the value) | |

#### 8.6.2 Clear of the connectors

A waterfall draws dotted connectors between the bars at the running total. Keep each label **at least 12 px** from the connectors.

- A rising bar's label at top - 6 sits 6 px from the next connector, which runs at the same height as that top. Move the label to top - 14, 14 px away
- A falling bar's label at bottom + 14 is 14 px from the connector at its bottom, which is enough

#### 8.6.3 Checking it

In a screenshot, check that:

- Each label is placed inside, outside, or in the legend as the table in 8.6.1 says for the bar's height
- Each label is at least 12 px from the connectors
- No outside label reaches into the next bar's area

One miss is a collision to fix.

## 9. Charts common in other fields

The guidebook (§1.1) applies to presentation dashboards in any field.
Besides the charts of sections 1 to 8, these come up often in other fields.

### 9.1 Finance

| Use | Chart | Layout | Note |
|---|---|---|---|
| Daily open, high, low, and close of a price or a rate | **Candlestick** | X is the date, Y the price; the four values, colored by rise and fall | Rise in blue, fall in red, with a second cue in the marker shape (never by color alone, §4.5) |
| Income to expenses | **Waterfall** | Bars accumulate, showing plus and minus | Bars start at 0 (§4.5); plus in blue, minus in red, with a second cue |
| Asset allocation | **Donut** or **treemap** | By share or by size | One to five colors (§5.4); a donut up to 7 under the conditions of section 4 |
| Progress to a target | **Gauge** | A half or full ring | Mark the target at 100% and show the gap to the current value |
| Distribution of values (asset bands of customers) | **Histogram** | X is the bin, Y the frequency | Bins by Sturges or Freedman-Diaconis; bars start at 0 |
| Spread (returns) | **Box plot** | X is the category, Y the value | Show the median, the quartiles, and the outliers |
| Relation of two measures (risk and return) | **Scatter plot** (section 1) | Points on X and Y | At most 5 series, by color and by shape |

### 9.2 Medical

| Use | Chart |
|---|---|
| Patient counts over time | Bars (one series) or a line |
| Treatment outcomes (survival) | A Kaplan-Meier curve (a stepped line) |
| Positive test rate | A line with a reference line at the standard value |
| Bed occupancy | A gauge, or bars with a target line |

### 9.3 Manufacturing

| Use | Chart |
|---|---|
| Output over time | Bars (monthly) or a line |
| Defect rate | A line with control limits (upper and lower) as reference lines |
| Equipment utilization | A gauge, or stacked bars (running, stopped, planned stop) |
| Pareto analysis of defect causes | A Pareto chart (bars and a cumulative line on two axes) |

### 9.4 Retail and online shops

| Use | Chart |
|---|---|
| Sales over time | Bars and a line on two axes (orders and the average spend, the pattern of page 11) |
| Composition by product category | A donut or bars |
| RFM analysis | A heat map (recency by frequency) |
| Cohort analysis | A heat map (time by cohort) |

### 9.5 SaaS and IT

| Use | Chart |
|---|---|
| Monthly and daily active users | A line (one series) or bars |
| Breakdown of monthly or annual recurring revenue | A waterfall (new plus expansion minus churn equals net growth) |
| Churn rate | A line with a reference line at the target churn |
| Conversion funnel | A funnel chart (bars by stage) |

### 9.6 Labels on a candlestick chart

| Element | Place |
|---|---|
| The four values | In a tooltip or the legend; never as text inside the plot (§4.5, unneeded decoration) |
| Rise and fall colors | Rise in blue-600 (3:1), fall in red-600 (3:1), with a filled body against a hollow one as the second cue |
| Volume | Bars in a lower band on a second axis, following the rules for bars |

### 9.7 Labels on a waterfall chart, at a glance

| Element | Place |
|---|---|
| Each bar's value | Above the bar (y - 6), as section 8.6 refines; plus in blue-600, minus in red-600 |
| Connectors | A thin gray-536 line (1 px) between the bars |
| Start and total bars | gray-900, set apart from the bars in between |

### 9.8 Labels on a gauge

| Element | Place |
|---|---|
| Current value | A large number in the center of the gauge (32-48 px, like a headline KPI) |
| Target | A reference tick outside the gauge (orange-600 or similar) |
| Percentage | A supplement right under the current value (month over month and progress) |

## 10. How to use this file

1. Settle what the chart should convey when the requirements are worked out
2. Pick one kind of chart with the tree in section 1
3. Check the wrong patterns in section 2 (no line alone for a monthly count, no misused dual axes; the dual axes of page 11 are fine)
4. Design one role per chart, the number of series, the colors, and the elements with sections 3 to 6
5. Check with section 5.2 that no step-400 color carries meaning alone
6. Write down the reason for the choice in one line, such as why this kind and why no dual axes

The line of step 6 keeps the reason for the chart findable after the drawing has been handed to the drawing tool, and it becomes the instruction when the chart is redrawn.
