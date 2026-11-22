# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Design Formats reads, runs, and keeps, and every rule `verify` checks.
The agent of a following skill writes the page or the document; the script in `skills/page-design/scripts/` only checks it.

## Files in the skill

| File | What it holds |
|---|---|
| `SKILL.md` | The contents the skill provides, how to write a page or a document with them, and how to run `verify` |
| `agents/openai.yaml` | How Codex shows and starts the skill |
| `musubi.json` | The contents the skill provides through musubi: `structure`, `theme`, and the four pattern files at version 1.0.0, and `look`, `report`, `sheet`, `document`, `choice`, and `verify` at version 2.0.0 |
| `formats/structure.md` | The order of an explanation |
| `formats/look.md` | The look rules, ending with the table of rules `verify` checks |
| `formats/theme.md` | The user's theme file: where it lives, its keys, their types, and each template's defaults |
| `formats/patterns/details.md` | Where the details of a picked item appear, with the rules and their sources |
| `formats/patterns/lists-and-tables.md` | How a list or a table shows its rows, with the rules and their sources |
| `formats/patterns/input-and-confirmation.md` | How a page takes and confirms a choice or an input, with the rules and their sources |
| `formats/patterns/states-and-notices.md` | How a page shows states and notices, with the rules and their sources |
| `formats/patterns/sources.md` | The page, the kind, the date it was read, and a short quote of every source the pattern files cite |
| `templates/report.html` | The report page type |
| `templates/sheet.html` | The approval sheet type |
| `templates/document.html` | The explainer type |
| `templates/choice.html` | The choice page type |
| `scripts/page-design.py` | `verify`, the check of a page or a document, and `theme`, which writes the user's theme file into a page |
| `tests/test-page-design.sh` | Tests of `verify`, the formats, the templates, the declaration, and the plugin |
| `tests/test-followers.sh` | Tests that the report skills of this repository follow page-design, run from a checkout of the repository |

## How a skill follows page-design

A following skill names the contents it follows, such as `page-design/look` and `page-design/report`, in its own `musubi.json`, with a version range and the fingerprint of the content it last checked.
Its `SKILL.md` says to open `page-design` by name, read the file it names for each content, and what to do when `page-design` is not installed.
The agent copies the template of the page type, replaces `DATA` and the words in `TEXT`, and runs `verify` on the page.

| File | Which plugin | What it holds |
|---|---|---|
| `formats/structure.md`, `formats/look.md`, `formats/patterns/<topic>.md` | design-formats | The order of an explanation, the look rules, and the pattern rules |
| `templates/<type>.html` | design-formats | The frame of each page type, with sample data |
| `musubi.json` | The following skill | The range and fingerprint of each content it follows |

When a format, a template, or the script changes, its fingerprint changes, and `musubi check` refuses every following skill until that skill is checked again and its fingerprint is updated.

Ten skills in this repository follow page-design, each as an optional follow with the version range of the major version it was checked against, `^1.0.0` for `structure` and `^2.0.0` for the other contents, and `"optional": true`, so each plugin still installs and works alone.

| Skill | Plugin | What it follows |
|---|---|---|
| `techdebt` | techdebt | `structure`, `look`, `report`, `verify` |
| `compare-report` | compare-report | `structure`, `look`, `report`, `verify` |
| `machine-cleanup` | machine-cleanup | `structure`, `look`, `sheet`, `verify` |
| `account-cleanup` | account-cleanup | `structure`, `look`, `sheet`, `verify` |
| `diagram-explainer` | diagram-explainer | `structure`, `look`, `document`, `verify` |
| `repo-progress` | repo-progress | `structure` |
| `secure-dotfile` | secure-dotfile | `structure` |
| `init-project` | init-project | `structure` |
| `release-check` | evm-dev | `structure` |
| `portman` | portman | `structure` |

The five skills with HTML pages keep their own templates, because a plugin's scripts never read outside their own skill folder, and run `verify` on the finished page.
The five skills that report in the chat write the report in the order of `structure`: the result first, what was done and skipped with the reasons, values not measured written as not measured, and the user's steps last.
When design-formats is not installed, `musubi check` skips these follows with a warning, and each skill works without page-design.
`tests/test-followers.sh` checks the declarations, the lines in each `SKILL.md`, the templates, and `musubi check` with and without design-formats, from a checkout of this repository.

## How the templates work

Each template is one HTML file with its styles and script inside it.
Every string shown to people is in one dictionary, `TEXT`, with an `en` and a `ja` entry, and the report's content is in one object, `DATA`.
The header holds the English and Japanese buttons (`data-lang`) and the light and dark buttons (`data-theme-choice`).
The page starts in English and in the theme of the operating system, and keeps the chosen language and theme in the browser's local storage, under `page-design-lang` and `page-design-theme`.
The approval sheet and the choice page build the text copied back to the chat in `copyText()`, from fixed English words and item keys only, so a script reads it the same way in either language.
When the browser refuses to copy, the page selects the text and says to copy it with the keyboard.
The colors, the fonts, the text size and line height, the page width, and the three corner sizes are tokens on `:root`, and the dark colors are tokens in both dark blocks.
`page-design.py theme <page>` replaces those tokens with the values of the user's theme file, `.design-theme.json` at the root of the repository or else `~/.design-theme.json`, and `formats/theme.md` lists the keys.

