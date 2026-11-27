# Changelog

Releases of the mechanism-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.4.2] - 2026-11-27

- The page is exported with dragon 0.88.0. Each topic tab opens on its map and the one-sentence answers, and each question is its own page. The side menu shows no question numbers and lists the figure titles under the open question, which scroll to the figure when pressed, and each page ends with links to the previous and next pages

## [0.4.1] - 2026-11-27

- The number of questions and the kinds of material decide between one page and topic tabs. Material of one kind with five or fewer questions is one page, and six or more questions or more than one kind of material split the explainer into an overview tab and one tab per topic, so a plan can no longer put many questions into one topic and write one long page

## [0.4.0] - 2026-11-27

- An explainer with two or more topics is split into an overview tab and one tab per topic instead of one page per question. The plan sorts the material into the mechanism, background knowledge, records, and reference material, puts the mechanism first and records and reference material last, and moves a question after the topic it needs
- Every box of the overview figure that a topic explains links to that topic, so pressing the box opens its tab, and each topic tab opens with a map of the overview with that topic's boxes in color and the one-sentence answers of its questions
- The page is exported with dragon 0.87.0, which draws the topic tabs and the maps

## [0.3.0] - 2026-11-26

- An explainer with two or more topics is no longer one long page: it opens on an overview page and shows each question on its own page, with the side menu and links to the previous and next pages. An explainer with one topic stays one page
- The page is exported with dragon 0.85.0, which splits a guide page with two or more topics into pages and prints two steps of a figure to a sheet

## [0.2.0] - 2026-11-26

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

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/mechanism-explainer--v0.3.0...HEAD
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/mechanism-explainer--v0.3.0
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/mechanism-explainer--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/mechanism-explainer--v0.1.0
