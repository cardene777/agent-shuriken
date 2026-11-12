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
6. **Details**: endpoints, schemas, code, and exception tables, in collapsed `details` blocks.

Before writing, list the main operations, states, boundaries, and, when they apply, demo and production differences, and give each one a section or a figure.
If an item has neither, write the missing text before adding tables or figures.

Use tables for comparisons, mappings, and lists.
Paragraphs and figures carry the explanation; a reader of the tables alone should not be expected to understand the subject.

Open with one plain sentence, then a concrete sequence of two to four steps, then what is out of scope.
Introduce technical terms after the sequence that uses them, not in the first sentence.

Do not write about the document itself ("this document", "this page", "this section").
The title, the contents list, and the headings already say what is covered; the text describes how the subject behaves and why.

The `lead` says who does what (who searches, who answers, who confirms), with verbs that match each actor's role.
Name what the subject actually defines (requests, responses, states, orders) instead of vague verbs such as "handles" or "supports".

## Top-level fields

| Field | Required | Meaning |
|---|---|---|
| `lang` | no | `en` (default) or `ja`. Sets `<html lang>`, the interface text (contents button, labels, date, PDF menu, chart units), and the language-specific checks |
| `title` | yes | Document title |
| `lead` | yes | One sentence under the title |
| `date` | no | Date shown in the header or above the contents list. Defaults to the build date (`As of November 12, 2026`, or the Japanese form in Japanese documents) |
| `tabs` | yes | Pages. One tab gives a single page with no header; two or more add header tabs ([tab-shape.md](tab-shape.md)) |

Each tab has `id`, `label`, `sections`, and optionally `title` (page heading, defaults to `label`) and `lead` (the first page falls back to the document `lead`).
Each section has `id`, `title`, `blocks`, and optionally `nofigure`.
Ids start with a letter and use letters, digits, `-`, and `_`; every id in a document is unique.

## Rendered skeleton

`render.py` produces this shape (single page shown). Write the same shape when editing by hand.

```html
<aside class="doc-side" id="doc-side" aria-label="Contents">
  <p class="doc-brand">Document title</p>
  <p class="doc-date">As of November 12, 2026</p>
  <nav class="doc-toc" data-page="a" aria-label="Document title contents">
    <button type="button" data-sec="a-s1">First section</button>
    <button type="button" data-sec="a-s2">Second section</button>
  </nav>
</aside>
<div class="doc-mbar"><button type="button" aria-controls="doc-side" aria-expanded="false">☰ Contents</button><span class="doc-here"></span><span class="doc-count"></span></div>
<main class="doc-main">
<div class="doc-page" data-page="a">
<section class="doc-sec" id="a-s1" data-name="First section">
  <div class="doc-pagehead"><h1>Document title</h1><p class="lead">One sentence on what the subject does.</p></div>
  <h2><span class="num">01</span>First section</h2>
  <p>Body text.</p>
  <figure class="free" id="a-flow">
    ...
    <figcaption>Figure 1 What the figure shows</figcaption>
  </figure>
</section>
<section class="doc-sec" id="a-s2" data-name="Second section" data-nofig="Why this section has no figure.">
  ...
</section>
</div>
<div class="doc-step"><button type="button" data-step="-1">Previous section</button><span class="doc-count"></span><button type="button" data-step="1">Next section</button></div>
</main>
<div class="doc-scrim"></div>
```

The left contents list switches sections; only the chosen section is shown.
Each section explains its topic fully in prose; do not cut text to fit one screen.
`check.py` compares the contents buttons (`data-sec`) with the sections, so a section added without a contents entry, or an entry left after a section was removed, shows up in its output.

## The opening

The first section of a page opens with the title (`<h1>`) and one `<p class="lead">`, nothing else.
Do not add a summary box, a list of assumptions, or reading instructions there.

A summary box repeats what the sections say next, so the reader reads it twice.
Write assumptions and reading notes in the section that needs them.
`check.py` fails a document with any other element between the title and the first heading, whatever its content.

## Figures

Every section has a figure, or states why it has none in `nofigure` (rendered as `data-nofig`).
`check.py` fails a section with neither.
Three kinds of figure are drawn inside the document; none loads anything from outside.

| Figure | How to write it | Use it for |
|---|---|---|
| Chart | `chart` block with `kind` `timeband`, `capbar`, `bars`, or `period` ([chart-shape.md](chart-shape.md)) | Hours in a day, an amount against a limit, numbers to compare, periods on a year axis |
| HTML figure | `html` block with `caption`, rendered as `<figure class="free">` | Boxes and arrows, layers, comparisons laid out in space: anything the other kinds do not cover |
| Step ladder | `html` block with `caption` whose `html` is `<div class="ladder" data-ladder="NAME"></div>`, filled by `ladder.py` ([ladder-shape.md](ladder-shape.md)) | A sequence of steps where each step carries several items |

