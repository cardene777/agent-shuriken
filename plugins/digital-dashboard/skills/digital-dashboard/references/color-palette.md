# Color palette

The official color codes of the Digital Agency's "Practical guidebook for dashboard design": 7 color families in 4 categories.
The values come from the color palette page of the guidebook, `https://www.digital.go.jp/resources/dashboard-guidebook/color-palette`, and the roles from §4.3 of the guidebook.
When a theme is used, this file is not attached, and the request asks for the theme's colors instead.

**Do not take colors from `dataColors` in the JSON inside the Power BI templates.**
The array holds only indexes, so the names of the steps cannot be recovered, and it lacks the secondary colors, Success and Error, the Highlight and Control backgrounds, and Link.

## 1. Values shared by every family

These stay the same whichever family is used.

| Category | Name | HEX | Use |
|---|---|---|---|
| Text | Text (Black) | `#000000` | On light backgrounds |
| Text | Text (White) | `#FFFFFF` | On dark backgrounds |
| Text | Label | `#626264` | Labels, notes, and other supporting text |
| Text | Link | `#0017C1` | Text that is a link |
| Background | Standard | `#F8F8FB` | Behind content such as figures, charts, and tables |
| Background | Control | `#F1F1F4` | Behind controls such as filters |
| Semantic | Success | `#197A4B` | A condition that is met, such as a target |

**Label is not `#000000`.** Axis labels, notes, and legends in the body color draw the eye before the data does.

Other values are set per family. First the Highlight background and Error.
The chart's Primary, Secondary, and Neutral colors and the semantic Positive and Negative are also per family (section 4).

| Family | Highlight background | Error |
|---|---|---|
| Solid Gray | `#4D4D4D` | `#CE0000` |
| Blue | `#0017C1` | `#CE0000` |
| Light Blue | `#0055AD` | `#CE0000` |
| Cyan | `#006F83` | `#CE0000` |
| Green | `#115A36` | `#CE0000` |
| Orange | `#AC3E00` | `#850000` |
| Red | `#CE0000` | `#850000` |

Orange and Red are warning colors themselves, so their Error moves to the darker value.

## 2. The step numbers

A larger number is darker. There are six steps: `1200 / 900 / 600 / 400 / 200 / 50`.

**The key color is 600**, not 500.

On a white background, a fill of step `600` or darker meets a contrast of 3:1.
A fill of step `400` or lighter needs the number shown right beside it, or shown on hover.

Solid Gray alone steps as `900 / 700 / 536 / 400 / 200 / 50`.
`536` comes from the design system and is **the only step that meets 4.5:1 on both white and black**. Do not round the number.

## 3. Roles of the chart colors

The color palette page lists the colors without their roles. The roles are in §4.3 of the guidebook, on how the palette is built.

| Role | Definition | Assigned (in the Blue family) |
|---|---|---|
| **Primary** | The base color for the main data of a chart | The family's 6 steps |
| **Secondary** | A supporting color for highlights and for telling several series apart | 3 steps of Yellow |
| **Neutral** | A quiet color for data that needs no emphasis, and for **what is compared with** | 4 steps of SolidGray |
| Others | | 2 steps of Red |

The choice follows mechanically:

1. The main series takes the family's color
2. A second series takes **the Secondary color**, not another step of the family's color
3. Targets, averages, and last year's values take Neutral

The third follows from the guidebook's design principle of giving something to compare with (chapter 3).

Secondary depends on the family: Green for Cyan, Cyan for Green, and Yellow for every other family.

**Pick the step of Secondary by its contrast.** Yellow 600 (`#D2A400`) has a contrast of 2.32, under 3:1, so a fill takes **800** (`#A58000`, contrast 3.69).
Green and Cyan meet 3:1 at 600 (3.45 and 3.00). The table of series colors per family is in `dos-donts.md`.

## 4. Every color code, by family

### Solid Gray

For a single series, a neutral look, or printing first.

| Category | Name | HEX |
|---|---|---|
| Chart | SolidGray 900 | `#1A1A1A` |
| Chart | SolidGray 700 | `#4D4D4D` |
| Chart | SolidGray 536 | `#767676` |
| Chart | SolidGray 400 | `#999999` |
| Chart | SolidGray 200 | `#CCCCCC` |
| Chart | SolidGray 50 | `#F2F2F2` |
| Chart (Secondary) | Yellow 800 / 600 / 400 | `#A58000` / `#D2A400` / `#FFC700` |
| Semantic Positive | Blue 600 / 200 / 50 | `#3460FB` / `#C5D7FB` / `#E8F1FE` |
| Semantic Negative | Red 600 / 200 / 50 | `#FE3939` / `#FFBBBB` / `#FDEEEE` |

