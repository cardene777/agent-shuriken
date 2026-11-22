# Conventions for public sector dashboards

## Where they apply

Policy progress, local government KPIs, the issuing rate of identity cards, education statistics, the use of public services, and the share of administrative procedures done online. This is the field of the finished example on page 11 of the guidebook's user manual.

## Key patterns

| Element | Recommended | Why |
|---|---|---|
| Headline KPI | Top left, large (56-72px) | §3.4, the eye moves from top left to bottom right; the whole comes first |
| CSV and Excel buttons | **Near the footer, or at the end of the summary paragraph** | A public dashboard is mainly read; exporting is secondary (a toolbar at the top right is a SaaS convention, not this field's) |
| Main charts | Lines (trends over time), bars (comparison by region or year), and a table (the 47 prefectures) | §4.2 and the official templates of §5.1 |
| Dual axes | Only for one event at two grains, as page 11 shows a count with its rate (`chart-decision-tree.md`, section 2); never for a single series | §4.5, avoid misunderstanding |
| Accent color | Reserved for one meaning, such as emphasizing the key figure or a high rate of progress | One meaning per accent |
| Density | Low to medium (4-6 KPIs, 1-2 charts, 1 table) | Meant for the general public, §3.2, the right amount of information |
| Footer | The source (left) and the date the data is from (right), two lines of small gray text | The pattern of the finished example |
| Icons | None, except the download mark of the CSV button | §4, no decoration |
| Grid lines | Faint horizontal lines only | `visual-ssot.md`, section 4 |

## What to avoid

- An export button in a toolbar at the top right (a SaaS convention mixed in)
- A dark hero area (gradients, shadows, black backgrounds): use one solid primary fill
- High density (8 or more KPIs, 3 or more charts): the general public cannot take it in
- Trade abbreviations (KPI, MAU, MRR): use plain words

## Basis

The Digital Agency's "Practical guidebook for dashboard design": the presentation dashboard of §1.1, the public sector templates of §5.1, and the checklist of §5.4.
