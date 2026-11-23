# How it works

English · [日本語](how-it-works.ja.md)

The plugin holds one skill, `product-deck`.
The agent follows `skills/product-deck/SKILL.md`, writes the deck's files in your repository, and runs the scripts in `skills/product-deck/scripts/` with Node.js.

## Files in the skill

| File | What it holds |
|---|---|
| `SKILL.md` | The steps: take screenshots, plan, write, approve, build, render, check, look, make the text editable, render the handouts |
| `references/deck-structure.md` | The base of ten slides, the slides a product deck does not have, and the layout discipline |
| `references/layout-rules.md` | The layout rules, each with the check that sees it or "by eye" |
| `references/writing-rules.md` | The writing rules, each with the check that sees it or "by eye" |
| `references/banned-words.txt` | Words that must not appear on a slide, read by `audit.mjs` unless `--words` names another list |
| `scripts/capture.mjs` | Takes a screenshot of one page |
| `scripts/audit.mjs` | Checks the rendered slides |
| `scripts/audit-text.mjs` | Checks the wording from the deck's data |
| `scripts/theme.mjs` | Reads the user's theme file and prints the CSS variables a deck takes from it |
| `scripts/shoot.mjs`, `scripts/render.mjs` | Render slides to 1920x1080 PNG files |
| `scripts/glyph-fit.mjs` | Measures whether icons fit their containers |
| `scripts/load-playwright.mjs` | Resolves Playwright for the scripts that drive a browser |

## Playwright

The plugin ships no `node_modules`.
Each script that drives a browser imports `load-playwright.mjs`, which resolves `@playwright/test` from the folder in `PLAYWRIGHT_FROM`, or from the script's own folder when the variable is not set.
When neither has it, the script prints that Playwright was not found with the value of `PLAYWRIGHT_FROM`, and exits 2 before it opens a page or writes a file.

## The deck's files

The agent writes them in `docs/decks/<name>/` of your repository.

| File | What it holds |
|---|---|
| `plan.md` | The structure: one row per slide with its claim, its screen, and whether it has a figure |
| `content.md` | The text of each slide, for you to approve |
| `assets/` | The screenshots |
| `build/deck-data.mjs` | Every word on the slides, as `export const faces = [...]`, one object per slide |
| `build/deck-faces*.mjs`, `build/deck-styles.mjs`, `build/deck-base-css.mjs`, `build/render.mjs` | How the slides are laid out, with no words |
| `build/build-deck.mjs`, `build/build-decks.mjs` | The renderers of the handout and of the viewer that compares styles; both run the checks |
| `build/build-slide-edit.mjs`, `build/apply-edits.mjs` | The screen that edits the text on the slides, and the tool that writes the edits back to `deck-data.mjs` |
| `build/build-pdf.mjs`, `build/build-pptx.mjs` | The renderers of the PDF and the PowerPoint |
| `build/writing-terms.txt` | The deck's terms for the wording check |

## The checks

| Check | Reads | Exit |
|---|---|---|
| `audit.mjs <viewer HTML> <style>...` | The rendered slides, opened in a headless browser | 0 when nothing is flagged, 1 when a slide is flagged, 2 when a style cannot be opened or a check counted nothing |
| `audit-text.mjs <deck-data.mjs>` | The deck's data, the deck's terms, and the words to drop when that list is found | 0 when nothing is flagged, 1 when a slide is flagged, 2 when the terms or a list passed by path are missing, or a check counted nothing |

Each check prints how many items it looked at, so that "flagged 0 slides" can be told apart from a check that looked at nothing; a count of 0 stops the run with exit 2.

## The word lists

`audit-text.mjs` always runs three built-in rules, which need no list of the user's.

| Built-in rule | What it sees |
|---|---|
| `the same thing is called by different words` | A word that mixes in, from the `synonym` lines of the deck's terms |
| `a core word comes before its explanation` | A core word on a slide before the one that explains it, from the `core` lines of the deck's terms |
| `a person does a thing's action` | A Japanese sentence where a person or an agent does what a thing does |

It reads two lists, and neither ships with the plugin.

