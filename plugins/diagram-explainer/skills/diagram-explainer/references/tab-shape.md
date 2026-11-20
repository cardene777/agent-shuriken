# Pages with header tabs

A document with two or more topics (for example how something works and how it is set up) is split into pages by tabs in the header.
The left contents list holds only the current page's sections, so readers can read just the pages that concern them.
A single-topic document has no header: a bar with one tab tells the reader nothing.

The template is [`starter-doc.html`](../templates/starter-doc.html).
With two or more `tabs` in the content JSON, `render.py` builds the header and the pages.
All pages live in one HTML file and are switched in place.

## Rules

| Rule | Shape | Why |
|---|---|---|
| Page keys are short | `a` / `b` / `c` | They become the section id prefix |
| Section ids are `<key>-s<number>` | `a-s1` / `b-s3` | Sections on different pages never share an id |
| Header buttons and pages match one to one | `nav.doc-pages` `data-page="a"` and `div.doc-page[data-page="a"]` | A click knows which page to show |
| Pages other than the first are kept in a `template` | `<template data-fill="b">` | Their content is built only when the page opens |
| Each page has its own contents list | `nav.doc-toc[data-page="a"]` | The order inside a page is shown on that page |
| The first section of each page opens with a heading | Page title (`<h1>`) and one lead sentence | The reader knows which page they are on |

`check.py` checks these rules: header buttons and pages, pages kept in a `template`, contents and sections per page, section id prefixes, and the PDF button.

Caption numbers start at 1 on each page (`Figure 1`, `Figure 2`, ...); `prose.py` counts them per section id prefix.

## Why later pages wait in a `template`

The content of a `template` is not part of the page until it is moved in, so pages that are not shown cost nothing when the document opens.
When a header tab is clicked, `assets/doc.js` moves that page's content out of the `template` and `assets/charts.js` draws its charts.
The content is moved, not copied, so going back to a page that was already opened does not build it again.

## Linking to a section on another page

Write `<a href="#b-s1">` in an `html` block.
Clicking it switches to that page and shows the section.
Opening the document with a `#` fragment in the URL also shows that page and section first.

## Narrow screens

A bar at the top shows the current section name and a `☰ Contents` button (in Japanese documents, the Japanese word for contents).
The button slides in the same contents list; choosing a section closes it.
The header tabs stay above the bar and scroll sideways when they do not fit.
A long document title is cut short with an ellipsis so that the tabs keep their room; keep the `title` short.

## Printing

In a multi-page document the `PDF` button at the right of the header offers two choices.
In a single-page document the button sits above the contents list and prints everything.

| Choice | Printed |
|---|---|
| This page only | Every section of the page being shown |
| All pages | Every section of every page, in order |

Neither is the default because both uses are common: handing one topic to someone, or reading the whole document.
Printing from the browser's own print command prints all pages.

On paper the header and contents list are hidden, every section is printed in order, and each section starts a new page.
Time band view buttons are listed with their text, and capped bars show both states.
Open the document with `?paper=1` (all pages) or `?paper=page` to see the paper layout on screen.

The PDF is made by the reader's print dialog ("Save as PDF").
The document does not assemble a PDF itself, so it stays one file that loads nothing from outside.
The menu labels follow the document language.

## How assets are included

The layout, charts, step ladders, and print layout live in `assets/`; the template has one marker line for each.

```html
<style>
/* diagram-explainer:asset doc.css */
/* diagram-explainer:asset charts.css */
/* diagram-explainer:asset ladder.css */
/* diagram-explainer:asset print.css */
</style>
...
<script>
// diagram-explainer:asset charts.js
</script>
<script>
// diagram-explainer:asset doc.js
</script>
<script>
// diagram-explainer:asset print.js
</script>
```

Keep `charts.js` before `doc.js`: `doc.js` asks `charts.js` to draw a page's charts when it shows the page.

`build.py` replaces each marker with the file's content.
A marker that points at a missing file, or one that is not on its own line, stops the build, so no marker reaches a shared document.

The assets are not copied into the template so that each exists in one place; two copies drift apart when only one is fixed.
