# Writing numbers

How to write numbers on a dashboard in any field, built on three points of the Digital Agency's "Practical guidebook for dashboard design" (edition of 2026-03-31): short units and series names (§4.5), no waiting (§4.4), and never meaning by color alone (§5.5).
Read it when a field writes its numbers its own way, as in finance, manufacturing, medicine, education, or retail.
The Japanese units and date forms below are the forms a Japanese dashboard shows.

## 1. Units (locale ja-JP)

| Range | Written as | Example | Helper |
|---|---|---|---|
| 0 to 999 | As is | `856` | `n.toLocaleString("ja-JP")` |
| 1,000 to 9,999 | With commas | `5,840` | The same |
| 10,000 to 99,999,999 | In units of ten thousand (optional) | `1.2万` / `5,840万` | A custom `FMT_MAN(n)` |
| 100,000,000 to 9,999,999,999,999 | In units of a hundred million | `1.5億` / `12.3億` | A custom `FMT_OKU(n)` |
| 10,000,000,000,000 and more | In units of a trillion | `1.2兆` | A custom `FMT_CHO(n)` |
| A thousand and more, for English readers | K / M / B | `5.8K` / `1.2M` | A custom `FMT_K(n)` |

### 1.1 Helpers

```js
const FMT_INT = (n) => n.toLocaleString("ja-JP");
const FMT_K = (n) => n >= 1000 ? `${Math.round(n / 100) / 10}K` : `${n}`;
const FMT_MAN = (n) => n >= 10000 ? `${Math.round(n / 100) / 100}万` : FMT_INT(n);
const FMT_OKU = (n) => n >= 100_000_000 ? `${Math.round(n / 10_000_000) / 10}億` : FMT_MAN(n);
const FMT_CHO = (n) => n >= 1_000_000_000_000 ? `${Math.round(n / 100_000_000_000) / 10}兆` : FMT_OKU(n);
```

### 1.2 Which helper

| Kind of dashboard | Helper | Why |
|---|---|---|
| Public sector, national | FMT_MAN / FMT_OKU | Counts, people, and amounts run from ten thousands to hundred millions |
| Finance, domestic trading | FMT_OKU / FMT_CHO | Balances and trades run from hundred millions to trillions |
| Finance, personal assets | FMT_INT / FMT_MAN | Amounts must be exact to the yen |
| Global finance | FMT_K / FMT_M / FMT_B | The international notation |
| Retail and online shops | FMT_INT / FMT_MAN | Customers and sales run from thousands to ten thousands |
| SaaS and IT | FMT_INT / FMT_K | Active users and counts |
| Medical (patients, tests) | FMT_INT / FMT_MAN | Thousands to ten thousands |

## 2. Currencies

| Currency | Symbol | Example | Note |
|---|---|---|---|
| Japanese yen (JPY) | After | `1,200円` or `¥1,200` | Public dashboards prefer `円`; `¥` is fine on personal web pages |
| US dollar (USD) | Before | `$1,200` | Two decimals (`$1,200.50`) |
| Euro (EUR) | Before or after, by country | `€1,200` / `1.200,00 €` | Follow each country's locale |
| Pound sterling (GBP) | Before | `£1,200` | Two decimals |
| Korean won (KRW) | After | `1,200원` or `₩1,200` | No decimals |
| Crypto assets (BTC, ETH) | After | `0.05 BTC` / `1.234 ETH` | A fixed number of decimals, 8 (satoshi) or 18 (wei) |

### 2.1 Mixed currencies

Do not put several currencies in one chart (§4.5, no distortion). When it is unavoidable, convert to one base currency and state the rate and the date of the conversion in the footer.

## 3. Percentages

| Use | Written as | Decimals | Example |
|---|---|---|---|
| Headline KPI | One decimal | `70.2%` | Progress, utilization |
| A rate cell in a table | No decimals | `70%` | Side by side in a table of 47 rows |
| Comparison (month over month, year over year) | `+` or `-` with the digits | `+1.3 pt` / `-2.5%` | Tell percentage points (pt) from percent |
| Shares (donut) | One decimal | `29.2%` | Always with the counts in the legend |

### 3.1 Percentage helpers

```js
const PCT = (n, digits = 1) => `${(n * 100).toFixed(digits)}%`;
const PCT_PT = (n) => `${n >= 0 ? "+" : ""}${(n * 100).toFixed(1)} pt`;
```

## 4. Negative values

| Field | Written as | Example |
|---|---|---|
| Public sector | `-N` (a minus sign and the number) | `-1,200` |
| Finance (accounting, audit) | `(N)` (in parentheses) | `(1,200)`, as the trade writes it |
| Finance (web pages for users) | `-N` in red | `-1,200` in the negative state color |
| Everywhere | Never by color alone (§4.5): always a sign or a shape mark too | `▼ -1.5%` (the sign and ▼) |

## 5. Fixed decimals and aligned digits

Always apply `font-variant-numeric: tabular-nums` in CSS so columns line up, and give SVG text inside charts the attribute `font-variant-numeric="tabular-nums"`.

```css
.kpi-value, .num, .data-label {
  font-variant-numeric: tabular-nums;
}
```

```html
<text font-variant-numeric="tabular-nums">{value}</text>
```

## 6. Dates and times

| Use | Written as | Example |
|---|---|---|
| Monthly X axis, short | `YYYY/M` | `2025/6` |
| Monthly X axis, full | `YYYY年M月` | `2025年6月` |
| Daily X axis, short | `M/D` | `6/8` |
| Date and time | `YYYY-MM-DD HH:mm` | `2026-06-08 14:30` |
| The date the data is from (footer) | `YYYY-MM-DD` | `2026-05-31` |
| Time zone (global dashboards) | `+09:00 (JST)` | `2026-06-08 14:30 +09:00 (JST)` |
| Business days against calendar days | Marked with an abbreviation | `2026-06-08 (Mon, BD)`, where BD is a business day |

## 7. Checking the numbers

When looking over the drawn screens, check:

| Point | Passes when |
|---|---|
| Units agree | One chart does not mix units such as ten thousands and single counts |
| Decimals agree | The headline KPI and the table's footer use the same number of decimals |
| Currency symbols | Placed as the locale says (`円` after, `$` before) |
| Negative signs | `(N)` in parentheses or a colored `-N`, with a second cue |
| Aligned digits | Number columns line up vertically |

A miss does not hurt legibility directly but breaks the convention, so fix it.

## 8. Related files

- `chart-decision-tree.md` section 8, on where number labels go
- §4.4 of the guidebook, on clear labels (units in titles and series names)
- `abstraction-principles.md` section 5.2, on not distorting