The report and the explainer hold their figures as still dragon blocks, `<pre class="dragon" data-still>`, one block per language inside `<div data-figure-lang="en">` or `<div data-figure-lang="ja">`.
A rule in the style hides the blocks of the language the page does not show, so switching the language needs no drawing.
Each template carries the dragon entry line from jsDelivr, so the blocks draw when the template is opened as it is.
`npx -y @cardenelabs/dragon@<version> embed <page> --out <page>` draws every still block as an SVG of its last step, with no player, and removes the entry line, because no moving block is left.
The explainer builds its article from `DATA`, so its figures wait in a hidden `#figures` element and move into the article where a block names them.

## What verify checks

`verify <file>...` reads `.html` and `.htm` files as pages and `.md` files as documents.
`verify --source <file>...` checks the source of a page, such as a template, before `dragon embed`: it accepts still dragon blocks and the dragon entry line, and refuses a block without `data-still`.

| Rule | What it finds | Pages | Documents |
|---|---|---|---|
| `heading-punctuation` | A heading, a title, or a dictionary entry whose name holds title or heading, including each language's text in an entry such as `title: { en, ja }`, with a colon or a Japanese comma or period | Yes | Yes |
| `facts-in-one-line` | Three or more facts with numbers joined by commas in one line, also in a string of a page's script of any length, read with its escapes | Yes | Yes |
| `label-colon` | A label and a value joined with a colon or `=` | Yes | Yes |
| `small-text` | A font size under 12px or 0.75rem | Yes | No |
| `missing-lang` | An `<html>` element without `lang` | Yes | No |
| `missing-language-switch` | No `data-lang="en"` and `data-lang="ja"` buttons | Yes | No |
| `missing-theme-switch` | No `data-theme-choice="light"` and `data-theme-choice="dark"` buttons | Yes | No |
| `missing-dictionary` | No dictionary with an `en` and a `ja` entry | Yes | No |
| `missing-dark-colors` | No colors for `prefers-color-scheme: dark` | Yes | No |
| `missing-reduced-motion` | Transitions or animations without `prefers-reduced-motion` | Yes | No |
| `external-file` | A script, style, image, frame, or font read from another site; with `--source`, the dragon entry line is allowed | Yes | No |
| `figure-not-embedded` | A dragon block left on a page that `dragon embed` has not drawn | Yes | No |
| `figure-not-still` | With `--source`, a dragon block without `data-still` | Yes | No |
| `facts-not-table` | Facts in an element named `facts` that is not a `<table>`, including one a script builds as markup, or a facts row whose label is not a `<th scope="row">` | Yes | No |
| `sentence-per-line` | A Japanese full stop with more text after it on the same line, outside a closing bracket or quote | Yes | Yes |
| `list-detail-width` | A `.split` whose list column grows with the page, such as `1fr` or `minmax(0, 1.1fr)`, instead of keeping a fixed width | Yes | No |

In a page, text inside `script`, `style`, `code`, `pre`, `textarea`, and `svg` is not read as shown text, and the font sizes in a drawn figure's `svg` are not measured; strings in scripts are read only for titles and facts, and only when they hold no markup or code.
In a document, fenced code, tables, quotes, and HTML comments are skipped, and inline code is removed before a line is checked.

Each problem is one line, `<file>:<line>: <rule>: <how to fix>`, followed by a summary line, and the exit code is 1.
When nothing is wrong, it prints `page-design: ok (<n> files)` and exits 0.
It exits 2, with the reason on standard error, when no file is given, a file cannot be read, or a file is neither HTML nor Markdown.

## What it runs and connects to

`verify` reads the files you pass and prints to standard output and standard error.
It prints only file names, line numbers, rule names, and fixes, never the text of the page.
It runs no other program and connects to nothing.
To draw the figures, the agent runs `npx -y @cardenelabs/dragon@<version> check` and `embed`, which fetch the `@cardenelabs/dragon` package from the npm registry into npm's cache the first time; nothing is installed globally, and the page's text is sent nowhere.
Before `dragon embed`, a template loads dragon from jsDelivr through its entry line; after it, the page loads nothing from other sites.
`theme` reads the page and the theme file, writes only the page, runs no other program, and connects to nothing.

## What it keeps

`verify` and `theme` keep nothing, and `theme` never writes the theme file.
A page made from a template keeps the chosen language and theme in the browser's local storage, on the machine where it is opened.
