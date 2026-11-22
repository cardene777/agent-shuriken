# Dos and don'ts of dashboard design

The ten items (five on learning what you want to know, five on avoiding misunderstanding) of §4.4, "Principles of chart design", and §4.5, "Dos and don'ts", of the Digital Agency's "Practical guidebook for dashboard design" (edition of 2026-03-31).
Each item has a **do**, a **don't**, and an implementation note written for this skill.

## The two principles (§4.4)

| Principle | What it means |
|---|---|
| **Learn what you want to know** | Reach the information you need quickly (simple, ordered, emphasized, fast) |
| **No misunderstanding** | Convey the data accurately (clear labels, definitions, no distortion, meta information) |

## Learning what you want to know

### 1. Show the overall figures and the detailed charts (§4.5 and §3.3)

Put the overall figures (headline KPIs) beside the detailed charts, so the whole is seen first.

```text
Do
  +-----------------+-------------------+
  | Sales ¥10M      | Monthly trend ──╲ |
  | +15% YoY        |            ╲   ╲  |
  +-----------------+-------------------+

Don't
  +-----------------------------------+
  | Monthly trend ──╲                 |  <- the whole cannot be seen
  |            ╲   ╲                  |
  +-----------------------------------+
```

Note: the headline KPIs take about the top-left third, in type of 3rem or larger. Always add something to compare with, such as the previous period or the previous year (§3.3, give something to compare with).

### 2. Order the items of a chart with a meaning (§4.5)

The items of bars, pies, and tables go in the order the viewer wants to know or can compare most easily: by size, by update date, alphabetically, whichever fits best.

- Do: a sales ranking in descending order of sales
- Do: a timeline with the newest first (at the top)
- Don't: by ID or by registration order (unrelated to the viewer's decision)
- Don't: in random order

Note: always sort explicitly. With a chart library, pass the data already sorted.

### 3. Remove unneeded elements (§4.5, and "keep it simple" in §4.4)

Avoid repeating information, and keep the underlying grid to a minimum. Text not directly about the numbers goes in a light color (about step 400).

```text
Do                              Don't
  100 ┐                           100 ┐━━━━━━━━━━━━━━━━━━
   80 │   ████                     80 │━████━━━━━━━━━━━━━
   60 │   ████  ████               60 │━████━━████━━━━━━━
   40 │   ████  ████               40 │━████━━████━━━━━━━
   20 │   ████  ████               20 │━████━━████━━━━━━━
    0 └────────────                 0 └━━━━━━━━━━━━━━━━━━
       Q1    Q2                        Q1    Q2
                                     ^ dark grid lines, and many of them
```

Note: a faint dashed grid in `#E6E6E6`, no tick marks, and a quiet axis line in `#CCCCCC`.

### 4. No decoration and no rich effects (§4.5)

3D, drop shadows, gradients, and textures are noise unrelated to the numbers. **Do not use:**

- 3D pies or 3D bars
- Cards decorated with heavy shadows
- Gradient fills (they make series harder to tell apart)
- Soft, embossed backgrounds behind icons
- Numbers that spin or fade in (they delay reading)

Note: no large shadow or gradient classes inside a dashboard. Show card edges with a 1px line in the step-200 gray.

### 5. Use few colors in a chart (§4.5, and "add emphasis" in §4.4)

About **one to five colors** per chart. With more, it is unclear which series to look at.

Choose the colors by the official roles (Primary, Secondary, Neutral).
**Do not use another step of the family's color for the second series.** Take Secondary (`color-palette.md`, section 3).

**Pick the step of Secondary that meets a contrast of 3:1.** The secondary colors are lighter than the family's color, and in some families step 600 does not reach 3:1.

| Family | Primary | Secondary (the lightest that meets 3:1) |
|---|---|---|
| Solid Gray | 536 (`#767676`, 4.54) | Yellow 800 (`#A58000`, 3.69) |
| Blue | 600 (`#3460FB`, 4.99) | Yellow 800 |
| Light Blue | 600 (`#008BF2`, 3.51) | Yellow 800 |
| Cyan | 600 (`#00A3BF`, 3.00) | Green 600 (`#259D63`, 3.45) |
| Green | 600 (`#259D63`, 3.45) | Cyan 600 (`#00A3BF`, 3.00) |
| Orange | 600 (`#FB5B01`, 3.18) | Yellow 800 |
| Red | 600 (`#FE3939`, 3.58) | Yellow 800 |

**Yellow 600 (`#D2A400`) has a contrast of 2.32 and misses 3:1.** As a fill it needs the number right beside it, or shown on hover.
The same holds for Yellow 400 (`#FFC700`, 1.56), Green 400, and Cyan 400.

| Series | Palette |
|---|---|
| 1 | Primary alone |
| 2 | Primary and Secondary (the table above) |
| 3 | Primary, Secondary, and Primary 900 |
| 4-5 | Add Primary 400 (with the numbers beside it) |
| 6 or more | **Split the chart or group the series** |

