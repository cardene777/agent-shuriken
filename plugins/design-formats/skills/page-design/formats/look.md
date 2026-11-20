# Look of a document or page

This format sets how a Markdown document or an HTML page looks.
Rules marked HTML apply only to pages; the rest apply to both.
The order of the explanation is in `structure.md`, next to this file, and the four page types are in `templates/`.

## Headings

A heading is a name, not a sentence.

- Write no colon (`:` or `：`) and no `、` or `。` in a heading, in any language
- Name the subject and the kind in one phrase, such as "Weekly sales of the bakery" or "パン屋の週の売り上げ", and put the details on the line under the title
- Keep the title when showing details, and write the details under it
- Do not repeat in the body a heading the header already shows
- Number headings and file names only when the order is the content, and number from 1 without restarting

## Facts in a table

Facts about the page, such as the store, the period, counts, and when it was generated, go in a table, never in one sentence.

- HTML: a `<dl>` grid or a `<table>` of label and value cells under the title
- Markdown: a table with an Item and a Value column
- A sentence such as "Main street store, 2026-11-10 to 2026-11-16, 24 products, generated 2026-11-17" is the shape to avoid
- Keep facts about the page apart from the results. Facts sit on one quiet line under the title, and the result numbers sit on one band of large numbers below it
- Show each value once. A number that is a result goes on the band, not also among the facts

## Joining items

- Do not join items with `・`, a colon, or `=` in text people read; use a table, a sentence, or a heading with text under it
- Do not end a line with a colon
- In Japanese, put no space between Japanese and ASCII letters or numbers
- Keep inline code, URLs, and paths as they are, in backticks in Markdown

## Words on the screen

- Name buttons with a short verb; close and enlarge are icons with an accessible label
- Show a path as a link and a URL as it is
- Say whose item changed, what changed, and through what, in plain words
- Leave out excuses, demo notices, and raw error text; say what went wrong and what to do
- Keep explanations and warnings apart, and show states such as unsaved at the top right

## Text size and weight

- Body text 14 to 16px, and nothing under 12px
- Headings clearly larger than body text, and readable at a glance
- Text dark enough to read, with a contrast of at least 4.5 to 1, and not pale gray on gray
- Nothing oversized: a page title is around 20 to 24px

## Explanations and help

- Show explanations; do not hide them in toggles
- Fold only long concrete data, such as raw lists and logs
- Put supplementary help behind a ? icon that opens a dialog

## Details beside the list

A list shows the summary, and the details of one item sit beside it.

- HTML: pressing a row shows its details in a panel to the right on wide screens, and under the list on phones
- Show lists as cards or tables, and split long lists by category into tabs
- Show about 50 rows per page, with the paging centered above and below the list, and no paging when the list fits on one page
- Give each row its value as a number. A bar without a number does not say what it measures
- Let people choose by pressing a row or a card, not by aiming at a small checkbox
- Keep a way back to the whole list

## Figures

- Show amounts, shares, steps, parts, and order as figures, not only as numbers in a table. Pick the figure from what the reader compares

| What the reader compares | Figure | dragon notation |
|---|---|---|
| The amounts of a few items | Bar chart | `chart <title> [shape: bar]` |
| The shares of one whole | Donut | `chart <title> [shape: donut]` |
| The steps of a procedure, in order, with no choices | Steps in a row | `cycle <title> [shape: band]`, with no line back to the first step and `[carry: none]` on each line |
| A procedure that branches at choices | Flow | `flow` |
| The parts of a system and what passes between them | Architecture | `architecture` |
| Messages between parties in time order | Sequence | `sequence` |
| A change over time | Line chart | Not in dragon yet; show a table until dragon draws a line chart |