| List | Read from | When it is missing |
|---|---|---|
| The words to drop | `--prose-words <path>`, or else `~/.product-deck/prose-words.txt` | Without a list in the home folder, the built-in rules run alone, and the script says on standard error that no word list was found and where it looked. A path passed with `--prose-words` that does not exist stops the run with exit 2 |
| The deck's terms | `--terms <path>`, or else `~/.product-deck/writing-terms.txt` | No check runs; exit 2 names the place it looked |

The home folder is found with Node.js's `os.homedir()`.

### The words to drop

One word per line: the kind, the word, and what to write instead, separated by spaces. A line starting with `#` is a note.

```
# kind  word  instead
wordy  utilize  use
wordy  leverage  use
unknown  idempotent  safe-to-repeat
bare-english  workflow  steps
allow  API  keep
```

| Kind | How it is matched |
|---|---|
| `bare-english` | At word boundaries, ignoring case |
| `allow` | Not a word to drop: it takes the word out of `bare-english`. The third column is still needed |
| Any other name | As a substring; the name becomes the name of a check |

Each kind needs at least one word, or the check stops with exit 2.

### The deck's terms

One term per line, starting with its kind.

```
synonym  record  entry  log
synonym  agent  bot
except  record  history
core  record  3
core  policy  4
allow  smart contract
```

| Kind | Form | Meaning |
|---|---|---|
| `synonym` | `synonym <word decided> <word that mixes in>...` | A word that mixes in must not appear; the word decided names that thing |
| `except` | `except <word decided> <form>...` | A text holding one of the forms is not checked for that word, such as a heading copied from the product's screen |
| `core` | `core <word> <slide number>` | The word must not appear before the slide that explains it |
| `allow` | `allow <phrase>` | A phrase kept even when it holds a word to drop |

The list needs at least one `synonym` and one `core` line, or the check stops with exit 2.

For a deck in Japanese, the kinds may keep their Japanese names, which `scripts/audit-text.mjs` lists.

## The theme file

`theme.mjs`, run in your repository, reads the first of these two places that holds a theme file.

| Order | Place | Use |
|---|---|---|
| 1 | `.design-theme.json` at the root of the git repository the command runs in | The look of one project |
| 2 | `~/.design-theme.json` | The look of everything you make |

The repository's file is used as it is, and the home file is not merged into it.
It is the theme file of the page-design skill of design-formats, with the same keys and the same values; product-deck reads it with its own script, because a plugin reads nothing outside its own folder.

A deck takes these keys, and every style of the deck takes them through the CSS variables.

| Key | CSS variable |
|---|---|
| `light.accent`, `light.accent-ink`, `light.accent-soft` | `--accent`, `--accent-ink`, `--accent-soft`: the main color |
| `light.bg`, `light.surface`, `light.ink`, `light.sub`, `light.line` | `--bg`, `--surface`, `--ink`, `--sub`, `--line`: the neutrals |
| `font.sans`, `font.mono`, `font.line-height` | `--sans`, `--mono`, `--line-height` |
| `space.radius-small`, `space.radius`, `space.radius-large` | `--radius-small`, `--radius`, `--radius-large`, in pixels |

The other keys are not used on slides, and the script names the ones the file holds.

| Key | Why it is not used |
|---|---|
| `dark.*` | A handout has one look |
| `light.bar`, `light.label` | They are parts of pages |
| `font.size` | Slide text is sized for 1920x1080 and stays at 22px or more |
| `space.page-width` | A slide is 1920 wide |

| Case | Standard output | Standard error | Exit |
|---|---|---|---|
| No theme file | Nothing | That there is no theme file and the deck keeps its own look | 0 |
| A theme file | A `:root { ... }` block of the keys it sets that a deck takes | The file read, and the keys not used | 0 |
| A file that is not JSON, holds a key not listed, or a value of the wrong kind or out of range | Nothing | Each such key, such as `light.acent` | 2 |

Without a theme file, the agent picks one main color for the deck, with neutrals only.

## Samples

When `~/.product-deck/samples/` exists, the agent lists it and looks at the images in it before placing screenshots.
The plugin ships no sample image.

## What it writes and keeps

The plugin writes only the deck's files in your repository.
It writes nothing in `~/.product-deck/` or in the theme file, which you keep yourself, and sends nothing anywhere.