What is compared with (targets, averages, last year's values) does not count as a series and takes **Neutral**:
`#666666` (SolidGray 600, 5.74). **`#999999` (SolidGray 400) has 2.85 and misses 3:1**, so it is not used as a fill.

Note: give Primary only to the series to emphasize and Neutral to the rest; that makes the emphasis. More in `color-palette.md`, section 3.

## Avoiding misunderstanding

### 6. Say in the title what the chart shows and what kind of data it is (§4.5)

Write in the title **what the numbers mean** and **the kind of data** (monthly trend, running total, shares, and so on).

- Do: "Monthly sales (January to December 2025)"
- Do: "Sales by department, share of the total (Q4 2025)"
- Don't: "Sales" (no range, no kind)
- Don't: "Chart 1"

Note: the title is a level-2 heading, 1.25 times the size of the text inside the chart, and always names the kind (trend, shares, running total).

### 7. Keep titles and legends simple (§4.5, and "label clearly" in §4.4)

Avoid long phrases; write briefly.

- Do: "Tokyo", "Osaka"
- Don't: "Sales results of this month in Tokyo (before tax)" (too long for a legend)

Note: about 10 characters per legend label. Conditions such as before tax or preliminary go into the meta information (item 10).

### 8. Keep the chart and its legend together (§4.5)

Put the legend **right next to the chart**, in **the order of the series** in the chart.

```text
Do
  Trend ─── ① ──── ②        ① Tokyo
        ─── ③               ② Osaka
                            ③ Fukuoka
        (the legend right of the chart)

Don't
  Trend ─── ① ──── ②
        ─── ③
        ...
        ① Tokyo  ② Osaka  ③ Fukuoka   <- the legend far from the chart
```

Note: fix the legend vertically to the right, in the order of the data's series. For line charts, the series names placed **right next to the lines** are better than a legend (§4.2).

### 9. Start the axis at 0 as a rule (§4.5)

When **bars in particular** start above 0, the differences look larger or smaller than they are. A start at 0 is **required** for bars.

```text
Do                              Don't
  ^                               ^
  6 ─── ┌──┐ ┌──┐                 6 ─┌──┐ ┌──┐
  4 ─── │  │ │  │ ┌──┐            5 ─│  │ │  │ ┌──┐
  2 ─── │  │ │  │ │  │            4 ─│  │ │  │ │  │
  0 ─── └──┘ └──┘ └──┘            3 ─└──┘ └──┘ └──┘
       A    B    C                    A    B    C
                                  ^ starting at 3 exaggerates the difference
```

Lines and areas do not strictly need 0, but their axis ranges are never cut arbitrarily (§4.4, no distortion).

Note: set the Y axis domain from 0 explicitly; leaving it out lets the library fit a range that may not start at 0.

### 10. Do not tell categories apart by color alone (§4.5 note, §4.3 on color vision)

Mind color vision differences: show categories with **color and shape or pattern**, so they can be told apart in black-and-white print too.

- Do: lines with color and marker shapes (●▲■◆)
- Do: bars with color and a light stripe or dot pattern
- Do: pies with color and labels on leader lines
- Don't: "the red line is Tokyo, the blue line is Osaka" (color alone)
- Don't: a heat map whose legend gives only color names

Note: give each line its marker shape, and back the legend with a table where it helps.

## The principles of chart design (§4.4)

§4.4 of the guidebook lists these principles above the ten items. **The dos and don'ts make them concrete:**

| Principle | Items |
|---|---|
| Keep it simple | 3, 4, 7 |
| Order with a meaning | 2 |
| Add emphasis | 1, 5 |
| Do not make the viewer wait | (with the loading speed in the technical part of §5.4) |
| Label clearly | 6, 7 |
| Define the data | (with the reference to data definitions in the data design part of §5.4) |
| Do not distort | 9 |
| Write the meta information | (with the data update date in the data design part of §5.4) |

## The official checklist (§5.4)

These items of the official checklist (`checklist.xlsx`, downloaded by `scripts/fetch_official.py`) match the dos and don'ts directly:

- 2, figures for the whole, matches item 1
- 5, one to five colors, matches item 5
- 6, as few grid lines and borders as possible, matches item 3
- 7, no unneeded decoration, matches item 4
- 8, clear titles and series names, matches items 6 and 7
- 9, bars start at 0, matches item 9
- 15, not by color alone, matches item 10

Check these together.

## Sources

- §4.4 of the guidebook, principles of chart design (the eight principles above)
- §4.5 of the guidebook, dos and don'ts (the ten items)
- §4.3 of the guidebook, color palette (color vision)
- §3.3 of the guidebook, principles of dashboard design (the headline KPIs and something to compare with)
