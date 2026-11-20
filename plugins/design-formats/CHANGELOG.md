# Changelog

Releases of the design-formats plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-20

First public release.

- The `page-design` skill holds how documents and reports explain (`formats/structure.md`) and how they look (`formats/look.md`), and four self-contained HTML page templates: a report with details beside the list, an approval sheet, an explainer with a contents list and a glossary, and a choice page that keeps today's version as an option. Skills follow it through musubi, which pins each content's version and fingerprint
- `page-design.py verify` names each line of a page or a Markdown document with a colon or a Japanese comma or period in a heading, facts crammed into one line, or a label joined with a colon, and each page with text under 12px, no language or theme switch, no dictionary, no dark colors, motion without the reduced-motion setting, or a file read from another site, with how to fix it and without printing the page's text

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/design-formats--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/design-formats--v0.1.0
