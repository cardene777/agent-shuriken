# Changelog

Releases of the slides plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.1] - 2026-11-22

- The `slide-builder` test no longer spells out the names of the maintainer's private decks. It still checks that no file holds a home path, a local Codex path, an issue reference, or the name of the private configuration repository

## [0.1.0] - 2026-11-22

- The `slide-builder` skill writes the Markdown outline (`slides-outline.md`) of an explanatory deck of ten or more slides, with each slide's takeaway, explanation, and figure described in words for a non-engineer audience, and `examples/slides-outline.md` shows a complete ten-slide outline
- `validate.py` checks an outline with the Python standard library only. It rejects a slide without its heading, meta line, or takeaway, numbers out of order, and a figure without its list of elements, naming the slide, and flags general code words such as function and class, plus any word given with `--ban` for the deck's own field. An outline written in Japanese may use the Japanese spellings of the headings that `outline-headings.json` lists
- The `slide-forge` skill designs a one-slide or short presentation as HTML in one of four tones, adds a toolbar for editing the text in the browser, in English by default with a switch to Japanese, and exports PowerPoint, HTML, and PDF into `decks/<deck-name>/` in your project
- `export_all.sh` runs the PowerPoint builder through `uv run --with python-pptx --with Pillow` and the PDF through `uv run --with playwright`, so nothing is installed into your Python. Without uv, it writes nothing and says how to install uv; without Playwright's browser, it skips only the PDF, says how to install the browser, and never downloads it

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/slides--v0.1.1...HEAD
[0.1.1]: https://github.com/cardene777/agent-shuriken/releases/tag/slides--v0.1.1
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/slides--v0.1.0
