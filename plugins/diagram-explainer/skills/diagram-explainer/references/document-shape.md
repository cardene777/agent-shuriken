# Document shape

How to plan the content JSON, which blocks `render.py` accepts, and the HTML it produces.
The full field list is in [`content.schema.json`](content.schema.json); this page explains how to use it.
[`content.sample.json`](../examples/content.sample.json) and [`content.sample.ja.json`](../examples/content.sample.ja.json) use every block.

## Building a document

```bash
python3 scripts/render.py --in content.json --out body.html
python3 scripts/despace.py body.html                          # Japanese documents only
python3 scripts/ladder.py --html body.html --src ladders/     # only when the document has step ladders
python3 scripts/build.py --in body.html --out doc.html
python3 scripts/check.py doc.html
```

`render.py` fills [`starter-doc.html`](../templates/starter-doc.html).
`build.py` replaces the asset markers with the files in `assets/` and refuses unfinished documents, so the finished file opens offline and loads nothing from outside.

## Standard structure

Explainers of a standard, an API, or a protocol follow this order.

1. **Concept**: what the subject defines and what it leaves out.
2. **Main operations**: the operations of an API (create, get, update, complete, cancel, ...) or the messages of a protocol, shown together in prose or one figure.
3. **States and failures**: order of operations, completion, cancellation, and retries.
4. **Demo**, when there is one: what a demo leaves out, stated in the text.
5. **Production**, when there is an implementation: what production adds (transport, authentication, storage, payment, stock).
6. **Details**: endpoints, schemas, code, and exception tables; fold only raw data of ten lines or more, such as a log or a full schema, into collapsed `details` blocks.

Before writing, list the main operations, states, boundaries, and, when they apply, demo and production differences, and give each one a section or a figure.
If an item has neither, write the missing text before adding tables or figures.

Use tables for comparisons, mappings, and lists.
Paragraphs and figures carry the explanation; a reader of the tables alone should not be expected to understand the subject.
Put units in the column header, as in "Loan period (weeks)", and bare numbers in the cells.
Give the cards of one block the same fields or labels in the same order, so the reader compares them line by line.

Open with one plain sentence, then a concrete sequence of two to four steps, then what is out of scope.
Introduce technical terms after the sequence that uses them, not in the first sentence.

Do not write about the document itself ("this document", "this page", "this section").
The title, the contents list, and the headings already say what is covered; the text describes how the subject behaves and why.

The `lead` says who does what (who searches, who answers, who confirms), with verbs that match each actor's role.
Name what the subject actually defines (requests, responses, states, orders) instead of vague verbs such as "handles" or "supports".

## Top-level fields

| Field | Required | Meaning |
|---|---|---|
| `lang` | no | `en` (default) or `ja`. Sets `<html lang>`, the date, the language-specific checks, and the interface language the page starts in (contents button, labels, PDF menu, chart units) |
| `title` | yes | Document title |
| `lead` | yes | One sentence under the title |
| `facts` | no | Rows of the facts table under the first title: `asOf` (the time the document describes), `spec` (the specification and its version), and `read` (the date the sources were read) |
| `date` | no | The time the document describes, used when `facts.asOf` is not given. Defaults to the build date (`November 12, 2026`, or the Japanese form in Japanese documents) |
| `tabs` | yes | Pages. One tab gives a single page; two or more add page tabs to the header band ([tab-shape.md](tab-shape.md)) |

Each tab has `id`, `label`, `sections`, and optionally `title` (page heading, defaults to `label`) and `lead` (the first page falls back to the document `lead`).
Each section has `id`, `title`, `blocks`, and optionally `nofigure`.
Ids start with a letter and use letters, digits, `-`, and `_`; every id in a document is unique.

## Rendered skeleton

`render.py` produces this shape (single page shown). Write the same shape when editing by hand.

