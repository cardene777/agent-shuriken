# Conventions for finance dashboards

## Where they apply

Treasury (total assets, stablecoins in USD and JPY, money market funds, bank balances), trading (exchange rates, volume, profit and loss), credit portfolios, customer assets over time, and payment dashboards.

## Key patterns

| Element | Recommended | Why |
|---|---|---|
| Headline KPI | Top left, large (56-72px), with secondary KPIs (awaiting approval, unsettled balances) in the right column | §3.4 and the treasury convention: what needs an immediate decision top left, what needs an action in the right column |
| CSV and Excel buttons | **Both in the toolbar at the top right and at the right of each chart's header** | Finance analyzes and audits often, so exporting is a main operation (the SaaS convention, in part) |
| Main charts | Lines (change over time), areas (stacked composition), and a table (transaction history) | §4.2; assets over time are continuous, which suits lines |
| Dual axes | **Allowed** (yen and percent, amount and count; the exception of §4.5) | A practice of the trade, such as an exchange rate shown with its rate of change |
| Accent color | Reserved for one or two meanings (a call to buy, an important notice), never for chart series | Chart series take tints of the primary color |
| Density | Medium to high (4-6 KPIs, 2-3 charts, a table of 5 rows, 2-4 fund cards) | Meant for professionals; high density is fine |
| Footer | 3-5 data definitions (where balances come from, the source of yields, the benchmark, the update frequency, accessibility) | Audit trails need the sources stated |
| Icons | No decorative icons; currency badges as text (USD, JPY, BTC) are fine | §4, and telling currencies apart carries meaning |
| The date the data is from | State T+1 (such as "the price is the previous business day's close") | Financial data is delayed by nature, and the delay is stated |
| Status badges | Done (green), awaiting approval (amber), rejected (red), processing (purple): four colors, each with a symbol | §5.5, not by color alone |

## What to avoid

- Gradients or shadows on the hero area: use one solid primary fill
- The accent color spilling into chart series: replace it with primary tints
- The accent color on the awaiting-approval KPI (it reads as a call to act): use the warning state color
- Broken axes (non-linear ticks on the Y axis): keep the ticks evenly spaced
- Too much in the footer (6 or more items): keep it to 3-5

## Basis

The presentation dashboard of §1.1 of the Digital Agency's "Practical guidebook for dashboard design" (figures, charts, and tables) fits finance fully, and the practice of the trade falls under the dual axes that §4.2 allows for one event at two grains.
