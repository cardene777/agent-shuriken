# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Design Formats reads, runs, and keeps, and every rule `verify` checks.
The agent of a following skill writes the page or the document; the script in `skills/page-design/scripts/` only checks it.

## Files in the skill

| File | What it holds |
|---|---|
| `SKILL.md` | The contents the skill provides, how to write a page or a document with them, and how to run `verify` |
| `agents/openai.yaml` | How Codex shows and starts the skill |
| `musubi.json` | The contents the skill provides through musubi: `structure`, `look`, `report`, `sheet`, `document`, `choice`, and `verify`, each at version 1.0.0 |
| `formats/structure.md` | The order of an explanation |
| `formats/look.md` | The look rules, ending with the table of rules `verify` checks |
| `templates/report.html` | The report page type |
| `templates/sheet.html` | The approval sheet type |
| `templates/document.html` | The explainer type |
| `templates/choice.html` | The choice page type |
| `scripts/page-design.py` | `verify`, the check of a page or a document |
| `tests/test-page-design.sh` | Tests of `verify`, the formats, the templates, the declaration, and the plugin |

## How a skill follows page-design

A following skill names the contents it follows, such as `page-design/look` and `page-design/report`, in its own `musubi.json`, with a version range and the fingerprint of the content it last checked.
Its `SKILL.md` says to open `page-design` by name, read the file it names for each content, and what to do when `page-design` is not installed.
The agent copies the template of the page type, replaces `DATA` and the words in `TEXT`, and runs `verify` on the page.

| File | Which plugin | What it holds |
|---|---|---|
| `formats/structure.md`, `formats/look.md` | design-formats | The order of an explanation and the look rules |
| `templates/<type>.html` | design-formats | The frame of each page type, with sample data |
| `musubi.json` | The following skill | The range and fingerprint of each content it follows |

When a format, a template, or the script changes, its fingerprint changes, and `musubi check` refuses every following skill until that skill is checked again and its fingerprint is updated.

## How the templates work

Each template is one HTML file with its styles and script inside it.
Every string shown to people is in one dictionary, `TEXT`, with an `en` and a `ja` entry, and the report's content is in one object, `DATA`.
The header holds the English and Japanese buttons (`data-lang`) and the light and dark buttons (`data-theme-choice`).
The page starts in English and in the theme of the operating system, and keeps the chosen language and theme in the browser's local storage, under `page-design-lang` and `page-design-theme`.
The approval sheet and the choice page build the text copied back to the chat in `copyText()`, from fixed English words and item keys only, so a script reads it the same way in either language.
When the browser refuses to copy, the page selects the text and says to copy it with the keyboard.

## What verify checks

`verify <file>...` reads `.html` and `.htm` files as pages and `.md` files as documents.

| Rule | What it finds | Pages | Documents |
|---|---|---|---|
| `heading-punctuation` | A heading, a title, or a dictionary entry whose name holds title or heading, including each language's text in an entry such as `title: { en, ja }`, with a colon or a Japanese comma or period | Yes | Yes |
| `facts-in-one-line` | Three or more facts with numbers joined by commas in one line | Yes | Yes |
| `label-colon` | A label and a value joined with a colon or `=` | Yes | Yes |
| `small-text` | A font size under 12px or 0.75rem | Yes | No |
| `missing-lang` | An `<html>` element without `lang` | Yes | No |
| `missing-language-switch` | No `data-lang="en"` and `data-lang="ja"` buttons | Yes | No |
| `missing-theme-switch` | No `data-theme-choice="light"` and `data-theme-choice="dark"` buttons | Yes | No |
| `missing-dictionary` | No dictionary with an `en` and a `ja` entry | Yes | No |
| `missing-dark-colors` | No colors for `prefers-color-scheme: dark` | Yes | No |
| `missing-reduced-motion` | Transitions or animations without `prefers-reduced-motion` | Yes | No |
| `external-file` | A script, style, image, frame, or font read from another site | Yes | No |

In a page, text inside `script`, `style`, `code`, `pre`, `textarea`, and `svg` is not read as shown text; strings in scripts are read only for titles and facts, and only when they hold no markup or code.
In a document, fenced code, tables, quotes, and HTML comments are skipped, and inline code is removed before a line is checked.

Each problem is one line, `<file>:<line>: <rule>: <how to fix>`, followed by a summary line, and the exit code is 1.
When nothing is wrong, it prints `page-design: ok (<n> files)` and exits 0.
It exits 2, with the reason on standard error, when no file is given, a file cannot be read, or a file is neither HTML nor Markdown.

## What it runs and connects to

`verify` reads the files you pass and prints to standard output and standard error.
It prints only file names, line numbers, rule names, and fixes, never the text of the page.
It runs no other program and connects to nothing.
The templates load nothing from other sites.

## What it keeps

`verify` keeps nothing.
A page made from a template keeps the chosen language and theme in the browser's local storage, on the machine where it is opened.
