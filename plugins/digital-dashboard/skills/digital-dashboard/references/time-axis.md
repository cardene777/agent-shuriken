# Time axes

How to draw time axes in any field, built on two points of the Digital Agency's "Practical guidebook for dashboard design" (edition of 2026-03-31): conveying change and trend over time (§4.2) and not leaving the ticks of the value axis to automatic settings (§4.5).
It covers finance (seconds), the public sector (months), manufacturing (days and business days), and global dashboards (time zones).
The Japanese date forms below are the forms a Japanese dashboard shows.

## 1. Tick spacing

Chosen from the number of data points and the viewport width:

| Data points | Ticks | On a 1600 px viewport |
|---|---|---|
| up to 7 | Every point | One tick per 200 px |
| 8 to 12 | Every point | One tick per 120-180 px (as on page 11 of the guidebook) |
| 13 to 24 | Every other point | One tick per 130-200 px |
| 25 to 60 | Every fifth point | One tick per 100-200 px |
| 61 to 365 | Start of each month or week | 12-52 ticks |
| 366 and more | Start of each year or quarter | 4 or more ticks |

## 2. Tick labels by grain

| Grain | Short | Full | Used in |
|---|---|---|---|
| Second | `HH:mm:ss` | `2026-06-08 14:30:45` | High-frequency trading, live monitoring |
| Minute | `HH:mm` | `2026-06-08 14:30` | Call centers, SaaS monitoring |
| Hour | `HH時` | `2026-06-08 14時` | Service uptime, traffic |
| Day | `M/D` | `6/8` or `2026-06-08` | Daily production and sales reports |
| Week | `W{N}` | `2026 W23` (ISO week) | Sales, logistics |
| Month | `YYYY/M` | `2025年6月` | Public sector, management KPIs (as on page 11) |
| Quarter | `YYYY Q{N}` | `2026 Q1` | Financial reports |
| Year | `YYYY` | `2025` | Long-term trends |

## 3. Business days and calendar days

| Field | Business days | Written as |
|---|---|---|
| Finance (trading days) | Monday to Friday, without holidays | `2026-06-08 (Mon, BD)`, or only business days on the X axis |
| Manufacturing (working days) | The factory calendar | `2026-06-08 (Day 1)` |
| Logistics (delivery days) | Around the clock, every day | Calendar days as they are |
| Public sector | Mostly monthly totals | Calendar days matter little |

When only business days are shown, the points of weekends and holidays are missing, and the X axis closes the gaps.

## 4. Time zones

| Use | Written as |
|---|---|
| A domestic dashboard (one time zone) | `JST` once, at the end, such as in the footer |
| A global dashboard | `+09:00` on each tick, or everything in `UTC` |
| Exchange rates and international trades | UTC as the base, with the local time zone beside it |

A footer for a Japanese dashboard:
```
※ 全時刻は日本標準時 (JST、 UTC+09:00) です
```

## 5. No cut ranges (§4.5, no distortion)

| Wrong | Why | Instead |
|---|---|---|
| A line chart zoomed to `[60%, 80%]` on the Y axis | Exaggerates the change | Keep the Y axis at `[0, 100%]`, and add an inset chart for detail when needed |
| The X axis fixed to the last 7 days | Hides the long-term trend | A filter that switches between 7 days, 30 days, 90 days, and 1 year |
| Only the anomalies shown | Loses the whole picture | Show everything, and emphasize the anomalies with a reference line |

## 6. Which chart for a trend

| Data | Chart | Basis |
|---|---|---|
| One series over time (time and one measure) | A line | §4.2 |
| One series over time, emphasizing the count | Bars | §4.2, page 11 |
| A count and a rate together over time | Bars and a line on two axes | §4.2, page 11 |
| Several measures (3-5 series) | Small multiples (one line chart each) | §4.2 |
| A running total | An area chart (a line with a fill) | §4.2 |
| Seasons and cycles | A line with a moving average as a reference line | §4.5 |
| Finding anomalies | A line with upper and lower thresholds as reference lines | §3.2, something to compare with |

## 7. Checking the time axes

When looking over the drawn screens, check:

| Point | Passes when |
|---|---|
| Tick spacing | It fits the number of data points (the table in section 1) |
| Tick labels | All short or all full, never mixed |
| Time zone | Stated on a global dashboard |
| Cut ranges | The Y axis keeps `[0, max]` (always for bar charts) |
| Business days or calendar days | As the field expects |

A miss does not hurt legibility directly but breaks the convention, so fix it.

## 8. Related files

- `chart-decision-tree.md`, the tree in section 1 and the labels in section 8
- `numeric-format.md` section 6, on dates and times
- `abstraction-principles.md` section 5.2, on not distorting
