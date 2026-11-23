# Changelog

Releases of the product-deck plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.2.0] - 2026-11-23

- `audit-text.mjs` runs its built-in rules (one thing called by different words, core words before their explanation, and a person doing a thing's action) when `~/.product-deck/prose-words.txt` is missing, and says that no word list was found instead of stopping; a list in the home folder or passed with `--prose-words` adds its checks as before, and a passed path that does not exist still stops with exit 2
- The new `theme.mjs` reads `.design-theme.json` at the root of the repository, or else `~/.design-theme.json`, the theme file design-formats also reads, and prints the main color, neutrals, fonts, and corners as CSS variables that every style of the deck takes; without a theme the agent picks one main color as before, and a file with an unknown key or a bad value is refused with exit 2, naming each key
- The test that scans the plugin for private names looks only for general shapes: a home folder path, a local agent configuration folder, and an issue reference

## [0.1.0] - 2026-11-22

- The `product-deck` skill makes a product introduction deck: it takes screenshots of the real product first, decides the structure from ten base slides, has the user approve the plan and the text in the chat, and writes the files that build the slides in the user's repository, with every word in one data file and none in the layout code
- `audit.mjs` checks the rendered slides (text size, text cut off or outside the slide, overlaps of text and screenshots, screenshots too small or too coarse, text on the bottom margin, heading punctuation, banned words, explanations that do not end as sentences, and short last lines), and `audit-text.mjs` checks the wording from the deck's data (one thing called by different words, core words before their explanation, and the words of the user's own list). Both report what they counted and stop with exit 2 when a check looked at nothing
- `audit-text.mjs` reads the words to drop from `~/.product-deck/prose-words.txt` and the deck's terms from `~/.product-deck/writing-terms.txt` unless paths are passed, and runs no check when a list is missing
- The scripts that drive a browser take Playwright from the project named in `PLAYWRIGHT_FROM`, and samples of how to place screenshots are read from `~/.product-deck/samples/` only when that folder exists

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/product-deck--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/product-deck--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/product-deck--v0.1.0