```html
<header class="doc-top">
  <span class="doc-brand">Document title</span>
  <div class="doc-tools">
    <div class="doc-ctrl">
      <div class="doc-seg" role="group" data-ui-label="language" aria-label="Language"><button type="button" data-lang="en" lang="en">English</button><button type="button" data-lang="ja" lang="ja">日本語</button></div>
      <div class="doc-seg" role="group" data-ui-label="theme" aria-label="Light or dark"><button type="button" data-theme-choice="light" ...><svg>...</svg></button><button type="button" data-theme-choice="dark" ...><svg>...</svg></button></div>
    </div>
    <button type="button" class="doc-help" data-ui-label="help" aria-label="Help" aria-haspopup="dialog">?</button>
  </div>
</header>
<aside class="doc-side" id="doc-side" data-ui-label="contents" aria-label="Contents">
  <nav class="doc-toc" data-page="a" data-ui-label="pageContents" data-ui-name="First page" aria-label="First page contents">
    <button type="button" data-sec="a-s1">First section</button>
    <button type="button" data-sec="a-s2">Second section</button>
  </nav>
</aside>
<div class="doc-mbar"><button type="button" data-ui="contents" data-ui-icon="☰" aria-controls="doc-side" aria-expanded="false">☰ Contents</button><span class="doc-here"></span><span class="doc-count"></span></div>
<main class="doc-main">
<div class="doc-page" data-page="a">
<section class="doc-sec" id="a-s1" data-name="First section">
  <div class="doc-pagehead">
    <h1>Document title</h1>
    <p class="lead">One sentence on what the subject does.</p>
    <table class="facts" data-ui-label="facts" aria-label="About this document">
      <tbody>
        <tr><th scope="row" data-ui="factAsOf">As of</th><td>November 12, 2026</td></tr>
        <tr><th scope="row" data-ui="factSpec">Follows</th><td>RFC 9110</td></tr>
      </tbody>
    </table>
  </div>
  <h2><span class="num">01</span>First section</h2>
  <p>Body text.</p>
  <figure class="free" id="a-flow">
    ...
    <figcaption><span class="fig-no">Figure 1</span>What the figure shows</figcaption>
  </figure>
</section>
<section class="doc-sec" id="a-s2" data-name="Second section" data-nofig="Why this section has no figure.">
  ...
</section>
</div>
<div class="doc-step"><button type="button" data-ui="prev" data-step="-1">Previous section</button><span class="doc-count"></span><button type="button" data-ui="next" data-step="1">Next section</button></div>
</main>
<div class="doc-scrim"></div>
```

The header band (`header.doc-top`) holds the title, the page tabs when there are two or more pages, the switches (`div.doc-ctrl`), and the `?` button that opens the help in a dialog. On narrow screens `assets/doc.js` moves the switches into the top bar.

The left contents list switches sections; only the chosen section is shown.
Each section explains its topic fully in prose; do not cut text to fit one screen.
`check.py` compares the contents buttons (`data-sec`) with the sections, so a section added without a contents entry, or an entry left after a section was removed, shows up in its output.

## The opening

The first section of a page opens with the title (`<h1>`) and one `<p class="lead">`; the first page adds the facts table (`table.facts`), nothing else.
Do not add a summary box, a list of assumptions, or reading instructions there.

The facts table always has an As-of row: the time the document describes goes in `facts` as `asOf`, else in `date`, else the build date is used.
Put the specification and the version the document follows in `facts` as `spec`, and the date you read its sources as `read`.

A summary box repeats what the sections say next, so the reader reads it twice.
Write assumptions and reading notes in the section that needs them.
`check.py` fails a document with any other element between the title and the first heading, whatever its content.

## Figures

Every section has a figure, or states why it has none in `nofigure` (rendered as `data-nofig`).
`check.py` fails a section with neither.
Four kinds of figure are drawn inside the document; none loads anything from outside.

| Figure | How to write it | Use it for |
|---|---|---|
| Chart | `chart` block with `kind` `timeband`, `capbar`, `bars`, or `period` ([chart-shape.md](chart-shape.md)) | Hours in a day, an amount against a limit, numbers to compare, periods on a year axis |
| HTML figure | `html` block with `caption`, rendered as `<figure class="free">` | Boxes and arrows, layers, comparisons laid out in space: anything the other kinds do not cover |
| Step ladder | `html` block with `caption` whose `html` is `<div class="ladder" data-ladder="NAME"></div>`, filled by `ladder.py` ([ladder-shape.md](ladder-shape.md)) | A sequence of steps where each step carries several items |
| Moving picture | `motion` block naming a page that `motion-diagram render` wrote, rendered as `<figure class="motion">` | A mechanism that reads best in motion: things come in, checks drop some, and the rest reach a person or an end |

Captions start with the figure number: `Figure 1`, `Fig. 1`, or `Example 1` in English, and the Japanese words for figure and example followed by the number in Japanese (see `content.sample.ja.json`).
Numbers run from 1 on each page and are counted separately for each prefix; `prose.py` fails gaps and repeats.
`render.py` puts the number in its own element (`<span class="fig-no">`), set apart from the caption by a margin instead of a space, so the gap stays the same in Japanese, where `despace.py` removes spaces next to numbers.

Do not put figures inside a collapsed `details` block: the reader would not see the figure while reading the section.

Every figure but a moving picture, which already takes the section width, gets an enlarge button at the right of its caption (`assets/doc.js`); it, or a press on the drawing, opens a copy of the drawing at twice its size in a dialog (`dialog.fig-zoom`), and closing the dialog returns the focus to the button.
A figure or table wider than its box scrolls sideways in a named region that takes the focus, and fades the side where it continues.

## Blocks

