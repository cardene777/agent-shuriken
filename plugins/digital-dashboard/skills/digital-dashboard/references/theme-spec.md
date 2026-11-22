# Formatting inside the templates

The design templates of the Digital Agency's "Practical guidebook for dashboard design" are `.pbit` files inside the downloaded zips (`templates/<Color>_1_0_0.zip`), version 1.0.0 of 2026-03-31.
A `.pbit` is itself a zip and holds the theme definitions under `Report/StaticResources/RegisteredResources/Digital_Agency_*.json`.
They hold **concrete values** that the guidebook's text does not give.

Type sizes, spacing, corner radii, grid line colors, and bar widths come only from these definitions.
When the dashboard is built with something other than Power BI, carry these values over as they are.
The values below were read from the Blue template.
When a theme is used, this file is not attached, because it holds color values.

## Defaults for every visual

The values set as the overall default (`*`) of the theme's `visualStyles`.

### Title

| Item | Value |
|---|---|
| Size | 14px |
| Font | Arial |
| Color | `#000000` |
| Weight | Bold |
| Alignment | Left |

### Subtitle

| Item | Value |
|---|---|
| Size | 10px |
| Color | `#626264` (the Label color) |
| Wrapping | On |

Note that the subtitle uses the Label color of the palette, not the body color (`#000000`).

### Legend

| Item | Value |
|---|---|
| Shown | Yes |
| Position | **Bottom** |
| Title | Hidden |
| Size | 10px |
| Font | Arial |
| Color | `#000000` |
| Marker | Line only (`lineOnly`) |
| Round markers | Not used |

The default position at the bottom matters.
Against the guidebook's principle of keeping the chart and its legend next to each other, the official templates chose the bottom.

### Axes (category and value)

| Item | Value |
|---|---|
| Label size | **8px** |
| Font | Arial |
| Label color | `#000000` |
| Axis title | Hidden |
| Grid lines | Solid |
| Grid line color | `#E6E6E6` |

The axis labels are very small at 8px.
Title 14px, legend 10px, and axis 8px make three levels.

The category axis also has:

| Item | Value |
|---|---|
| Preferred category width | 20 |
| Maximum margin factor | 50 |
| Inner padding | 40 |

### Data labels

| Item | Value |
|---|---|
| Shown | Yes |
| Size | 12px |
| Title size | 10px |
| Detail size | 12px |
| Position | Automatic |
| Density | 50 |
| Background | `#F8F8FB` |
| Background transparency | 10% |

Data labels have a background color, so a number placed on a colored fill stays readable by default.
This answers §4.3: when a fill cannot meet a contrast of 3:1, write the number right next to it.

### Padding, borders, and spacing

| Item | Value |
|---|---|
| Inner padding | 12px on every side |
| Vertical spacing | 8px |
| Background | `#F8F8FB` |
| Border color | `#F8F8FB` (the same as the background) |
| Corner radius | **12px** |

The border has the color of the background.
Regions are told apart by the difference in background color, not by frames.
This matches the guidebook's "remove unneeded elements" and "keep the underlying grid to a minimum".

### Dividers

| Item | Value |
|---|---|
| Color | `#949494` |

### Visual header

**Hidden** by default.
Every control icon (drill-down, filter, menu) is hidden.

Only two are shown:

- The copy-as-image button
- The focus mode button

This implements the design principle of chapter 3: do not demand complex operations.

## Page

| Item | Value |
|---|---|
| Page size | Custom |
| Width by height | 1280 by 720 |
| Background | `#FFFFFF` |
| Background transparency | 0% |
| Vertical alignment of the view | Top |

**The page background is white and the visual background is `#F8F8FB`**, two layers.
The slightly gray card and chart areas show the regions without borders.

## By kind of chart

### Line chart

| Item | Value |
|---|---|
| Markers | Shown |
| Marker fill | `#F8F8FB` |
| Marker border | Shown, in the series color |
| Line transparency | 0% |
| Area fill | None |
| Data label offset | 8px |
| Series label size | 10px |
| Series label background | `#F8F8FB`, 10% transparent |

The marker is filled with the background color and outlined in the series color.
Hollow points sit on the line, so each data point is easy to read.

Series labels have a background so they can sit right next to the line, as the guidebook asks for series names, and stay readable when they overlap it.

### Stacked column chart

| Item | Value |
|---|---|
| Bar width | 10 |
| Data label color | `#FFFFFF` |
| Data label position | Inside, centered |
| Label overflow | Allowed |
| Label offset | 13px |
| Bar border | None |
| Total shown | Yes (color `#000000`) |

Stacked bars put **white labels inside, centered**.

### Clustered column chart

| Item | Value |
|---|---|
| Bar width | 10 |
| Data label color | `#000000` |
| Data label position | Outside end |
| Label offset | 13px |
| Gap between series | 24 |

Clustered bars put **black labels outside**.
Note that the color and the position are the opposite of stacked bars.

