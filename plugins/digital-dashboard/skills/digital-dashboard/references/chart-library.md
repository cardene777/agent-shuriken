# The chart and component library

Every part laid out on the first page, "Chart and component library", of the Digital Agency's design templates (version 1.0.0 of 2026-03-31).
The values were read from `Report/Layout` of the `.pbit` inside `templates/Blue_1_0_0.zip`.
The parts are copied from this page and pasted onto the working sheet.

§5.1 of the guidebook says the templates provide 9 kinds of chart, but **the templates actually hold 30 visual types**.

The list below has 33 rows. The two maps share `shapeMap`, the two cards share `cardVisual`, and some slicers share `slicer`, so Power BI counts 30 visual types.
The 9 kinds of the guidebook are a short selection; the templates hold more.

The library page itself is 1280 by 6496, one tall page with every part on it.

## Charts (18)

| Name | Default size | Use |
|---|---|---|
| Line chart | 600 x 272 | Change over time, trends |
| Area chart | 600 x 272 | Change over time with amounts |
| Stacked area chart | 600 x 272 | Shares changing over time |
| 100% stacked area chart | 600 x 272 | Only the shares changing over time |
| Stacked column chart | 393 x 273 | Comparing amounts with their shares |
| Clustered column chart | 399 x 272 | Comparing amounts between categories |
| Clustered bar chart | 395 x 272 | Comparing amounts when the names are long |
| 100% stacked bar chart | 806 x 273 | Comparing shares, such as the share of each answer |
| Line and stacked column chart | 600 x 272 | Amounts (bars) with a rate (line) |
| Line and clustered column chart | 600 x 272 | Amounts and rates of several series |
| Ribbon chart | 395 x 272 | Rankings over time |
| Waterfall chart | 600 x 272 | The breakdown of a rise or fall |
| Funnel | 600 x 272 | The drop at each stage |
| Scatter chart | 600 x 272 | The relation of two variables, the spread |
| Treemap | 600 x 272 | Shares of a hierarchy |
| Pie chart | 600 x 272 | Shares |
| Donut chart | 600 x 272 | Shares (a total can sit in the center) |
| Gauge | 399 x 270 | Progress toward a target |

Only the 100% stacked bar chart is as wide as 806.
The size is meant for lining up the shares of the choices of a question, as the public example on education data does.

## Figures (2)

| Name | Default size | Use |
|---|---|---|
| Card | 395 x 128 | One headline figure |
| KPI | 395 x 272 | A figure, its target, and its trend |

There are two cards, showing two display formats.

## Tables (2)

| Name | Default size | Use |
|---|---|---|
| Table | 600 x 272 | A list of records |
| Matrix | 600 x 272 | Totals where rows and columns cross |

## Maps (2)

| Name | Default size | Use |
|---|---|---|
| Shape map (prefectures) | 600 x 416 | Colored by prefecture |
| Shape map (municipalities) | 600 x 416 | Colored by municipality |

Only the maps are taller, at 416, to fit the proportions of the Japanese islands.

The boundary data is inside the templates, so nothing else is needed.
The same data is also downloaded by `scripts/fetch_official.py` into `map/`.

## Filters (6)

| Name | Default size | Use |
|---|---|---|
| Slicer: dropdown | 395 x 128 | Pick from a list |
| Slicer: between values | 397 x 128 | A range of numbers or dates |
| List slicer | 189 x 272 | Pick from a vertical list |
| Button slicer | 189 x 272 | Pick with buttons |
| Input slicer | 394 x 272 | Filter by typing |
| Prefecture slicer | 168 x 67 | Pick in step with the map |

The input slicer and the button slicer are not standard in Power BI; they come with the templates as custom visuals.

## Navigation (3)

| Name | Default size | Use |
|---|---|---|
| Page navigator | 900 x 48 | Move between pages |
| Bookmark navigator | 600 x 48 | Switch between saved views |
| Action button | 300 x 48 | Any move or action |

All of them are 48 high.

## What the sizes say about the design

The default heights fall into a few groups.

| Height | Parts |
|---|---|
| 48 | Navigation |
| 128 | Cards and dropdown filters |
| about 272 | Charts, tables, and vertical filters |
| 416 | Maps |

The widths use only a few values as well: 189, 395, 600, 806, and 900.

On a page 1280 wide, they relate as follows.

| Width | Division |
|---|---|
| 600 | Halves (600 times 2 plus margins) |
| about 395 | Thirds |
| 189 | Sixths |
| 806 | Two of the thirds |

So the default sizes of the parts already fit the halves, thirds, and sixths of the layout grid.
A pasted part sits on the grid at once, so its size rarely needs adjusting.

## Using the library

The library page has a text "Title" as a heading with a divider under it.
Fifteen explanatory images (128 x 128) sit left of the parts.

They are there to explain, so do not copy them to the working sheet.
Copy only the charts, figures, tables, filters, and navigation themselves.