| `type` | Fields | Rendered as |
|---|---|---|
| `paragraph` | `text` | `<p>` |
| `heading` | `text` (required) | `<h3>` sub-heading inside the section |
| `list` | `items` (non-empty array of strings) | `<ul>` |
| `table` | `caption` (required), `columns` (non-empty array), `rows` (each row has as many cells as `columns`), optional `num` (the number columns, counted from 0) | `<div class="tbl" role="region">` with a `<table>`, its `<caption>`, column headers (`th scope="col"`), and the first cell of each row as a row header (`th scope="row"`) |
| `code` | `text`, optional `language` | `<pre><code class="language-NAME">`; the text is shown exactly as written |
| `keys` | `items`: 2 or more objects with `term` and `text` | `<div class="keys">`: key numbers or terms with a short explanation |
| `cards` | `items`: 2 or more objects with `title` and `text` or `list`; optional `label` (small tag) and `tone` (the item's state) | `<ul class="cards">` of `<li class="card">` |
| `note` | `text`, optional `title` and `tone` (default `info`); `warn` needs a `title` that names the risk | `warn`: `<div class="note warn" role="note">`, a framed box with an icon; other tones: `<div class="note">`, a titled paragraph in gray |
| `compare` | `items`: exactly 2 objects with `label` and `value` (the large value), optional `text` | `<div class="compare">`, left and right with the right side emphasized |
| `chart` | `id`, `kind`, `caption`, `spec`, optional `views` (timeband only, at most 5) | `<figure class="chart">` with an `<svg data-chart>` and its JSON |
| `html` | `id`, `html`, optional `css` and `caption` | `<figure class="free">` with a caption, otherwise `<div class="free">` |
| `motion` | `id`, `page` (a page that `motion-diagram render` wrote, relative to the content JSON), `caption` | `<figure class="motion">` whose frame carries the page byte for byte |
| `details` | `summary`, `blocks` (any blocks but `details`) | `<details class="exp">`, closed |

`tone` is one of `accent`, `good`, `warn`, `info`.
On a card it marks a state: `good` and `warn` color the card, and the others leave it plain.
Keep a section to two warnings at most; `check.py` fails a section with three or more.
A table's number cells (`td class="num"`) align right; its box keeps the header row and the first column in view while the table scrolls.
`keys` change how many fit in a row with the screen width, cards fill columns at least 260 px wide, and `compare` stacks below 640 px.

In text fields (all except `code` and `html`), `` `name` `` becomes `<code>name</code>` and any other markup is escaped.

In Japanese documents (`"lang": "ja"`), `render.py` starts each sentence of `paragraph`, `list` items, `lead`, `note`, and `cards` text on a new line, splitting at the Japanese full stop (U+3002) but not inside brackets (Japanese corner brackets and parentheses, full-width or not) or backticks.
Other documents keep each text as one run.

## `motion` blocks

A `motion` block places a moving picture of a mechanism in a section: the page that `motion-diagram render` of the `motion-diagram` skill wrote.
`render.py` reads only that file, from `page` relative to the content JSON, refuses a page without the marks `motion-diagram render` writes (`<main class="md" data-md>` and the `md-spec` data), and puts the page whole into `srcdoc` of a frame (`<iframe class="motion-frame">`).
`build.py` lets that frame through and refuses every other one.
The frame shares the document's origin, so its script and its colors stay apart from the document's while `assets/doc.js` can reach it.
`doc.js` makes the frame as tall as the picture and gives the page the light or dark of the document.
The page runs once when its picture is first on screen and shows its finished picture until then; before paper, `print.js` sends it `beforeprint`, so it draws its finished picture at the paper width in light colors.
Without the `motion-diagram` skill, draw the section as an HTML figure instead.

## `html` blocks

The `css` of an `html` block is nested under the block id (`<style>#ID { ... }</style>`), so it applies only inside the block.
Use the variables from `assets/doc.css` so the figure matches the page: `--ink`, `--ink-2`, `--ink-3` (text), `--line`, `--line-2` (borders), `--panel` (box background), `--accent`, `--accent-soft`, `--edge` (lines and arrows), `--radius`.

`render.py` refuses `html` containing `<script>`, `<style>`, `<link>`, `<iframe>`, `<object>`, `<embed>`, `<meta>`, `<base>`, `<frame>`, attributes starting with `on`, or `javascript:`, and `css` containing `@import` or tags.

A box-and-arrow figure, shortened from the sample:

```json
{"type": "html", "id": "a-flow", "caption": "Figure 1 How a request moves from the catalog to the pickup shelf",
 "html": "<div class=\"flow\"><div class=\"node\"><b>Searches the catalog</b></div><div class=\"arrow\" aria-hidden=\"true\"></div><div class=\"node end\"><b>Hold shelf for 7 days</b></div></div>",
 "css": "container-type: inline-size; .flow { display: grid; grid-template-columns: minmax(0, 1fr) 44px minmax(0, 1fr); align-items: center; } .node { padding: 12px 14px; background: var(--panel); border: 1px solid var(--line-2); border-radius: 12px; } .end { background: var(--accent-soft); border-color: var(--accent); } .arrow { position: relative; height: 2px; margin: 0 10px 0 6px; background: var(--edge); } .arrow::after { content: \"\"; position: absolute; right: -8px; top: -5px; border-left: 9px solid var(--edge); border-top: 6px solid transparent; border-bottom: 6px solid transparent; } @container (max-width: 640px) { .flow { grid-template-columns: minmax(0, 1fr); } .arrow { width: 2px; height: 24px; margin: 6px auto 14px; } }"}
```

Give the figure a narrow layout (here a container query that stacks the boxes) so it reads on a phone without scrolling sideways.

### Line legend

When lines in an HTML figure differ by color or dash, add a legend right below the drawing, outside any `details` block.
A figure whose lines all carry text labels does not need one.
For boxes that differ by fill, give the swatch a fill instead of a border, for example `<i style="background: var(--accent-soft); border-color: var(--accent)"></i>`.

```html
<div class="legend">
  <span><i style="border-color: var(--edge)"></i>Copy moves</span>
  <span><i style="border-color: var(--accent); border-top-style: dashed"></i>Notice is sent</span>
</div>
```

## Collapsed details

`details` blocks render closed. Do not add `open`: `check.py` fails open `<details>`.
Fold only raw data of ten lines or more, such as a log or a full schema; `check.py` fails a block of fewer than 10 lines.
The `summary` names what the block holds ("Scan log for one morning, 12 lines"); `check.py` fails a summary that is only "More" or "Details".
A `details` block never holds another, and `render.py` refuses one that does.
A run of four or more blocks starts with buttons that open or close all of them.
If one collapsed block would span several sub-headings, write it as normal text instead.

## Language and light or dark

Two switches sit side by side on the right of the header band, before the `?` button.
The language switch (`English`, `日本語`) changes only the interface text: the contents button and labels, the previous and next buttons, the Save PDF menu, the help, and chart units.
The document's own text and `<html lang>` stay in the language it was written in.
The light and dark switch changes the colors.
The page starts in the document's language and in the system's light or dark setting, and the browser remembers the reader's choices (`localStorage`), when it allows storage.
The interface words live in one dictionary, `assets/ui.json`, keyed by `en` and `ja`; nothing else defines them.
`render.py` and `ladder.py` read it when they write the page, `build.py` copies it into the page, and `assets/doc.js` reads it there, so elements marked with `data-ui`, `data-ui-label`, or `data-ui-title` show the same words before and after a switch.
To change or add a word, edit `assets/ui.json` in both languages and build again.

## Colors

Colors are tokens in `assets/doc.css`: light values on `:root`, dark values for the system's dark setting and for the reader's dark choice, and the light values again on paper.
Chart colors are named in the chart spec (`gray`, `blue`, `orange`, `violet`, `violet2`, `green`, `red`) or given as color values; the named colors have light and dark values, other values stay as given in both.
Step ladders use `--edge` (plain), `--edge-emphasis` (emphasis), `--ink` (strong), and `--edge-dashed` (lines going back), with defaults in `assets/ladder.css`.

Every color variable in `assets/doc.css` can be used in `html` blocks.
Use the variables rather than fixed colors, so the figure stays readable in dark.

| Variables | Use |
|---|---|
| `--bg`, `--panel`, `--card` | Page background, box background, card background |
| `--line`, `--line-2` | Light and stronger borders |
| `--rule` | Row lines of tables, at least 3:1 against the page |
| `--label` | Background of the facts table row headers and of card labels |
| `--ink`, `--ink-2`, `--ink-3`, `--ink-sub`, `--ink-faint` | Text, from strongest to faintest |
| `--accent`, `--accent-soft` | Emphasis and its light fill |
| `--good`, `--good-soft` | Success and its light fill |
| `--warn`, `--warn-soft` | Caution and its light fill |
| `--critical`, `--critical-soft` | Failure and its light fill |
| `--edge` | Lines and arrows |
| `--radius` | Corner radius of boxes |

## Print

On paper the header, contents list, and switches are hidden, every section is printed in order in light colors, and each section starts a new page (`assets/print.css`).
Every collapsed `details` block is opened with its summary, and the ones the reader had closed are closed again after printing.
Time band view buttons are listed with their text, capped bars show both states, and boxes that scroll are printed in full.
Figures are kept on one page (`break-inside: avoid`).
How to choose which pages to print is in [tab-shape.md](tab-shape.md).

## Where to keep the files

```
explainers/<slug>/
├── <slug>.html      finished document; the only file readers need
├── content.json     content JSON the document is built from
└── ladders/         step ladder definitions, one JSON file per ladder
```
