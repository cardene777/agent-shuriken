# Changelog

Releases of the design-formats plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

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
