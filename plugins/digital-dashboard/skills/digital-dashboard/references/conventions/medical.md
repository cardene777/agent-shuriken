# Conventions for medical dashboards

## Where they apply

ICU occupancy, patient counts (inpatient, outpatient, emergency), treatment outcomes, infection trends, bed occupancy, positive test rates, nurse staffing, and operating room schedules.

## Key patterns

| Element | Recommended | Why |
|---|---|---|
| Headline KPI | Top left, large, with its alert state (color and symbol) | Medicine is mainly about spotting anomalies; a threshold crossed must show at once |
| CSV and Excel buttons | In the footer or per chart; never in a toolbar at the top right | Audits and research are rare; the main operation is monitoring |
| Main charts | Lines (patients and vital signs over time), bars (comparison by ward), and a heat map (hour by weekday) | A heat map for shift analysis is fine, as the field uses it |
| Dual axes | Allowed (patient counts with the average length of stay; the exception of §4.5) | A practice of the field, to see correlations |
| Accent color | Reserved for one meaning (a threshold crossed, or urgent action needed), never for chart series | The alert keeps one clear meaning |
| Threshold lines | Each chart shows three lines: the normal range, warning, and critical | Judging thresholds is the main interest |
| Density | Medium (4-6 KPIs, 2-3 charts, an alert list of 5) | For medical staff: professionals, but speed of judgment comes first |
| Footer | The data source (electronic records, devices), the refresh interval, and a privacy notice | Medicine must state how personal data is handled |
| Icons | No decorative icons; alert icons (⚠ ✕) are fine | §4, and alerts always carry a second cue |
| Refresh rate | State it (30 seconds to 5 minutes) and show the time of the data large | Monitoring vital signs needs live data |
| Colors | Signal colors: red (critical), orange (warning), green (normal) | The field's signal convention, with care for color vision differences |

## What to avoid

- Gradients or shadows on the hero area: use one solid primary fill
- Alert colors used as decoration: red as decoration cannot be told from red as critical
- Old data shown without saying how fresh it is: show the time of the data large, with the refresh state (a loading indicator)
- Personal data of a patient in a headline KPI: totals only; single records behind a drill-down after a permission check
- Abbreviations of diseases without explanation: explain them where they first appear

## Basis

The presentation dashboard of §1.1 of the Digital Agency's "Practical guidebook for dashboard design" (spotting anomalies and deciding the next action) fits medical alert dashboards fully, and §5.5 (alternative information, not by color alone) applies directly to the field's signal colors.
