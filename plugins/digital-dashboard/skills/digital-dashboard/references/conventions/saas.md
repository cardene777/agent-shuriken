# Conventions for SaaS dashboards

## Where they apply

Monthly active users, monthly recurring revenue, churn rate, NPS, conversion rate, daily over monthly active users, feature adoption, and conversion funnels.

## Key patterns

| Element | Recommended | Why |
|---|---|---|
| Headline KPI | Top left, large, with a sparkline to its right | The SaaS convention shows the number and its trend together |
| CSV and Excel buttons | **In the toolbar at the top right and per chart** | SaaS teams export often to share in chat and email; it is a main operation |
| Main charts | Lines (active users and revenue over time), areas (retention cohorts), and funnels (conversion stages) | Funnels and cohort heat maps are fine, as the field uses them |
| Change badges | On every KPI (month over month, week over week in %), with color and an arrow | Growth is the main interest |
| Accent color | Reserved for one meaning (a call to upgrade or start a trial, or a target met), never for chart series | Charts take a categorical palette of primary tints or state colors |
| Density | High (6-8 KPIs, 3-4 charts, a table of 10 rows) | Meant for professionals and administrators, who take in the whole at high density |
| Footer | The data source, the last update, the refresh interval, and a link to the documentation | SaaS states where its data comes from |
| Icons | No decorative icons; status icons (✓ ⧗ ✕) are fine | §4, and statuses carry a second cue |
| Trend | A sparkline inside each KPI card | A static number and its trend in one view |
| Filters | Tabs at the top (period, segment) and a sidebar at the left (dimensions) | The usual analytics layout |

## What to avoid

- A gradient on the hero area (an old SaaS pattern): use one solid primary fill
- Vanity figures (a running total of millions) in the hero area: put actionable figures first (active users, revenue, churn)
- Too much density (10 or more KPIs, 5 or more charts): move details behind a drill-down
- The accent color spilling into data series: use primary tints or state colors
- A funnel that shows only absolute numbers: add the rate against the previous stage (%)

## Basis

The presentation dashboard of §1.1 of the Digital Agency's "Practical guidebook for dashboard design" (spotting anomalies and deciding the next action) fits SaaS analytics, and the field's practice falls under the dual axes §4.5 allows, such as active users with the churn rate over the same period.