- A chart shows values that the text and the tables do not already show. Never draw the rows of a list again as a chart. Steps in a row and a flow show the order of the steps, and the amounts stay in the text of the steps
- Write each figure as a still dragon block, `<pre class="dragon" data-still>`, which shows the last step as one picture with no player. The notation comes from the dragon skill
- Keep one block per language, each inside `<div data-figure-lang="en">` or `<div data-figure-lang="ja">`, and hide the other language with `html[lang="en"] [data-figure-lang="ja"], html[lang="ja"] [data-figure-lang="en"] { display: none; }`
- While the page is written, it carries the dragon entry line `<script type="module" src="https://cdn.jsdelivr.net/npm/@cardenelabs/dragon@<major.minor>/dist/cdn/dragon.js"></script>`. Before the page is handed over, run `npx -y @cardenelabs/dragon@<major.minor> embed page.html --out page.html`. `dragon embed` draws every still block as an SVG and removes the entry line, so the page reads no other file
- A chart shows its own title, which says what it compares; give other figures a caption. Open every figure larger when pressed

## Enlarging

- HTML: figures, screenshots, and long text open larger when pressed, in a dialog that shows the whole
- Give figures the page's width; never shrink a figure to fit beside text

## Motion

- HTML: switch tabs, open details, and select items with short transitions of 150 to 250ms
- Show loading in the center of the area that is loading
- Always include `@media (prefers-reduced-motion: reduce)` that turns transitions and animations off

## Header controls

- HTML: the header holds the language switch, English and 日本語 buttons with `data-lang="en"` and `data-lang="ja"`, and the light and dark switch, buttons with `data-theme-choice="light"` and `data-theme-choice="dark"`
- Place the two switches side by side, never stacked
- English is the default language: `<html lang="en">`
- Keep every UI string in one dictionary per page, `TEXT = { en: { ... }, ja: { ... } }`
- Text copied back to the chat, and any format a script parses, never depends on the UI language

## Colors

- HTML: define colors as tokens on `:root` for light, redefine them under `@media (prefers-color-scheme: dark)` guarded by `:root:not([data-theme="light"])`, and again under `:root[data-theme="dark"]`
- Give `body` a background from a token
- Keep good, warning, and critical colors apart from the accent color
- Avoid decorative gradients and plain circles used as decoration

## Layout

- Cap the content width on wide screens, around 1200px for pages and 720px for forms
- Align items on a shared center line
- Put things to compare side by side, with sideways scrolling inside their own box when they do not fit
- A page that shows changes puts the request first and gives each change its own tab
- Use a figure where it explains better than text

## Self-contained pages

- HTML: the page reads no other file; styles, scripts, images, and fonts are inline or `data:` URIs
- Links to other sites are plain links that open in a new tab

## What verify checks

`scripts/page-design.py verify` checks the rules a script can see.

| Rule | What it finds | Pages | Documents |
|---|---|---|---|
| `heading-punctuation` | A heading, a title, or a dictionary title with a colon, `、`, or `。` | Yes | Yes |
| `facts-in-one-line` | Three or more facts with numbers joined in one line | Yes | Yes |
| `label-colon` | A label and a value joined with a colon or `=` | Yes | Yes |
| `small-text` | A font size under 12px | Yes | No |
| `missing-lang` | An `<html>` element without `lang` | Yes | No |
| `missing-language-switch` | No `data-lang="en"` and `data-lang="ja"` buttons | Yes | No |
| `missing-theme-switch` | No `data-theme-choice="light"` and `data-theme-choice="dark"` buttons | Yes | No |
| `missing-dictionary` | No dictionary with an `en` and a `ja` entry | Yes | No |
| `missing-dark-colors` | No colors for `prefers-color-scheme: dark` | Yes | No |
| `missing-reduced-motion` | Motion without `prefers-reduced-motion` | Yes | No |
| `external-file` | A script, style, image, or frame read from another site | Yes | No |
| `figure-not-embedded` | A dragon block left on a page that `dragon embed` has not drawn | Yes | No |
| `figure-not-still` | With `--source`, a dragon block without `data-still` | Yes | No |

`verify --source` checks the source of a page, such as a template, before `dragon embed`. It accepts still dragon blocks and the dragon entry line.
The text inside a dragon block and inside a drawn figure belongs to the figure, so the text rules do not read it.
The other rules in this file are kept by the writer and checked by eye.