Captions start with the figure number: `Figure 1`, `Fig. 1`, or `Example 1` in English, and the Japanese words for figure and example followed by the number in Japanese (see `content.sample.ja.json`).
Numbers run from 1 on each page and are counted separately for each prefix; `prose.py` fails gaps and repeats.

Do not put figures inside a collapsed `details` block: the reader would not see the figure while reading the section.

## Blocks

| `type` | Fields | Rendered as |
|---|---|---|
| `paragraph` | `text` | `<p>` |
| `heading` | `text` (required) | `<h3>` sub-heading inside the section |
| `list` | `items` (non-empty array of strings) | `<ul>` |
| `table` | `columns` (non-empty array), `rows` (each row has as many cells as `columns`) | `<div class="tbl"><table>` |
| `code` | `text`, optional `language` | `<pre><code class="language-NAME">`; the text is shown exactly as written |
| `keys` | `items`: 2 or more objects with `term` and `text` | `<div class="keys">`: key numbers or terms with a short explanation |
| `cards` | `items`: 2 or more objects with `title` and `text` or `list`; optional `label` (small tag) and `tone` | `<div class="cards">` of `.card` |
| `note` | `text`, optional `title` and `tone` (`warn` for cautions, `info` for side notes; default `info`) | `<div class="note">`, a colored box |
| `compare` | `items`: exactly 2 objects with `label` and `value` (the large value), optional `text` | `<div class="compare">`, left and right with the right side emphasized |
| `chart` | `id`, `kind`, `caption`, `spec`, optional `views` (timeband only) | `<figure class="chart">` with an `<svg data-chart>` and its JSON |
| `html` | `id`, `html`, optional `css` and `caption` | `<figure class="free">` with a caption, otherwise `<div class="free">` |
| `details` | `summary`, `blocks` (any blocks) | `<details class="exp">`, closed |

`tone` is one of `accent`, `good`, `warn`, `info`.
`keys` and `cards` change how many fit in a row with the screen width; `compare` stacks below 640 px.

In text fields (all except `code` and `html`), `` `name` `` becomes `<code>name</code>` and any other markup is escaped.

In Japanese documents (`"lang": "ja"`), `render.py` starts each sentence of `paragraph`, `list` items, `lead`, `note`, and `cards` text on a new line, splitting at the Japanese full stop (U+3002) but not inside brackets (Japanese corner brackets and parentheses, full-width or not) or backticks.
Other documents keep each text as one run.

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
Collapse only long supporting material.
If one collapsed block would span several sub-headings, write it as normal text instead.

## Colors

The page uses a light color scheme only (`assets/doc.css`); there is no dark-mode variant.
Chart colors are named in the chart spec (`gray`, `blue`, `orange`, `violet`, `violet2`, `green`, `red`) or given as color values.
Step ladders use `--edge` (plain), `--edge-emphasis` (emphasis), `--ink` (strong), and `--edge-dashed` (lines going back), with defaults in `assets/ladder.css`.

Every color variable in `assets/doc.css` can be used in `html` blocks.

| Variables | Use |
|---|---|
| `--bg`, `--panel`, `--card` | Page background, box background, card background |
| `--line`, `--line-2` | Light and stronger borders |
| `--ink`, `--ink-2`, `--ink-3`, `--ink-sub`, `--ink-faint` | Text, from strongest to faintest |
| `--accent`, `--accent-soft` | Emphasis and its light fill |
| `--good`, `--good-soft` | Success and its light fill |
| `--warn`, `--warn-soft` | Caution and its light fill |
| `--bad`, `--bad-soft` | Failure and its light fill |
| `--edge` | Lines and arrows |
| `--radius` | Corner radius of boxes |

## Print

On paper the header and contents list are hidden, every section is printed in order, and each section starts a new page (`assets/print.css`).
Collapsed details are opened, time band view buttons are listed with their text, and capped bars show both states.
Figures are kept on one page (`break-inside: avoid`).
How to choose which pages to print is in [tab-shape.md](tab-shape.md).

## Where to keep the files

```
explainers/<slug>/
├── <slug>.html      finished document; the only file readers need
├── content.json     content JSON the document is built from
└── ladders/         step ladder definitions, one JSON file per ladder
```