### Blue

The Digital Agency's standard, for official public services and trust.

| Category | Name | HEX |
|---|---|---|
| Chart | Blue 1200 | `#000060` |
| Chart | Blue 900 | `#0017C1` |
| Chart | Blue 600 | `#3460FB` |
| Chart | Blue 400 | `#7096F8` |
| Chart | Blue 200 | `#C5D7FB` |
| Chart | Blue 50 | `#E8F1FE` |
| Chart (Secondary) | Yellow 800 / 600 / 400 | `#A58000` / `#D2A400` / `#FFC700` |
| Chart (Neutral) | SolidGray 800 / 600 / 400 / 200 | `#333333` / `#666666` / `#999999` / `#CCCCCC` |
| Semantic Positive | Blue 600 / 200 / 50 | `#3460FB` / `#C5D7FB` / `#E8F1FE` |
| Semantic Negative | Red 600 / 200 / 50 | `#FE3939` / `#FFBBBB` / `#FDEEEE` |

### Light Blue

Public services, education, and a friendly look.

| Category | Name | HEX |
|---|---|---|
| Chart | LightBlue 1200 | `#00234B` |
| Chart | LightBlue 900 | `#0055AD` |
| Chart | LightBlue 600 | `#008BF2` |
| Chart | LightBlue 400 | `#57B8FF` |
| Chart | LightBlue 200 | `#C0E4FF` |
| Chart | LightBlue 50 | `#F0F9FF` |
| Chart (Secondary) | Yellow 800 / 600 / 400 | `#A58000` / `#D2A400` / `#FFC700` |
| Chart (Neutral) | SolidGray 800 / 600 / 400 / 200 | `#333333` / `#666666` / `#999999` / `#CCCCCC` |
| Semantic Positive | LightBlue 600 / 200 / 50 | `#008BF2` / `#C0E4FF` / `#F0F9FF` |
| Semantic Negative | Red 600 / 200 / 50 | `#FE3939` / `#FFBBBB` / `#FDEEEE` |

### Cyan

The basic choice for data visualization and analysis.

| Category | Name | HEX |
|---|---|---|
| Chart | Cyan 1200 | `#003741` |
| Chart | Cyan 900 | `#006F83` |
| Chart | Cyan 600 | `#00A3BF` |
| Chart | Cyan 400 | `#2BC8E4` |
| Chart | Cyan 200 | `#99F2FF` |
| Chart | Cyan 50 | `#E6FCFF` |
| Chart (Secondary) | Green 800 / 600 / 400 | `#197A4B` / `#259D63` / `#51B883` |
| Chart (Neutral) | SolidGray 800 / 600 / 400 / 200 | `#333333` / `#666666` / `#999999` / `#CCCCCC` |
| Semantic Positive | Cyan 600 / 200 / 50 | `#00A3BF` / `#99F2FF` / `#E6FCFF` |
| Semantic Negative | SolidGray 600 / 200 / 50 | `#666666` / `#CCCCCC` / `#F2F2F2` |

From Cyan on, Negative is gray instead of red. Red is kept as a meaning color so it does not clash with the family's color.

### Green

Success, health, and targets met.

| Category | Name | HEX |
|---|---|---|
| Chart | Green 1200 | `#032213` |
| Chart | Green 900 | `#115A36` |
| Chart | Green 600 | `#259D63` |
| Chart | Green 400 | `#51B883` |
| Chart | Green 200 | `#9BD4B5` |
| Chart | Green 50 | `#E6F5EC` |
| Chart (Secondary) | Cyan 800 / 600 / 400 | `#008299` / `#00A3BF` / `#2BC8E4` |
| Chart (Neutral) | SolidGray 800 / 600 / 400 / 200 | `#333333` / `#666666` / `#999999` / `#CCCCCC` |
| Semantic Positive | Green 600 / 200 / 50 | `#259D63` / `#9BD4B5` / `#E6F5EC` |
| Semantic Negative | SolidGray 600 / 200 / 50 | `#666666` / `#CCCCCC` / `#F2F2F2` |

### Orange

Caution and energy.

| Category | Name | HEX |
|---|---|---|
| Chart | Orange 1200 | `#541E00` |
| Chart | Orange 900 | `#AC3E00` |
| Chart | Orange 600 | `#FB5B01` |
| Chart | Orange 400 | `#FF8D44` |
| Chart | Orange 200 | `#FFC199` |
| Chart | Orange 50 | `#FFEEE2` |
| Chart (Secondary) | Yellow 800 / 600 / 400 | `#A58000` / `#D2A400` / `#FFC700` |
| Chart (Neutral) | SolidGray 800 / 600 / 400 / 200 | `#333333` / `#666666` / `#999999` / `#CCCCCC` |
| Semantic Positive | Orange 600 / 200 / 50 | `#FB5B01` / `#FFC199` / `#FFEEE2` |
| Semantic Negative | SolidGray 600 / 200 / 50 | `#666666` / `#CCCCCC` / `#F2F2F2` |

