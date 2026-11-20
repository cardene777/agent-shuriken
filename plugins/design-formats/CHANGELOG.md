# Changelog

Releases of the design-formats plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- `formats/look.md` draws a change over time as a dragon line chart (`[shape: line]`), and the report template opens its figures with the daily sales of the week as a line chart across the full width. page-design follows the dragon skill's updated notation and chart guide
- The report and explainer templates give their figure cards and the enlarged view the card color as `--dragon-figure-background`, so a figure's background matches its card on light and dark pages, and the report centers each figure in its card. `formats/look.md` says to pass the card color, and page-design follows the dragon skill's updated embed and chart guides
- Pages draw their figures with dragon. `formats/look.md` says which figure fits which kind of information, the report template shows the sales by time of day as a bar chart and each kind's share as a donut, and the explainer shows the steps as a band of steps. Each figure is a still dragon block per language that `dragon embed` draws as an SVG. `verify` names a page that still holds a block, and `verify --source` checks a template before `dragon embed`. page-design follows the dragon skill's notation, embed guide, and the guides of the chart, cycle, flow, architecture, and sequence kinds through musubi as optional follows
- The report template puts the facts about the page on one quiet line under the title and the result numbers on one band, shows each value once, gives each row its amount instead of an unlabeled bar, and shows no paging when the list fits on one page. `formats/look.md` holds these as rules

- The samples in the four page templates, `formats/look.md`, and the README all use one small bakery: the weekly sales report, the items to take off the winter menu, how to brew pour-over coffee, and the layout of the menu board
- `verify` also names a title kept per language, such as `title: { en: "Bakery: weekly sales", ja: "..." }` in a page's data, when one of its texts has a colon or a Japanese comma or period
- The report template shows facts and numbers that differ by language, and the approval sheet writes amounts with the yen sign in English and with the Japanese word for yen after the number in Japanese

## [0.1.0] - 2026-11-20

First public release.

- The `page-design` skill holds how documents and reports explain (`formats/structure.md`) and how they look (`formats/look.md`), and four self-contained HTML page templates: a report with details beside the list, an approval sheet, an explainer with a contents list and a glossary, and a choice page that keeps today's version as an option. Skills follow it through musubi, which pins each content's version and fingerprint
- `page-design.py verify` names each line of a page or a Markdown document with a colon or a Japanese comma or period in a heading, facts crammed into one line, or a label joined with a colon, and each page with text under 12px, no language or theme switch, no dictionary, no dark colors, motion without the reduced-motion setting, or a file read from another site, with how to fix it and without printing the page's text

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/design-formats--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/design-formats--v0.1.0
