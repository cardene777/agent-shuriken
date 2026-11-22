# Matching the official finished dashboard

The finished dashboard on page 11 of the user manual (`manual.pdf`, downloaded by `scripts/fetch_official.py`) of the Digital Agency's design templates, fixed here as visual rules to design against.
Reading the guidebook clause by clause misses some differences from that example: a monthly trend drawn as a lone line, the default grid lines of a chart library, an added breadcrumb, a large total in the donut's center, and a dashed target line lost in the grid.
These are matters of presentation and convention, so they are written down here.
The rules for dual axes are in `chart-decision-tree.md`, section 2, under "When two axes are right".

## The rules, taken from page 11 of the manual

### 1. Layout

- **Left column (filters)**: a vertical list of radio buttons under the heading "Select a region"
- **Center, top**: KPI A (the online usage rate, 0.7) and KPI B (the number of online uses), large, on solid blue
- **Center, middle**: a donut and its legend, the legend **in a column to the right of the donut**
- **Center, bottom**: **a column chart** of the monthly trend
- **Right column**: a tall table of the prefectures (47 rows, with data bars)

### 2. The monthly trend: bars, or bars with a line

The finished dashboard of page 11 draws bars for the count, a line for the rate, and a line for the prefectures that went online, on two axes.

| Use | Chart |
|---|---|
| A monthly count only | One series of columns (simple, when one series is enough) |
| A monthly count with a rate | **Bars and a line on two axes**, as on page 11 (count as bars, rate as the line) |
| Several series over time | Small multiples (one line chart each) |

Building a count with a rate:

- A composed chart with the count as bars on the left axis and the rate as a line on the right axis
- The bars in the family's step 200 as a light fill, the line in step 600
- A legend built beside the chart, in its header, not the chart library's default legend
- Still no fixed reference line at a count taken from an overall percentage, because the monthly totals differ and the line would mislead

### 3. Two value axes are allowed

Two axes are fine only when:

- The main axis (the count) and the second axis (the rate) show **the same event at two grains**
- The ranges follow `chart-decision-tree.md`, section 8.1, "Ranges of the Y axes" (the count axis at 1.4-1.6 times the largest value, bars at most 60-65% of the plot height, the end of the line at most 80% of it)
- The legend says which series uses the left axis and which the right
- The two axes do not measure unrelated things, such as counts against temperature

Other ways to show a rate:

- Bars and a line on two axes (the pattern of page 11)
- The rate as a separate KPI (simple)
- Small multiples, a count chart beside a rate chart (exploration)

### 4. No grid lines

Section 5 of page 11 of the manual says to hide the grid. Leave out the chart library's default grid, or make it fully transparent.

```tsx
// Wrong: the default shows the grid
<CartesianGrid />

// Right: no grid
// leave CartesianGrid out, or
<CartesianGrid stroke="transparent" />
```

Faint horizontal lines at the Y axis ticks are used on page 11 too (`horizontal={true} vertical={false}` with a step-200 gray).
The rule is **faint horizontal lines only**, not no lines at all.

### 5. No breadcrumb

The finished dashboard of page 11 has **no** breadcrumb (Home › Dashboards › ...). A dashboard is meant to fit one screen; a breadcrumb comes from the conventions of the surrounding application.

The exception is a multi-page dashboard that moves from a parent page to child pages. A dashboard on its own gets no breadcrumb.

### 6. The donut's center: quiet, or empty

The donut of page 11 shows no number in its center, or a very quiet one. A bold 16px "84,757 in total" there is not the official look.

- Best: nothing in the center
- Acceptable: a small label ("Total") with the value in the control color and a small size

### 7. Numbers beside the data bars of a table

The table of page 11 shows the data bar (blue fill) and the number **in separate areas**. A number laid over the end of the bar on a half-transparent white patch is not the official look.

```tsx
// As on page 11
<td className="grid grid-cols-[1fr_auto] gap-2 items-center">
  <div className="relative h-5"><div className="bg-[var(--theme-key)]" style={{width: pct + '%'}} /></div>
  <span className="font-mono">{value.toLocaleString()}</span>
</td>
```

### 8. The development indicator of the framework

A screenshot taken in a development server can show the framework's development indicator (in Next.js, a blue dot at the bottom left). A production build hides it; for screenshots in development mode, turn it off (`devIndicators: false` in `next.config.js` or `next.config.ts`).

## The structure of the finished dashboard

```
The finished dashboard of page 11:

┌─────────────────────────────────────────────────────────────────┐
│ [Title] Online usage of the procedure                           │  <- no breadcrumb
├────────────┬───────────────────────────┬────────────────────────┤
│ Filters    │ [KPI A: 0.7]              │ Tall table of the      │
│            │                           │ prefectures (47 rows)  │
│ - Hokkaido │ [KPI B: 5,832 thousand]   │ Ibaraki  ▓▓ number     │
│ - Tohoku   │                           │ Tochigi  ▓  number     │
│ - Kanto  ● │ ┌─ donut ─┐  legend       │ Gunma    ▓▓ number     │
│ - Chubu    │ │  ring   │  - in use     │ ...                    │
│ - Kinki  ● │ │  empty  │  - considering│ (scrolls)              │
│ - Shikoku ●│ │  center │  - not in use │                        │
│ - Kyushu   │ └─────────┘               │                        │
│            │ ┌── column chart ───────┐ │                        │
│            │ │  ▓ ▓ ▓ ▓ ▓ ▓ ▓ ▓      │ │  <- no grid            │
│            │ │  25/6 25/7 ... 26/5   │ │    (faint horizontal   │
│            │ └───────────────────────┘ │     lines only)        │
├────────────┴───────────────────────────┴────────────────────────┤
│ Footer: source of the survey and the date the data is from      │
└─────────────────────────────────────────────────────────────────┘
```

## Checking the drawn screens

- Read this file before looking over the drawn screens
- Compare the screens with the structure of page 11 of the manual
- Take screenshots at three widths (desktop, tablet, mobile) and show them to the user

## Related

- Page 11 of `manual.pdf`, the finished dashboard these rules come from
- `chart-decision-tree.md`, the choice of chart and the placement of labels