### Pie and donut

| Item | Value |
|---|---|
| Slice borders | Shown |
| Border width | 1px |
| Border color | The family's key color (`#3460FB` for Blue) |
| Label | Share of the whole |
| Label color | `#000000` |
| Label size | 10px |
| Inner radius of the donut | **80%** |

An 80% inner radius makes a thin ring with a large empty center.
The slice borders are in the family's color, not white.

### Table

| Item | Value |
|---|---|
| Outer border width | 1px |
| Outer border color | `#E6E6E6` |
| Vertical rules | Shown, `#E6E6E6`, 1px |
| Horizontal rules | Shown, `#E6E6E6`, 1px |
| Body size | 12px |
| Row padding | 3px |
| Header size | 10px |
| Header color | `#000000` |
| Header background | `#F1F1F4` (the Control background) |
| Header weight | Bold |
| Header alignment | Left |
| Body text color | `#000000` |
| Body background | `#FFFFFF` |

The header background is the palette's Control background.
The header is treated as a control because sorting works on it.

### Card (headline figures)

| Item | Value |
|---|---|
| Value size | **36px** |
| Value color | `#000000` |
| Value alignment | Left |
| Label | Hidden by default |
| Label size | 12px |
| Outer border | Hidden |
| Accent bar color | The family's key color |

The figure is 36px, about 2.6 times the 14px title, and the most prominent element on the screen.
This carries out §3.4 of the guidebook, which asks the top left to show the whole briefly and to draw the eye most, with type size as well as background color.

### KPI

| Item | Value |
|---|---|
| Value size | 36px |
| Icon | Hidden |
| Alignment | Left, vertically centered |
| Color when good | `#0017C1` (a dark step of the family) |
| Color when neutral | `#000000` |
| Color when bad | `#CE0000` |
| Target size | 12px |
| Last date size | 12px |

Good is shown with **a dark step of the family's color**, not with green.
Avoiding red against green takes care of color vision differences.

### Slicer (filter)

| Item | Value |
|---|---|
| Header | Hidden |
| Item size | 12px |
| Item padding | 4px |
| Item background | `#FFFFFF` |
| Overall background | `#F1F1F4` (the Control background) |
| Border color | `#F1F1F4` |
| Outer border color | `#949494` |
| Date size | 10px |
| Slider color | `#949494` |

### Gauge

| Item | Value |
|---|---|
| Fill | The family's key color |
| Target color | A dark step of the family |
| Target size | 12px |

## Type sizes

The theme uses six sizes.

| Size | Use |
|---|---|
| 36px | Headline figures (cards) and KPIs |
| 24px | Data labels of multi-row cards (`multiRowCard`) |
| 14px | Visual titles |
| 12px | Data labels, table body, slicer items, targets |
| 10px | Legends, subtitles, table headers, pie labels, series labels |
| 8px | Axis labels, axis titles, category labels |

There are few steps, and they are far apart.
Apart from 12px and 10px, each step is nearly double the next, so the order of importance reads from the size alone.

One figure on a card is 36px; several rows on a card are 24px.

### Padding of multi-row cards

Only multi-row cards (`multiRowCard`) have **16px** of inner padding instead of the default 12px.
They also show a border, `#949494`, 1px.

## Colors used for formatting

Colors used outside the data series.

| Color | Use |
|---|---|
| `#000000` | Body text, labels, axis labels, titles |
| `#626264` | Subtitles |
| `#FFFFFF` | Page background, table body background, labels on stacked bars |
| `#F8F8FB` | Visual background, borders, marker fills, label backgrounds |
| `#F1F1F4` | Table header background, slicer background |
| `#E6E6E6` | Grid lines and table rules |
| `#949494` | Dividers, slicer outer borders, sliders |

`#949494` is not on the color palette page; it exists only inside the templates, and only for dividers and the outer borders of controls.

## Colors of the data series

The first 8 colors of `dataColors` in the theme JSON are the Digital Agency's.

For the Blue theme:

| Order | HEX | Is |
|---|---|---|
| 1 | `#0017C1` | Blue 900 |
| 2 | `#3460FB` | Blue 600 (key color) |
| 3 | `#7096F8` | Blue 400 |
| 4 | `#C5D7FB` | Blue 200 |
| 5 | `#E8F1FE` | Blue 50 |
| 6 | `#FE3939` | Red 600 |
| 7 | `#FFBBBB` | Red 200 |
| 8 | `#F8F8FB` | The Standard background |

**From the 9th on, the colors are spares of Power BI's standard theme**, not the Digital Agency's.
More than 8 series fall back to them, which never happens when the number of colors is kept small.

Three points of a diverging color scale are also set:

| Position | HEX |
|---|---|
| Minimum | `#FFBBBB` |
| Middle | `#E6E6E6` |
| Maximum | `#C5D7FB` |

It runs from red through gray to blue, avoiding red against green, as the KPI colors do.