### Red

Danger, errors, and targets missed.

| Category | Name | HEX |
|---|---|---|
| Chart | Red 1200 | `#620000` |
| Chart | Red 900 | `#CE0000` |
| Chart | Red 600 | `#FE3939` |
| Chart | Red 400 | `#FF7171` |
| Chart | Red 200 | `#FFBBBB` |
| Chart | Red 50 | `#FDEEEE` |
| Chart (Secondary) | Yellow 800 / 600 / 400 | `#A58000` / `#D2A400` / `#FFC700` |
| Chart (Neutral) | SolidGray 800 / 600 / 400 / 200 | `#333333` / `#666666` / `#999999` / `#CCCCCC` |
| Semantic Positive | Red 600 / 200 / 50 | `#FE3939` / `#FFBBBB` / `#FDEEEE` |
| Semantic Negative | SolidGray 600 / 200 / 50 | `#666666` / `#CCCCCC` / `#F2F2F2` |

## 5. Colors for formatting only

Colors used outside the data series. They come from the formatting inside the templates.

| HEX | Use |
|---|---|
| `#E6E6E6` | Grid lines and table rules |
| `#949494` | Dividers, slicer borders, and sliders |

`#949494` is not on the color palette page; it exists only inside the templates.

## 6. Contrast

| What | Ratio needed |
|---|---|
| A chart's colored area against the background | **3:1 or more** |
| Text against the background | **4.5:1 or more** |

The design system asks 4.5:1 for text of every size. WCAG allows 3:1 for large text, but the design system does not use that allowance.

When a color cannot meet the ratio, there are two ways out:

1. Write the number right next to the colored area (the number itself meets 4.5:1)
2. Show the number on mouse-over or keyboard focus

### Compute the contrast before proposing a color

Before proposing or using a new color, compute its contrast on white and state the value.
Write one line per color: `Hex (#XXXXXX) - contrast N.NN on white -> 3:1 for a colored area met or missed`.
Do not propose a palette whose contrast was not computed. Contrast is a condition for using a color, not something checked afterwards.

Steps `600` and darker of the 7 official families are already checked.
**Compute it every time for a step `400` or lighter, and for any color derived outside the 7 families.**

Examples that failed or passed:

- `#57B8FF` (LightBlue 400): 2.16, misses 3:1 for an area
- `#F39800` (an accent orange): 2.26, misses
- `#5A89C7` (a derived mid blue): 3.60, meets
- `#115A36` (Green 900): 8.27, meets

For a derived color, aim at **3.5 or more** instead of just over 3.0, because decimal rounding in sRGB and the display's gamma move the real contrast by 0.1-0.3.

## 7. How many colors

The guidebook says only the 10 colors most used in dashboard design are set, and that other colors should be chosen with reference to the colors of each palette.

Even when more than 10 are needed, **do not invent colors**; refer to the colors listed.
The checklist also asks whether the colors of a chart are limited to about one to five.

One family per dashboard, and at most five colors in one chart.

## 8. Color vision differences

- Never tell categories apart by color alone; add shapes, patterns, or legend text
- Check that the dashboard still reads in black-and-white print
- Use color universal design palettes and color vision simulators
- With three or more series, pair color with shape or color with pattern

Avoid red against green. The official templates also show a good KPI with a dark step of the family's color, not with green.

## 9. Formatting beyond color

Type sizes, spacing, and the formatting of each chart are in `theme-spec.md`.

## 10. Values that disagree between sources

Some colors are written differently in different sources. **The color palette page is right.**

| Item | Wrong | Right |
|---|---|---|
| Blue key color | `#4979F5` in the guidebook's body text (called Blue-500) | `#3460FB` (Blue 600) |
| Blue 50 (chart) | `#D9E6FF` in the figure on page 36 of the guidebook | `#E8F1FE` |
| Cyan 50 | `#E9F7F9` in the JSON inside the templates | `#E6FCFF` |

The name `Blue-500` in the guidebook's body text comes from an older version of the design system and does not match the templates that are handed out.
The figure on page 36 of the same PDF uses the right name; only the body text was left behind by the update.

## Sources

- §4.3 of the guidebook, on the color palette
- The color palette page of the guidebook (7 families in 4 categories, about 190 colors)
- The Digital Agency design system's color palette and color accessibility pages
- The theme definitions inside the `.pbit` templates (the formatting colors only)
