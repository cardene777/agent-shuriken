# Changelog

Releases of the mechanism-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The page opens with an overview figure of the whole mechanism, written in the page lead before the first topic
- Every question heading ends with `[menu: <short name>]`, so the side menu lists it on one line
- Every figure has one sentence before it on what to look at and two to four sentences after it on what it shows
- The page is exported with dragon 0.82.0, which lists every question in a side menu numbered per topic, such as `2-1`, and prints the overview and every topic into the PDF with the box cards under each figure

## [0.1.0] - 2026-11-26

- One skill, `mechanism-explainer`, that writes an explainer page where each section answers one question with a one-sentence answer and two to four figures drawn in the dragon notation
- The agent plans the questions and figures first and writes the page only after you agree with the plan
- The page is written as dragon's guide Markdown, checked with `dragon check` and `dragon check --layout`, and exported with dragon 0.80.1 through `npx`, with a copy that opens offline
- `scripts/to-pdf.py` prints the page to a PDF on A3 paper by default with a Chromium-based browser already on the machine
- The skill follows the `plan`, `page`, `notation`, and `cheatsheet` formats of the `dragon` skill through musubi as optional follows

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/mechanism-explainer--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/mechanism-explainer--v0.1.0
