# Changelog

Releases of the product-deck plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The `product-deck` skill makes a product introduction deck: it takes screenshots of the real product first, decides the structure from ten base slides, has the user approve the plan and the text in the chat, and writes the files that build the slides in the user's repository, with every word in one data file and none in the layout code
- `audit.mjs` checks the rendered slides (text size, text cut off or outside the slide, overlaps of text and screenshots, screenshots too small or too coarse, text on the bottom margin, heading punctuation, banned words, explanations that do not end as sentences, and short last lines), and `audit-text.mjs` checks the wording from the deck's data (one thing called by different words, core words before their explanation, and the words of the user's own list). Both report what they counted and stop with exit 2 when a check looked at nothing
- `audit-text.mjs` reads the words to drop from `~/.product-deck/prose-words.txt` and the deck's terms from `~/.product-deck/writing-terms.txt` unless paths are passed, and runs no check when a list is missing
- The scripts that drive a browser take Playwright from the project named in `PLAYWRIGHT_FROM`, and samples of how to place screenshots are read from `~/.product-deck/samples/` only when that folder exists
