# Changelog

Releases of the mechanism-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- One skill, `mechanism-explainer`, that writes an explainer page where each section answers one question with a one-sentence answer and two to four figures drawn in the dragon notation
- The agent plans the questions and figures first and writes the page only after you agree with the plan
- The page is written as dragon's guide Markdown, checked with `dragon check` and `dragon check --layout`, and exported with dragon 0.80.1 through `npx`, with a copy that opens offline
- `scripts/to-pdf.py` prints the page to a PDF on A3 paper by default with a Chromium-based browser already on the machine
- The skill follows the `plan`, `page`, `notation`, and `cheatsheet` formats of the `dragon` skill through musubi as optional follows
