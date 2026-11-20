# Report structure

What goes in each section of the report, and the markup of every component the template styles.
`templates/base.html` holds the theme, with light and dark colors, and the language and light/dark switches with the script that runs them.
Write only the markup below inside it, leave the switches and their script as they are, and add no stylesheet, script, or color of your own.

## Placeholders

Replace every placeholder in the template. `scripts/check-report.py` fails while any is left.

| Placeholder | What to put there |
|---|---|
| `{{LANG}}` | The language code of the report, such as `en` or `ja`. The report's text stays in this language; the language switch starts from it and changes only the words of the switches |
| `{{TITLE}}` | The report title, such as "Static site generators compared" |
| `{{EYEBROW}}` | A short label above the title, such as "Comparison report" |
| `{{SUBTITLE}}` | One sentence on what was compared and for whom |
| `{{STATS}}` | Three `<div><dt>label</dt><dd>value</dd></div>` items: candidates, axes, and sources |
| `{{DATE}}` | The date the research was done |
| `{{AUTHOR}}` | The name the user gave for the cover after a short label in the report's language, such as "Prepared by Jane Doe", with `&`, `<`, and `>` escaped. When the user chose no name, replace it with nothing, leaving no space between the tags, and the line is hidden |
| `{{CONTENTS_HEADING}}` | The heading of the contents list |
| `{{TOC}}` | One `<li><a href="#id">title</a></li>` per section, in order |
| `{{SUMMARY}}` | The summary section's content, starting with its `<h2>` |
| `{{CANDIDATES}}` | The candidates section's content |
| `{{AXES}}` | One `<section id="axis-..." class="chapter axis">` per evaluation axis |
| `{{RISKS}}` | The risks section's content |
| `{{RANKING}}` | The ranking section's content |
| `{{SOURCES}}` | The sources section's content |
| `{{FOOTER}}` | The date, and a line saying the report reflects public information on that date |

Each section starts with an `<h2>`.
The template numbers the sections, so do not number the headings yourself.

## Sections

### Summary (`#summary`)

- Why the comparison was needed, in a `callout`
- The top three picks as `picks`, each with one or two sentences on why
- Five to seven findings as a `findings` list

### Candidates (`#candidates`)

- A table of every candidate with its type, license or pricing model, and status
- One `card` per candidate, with what it is in three or four sentences, who uses it, one strength, one weakness, and a `tag` for its type

### One section per axis (`.axis`)

- A table that compares every candidate on the axis, with a score and a rationale
- A `bars` chart when the axis has numbers to compare
- A `note` under each table or chart saying where the data comes from and under which conditions it was measured, written as [Figures in text](#figures-in-text) describes
- Keep measurements taken under the same conditions apart from each vendor's own figures

### Risks (`#risks`)

- A table of candidate, risk, severity as a `risk` label, mitigation, and rationale
- A `callout warn` for each risk that could rule a candidate out

### Ranking (`#ranking`)

- A scorecard table with one row per candidate, one score per axis, and an overall comment in the rationale column
- A [recommendation](#recommendation) table with the first choice, an alternative, and a fallback, each with the conditions under which it is the right pick
- A table of recommendations by use case, when different users would choose differently

### Sources (`#sources`)

- Every source as an `<li>` in `<ol class="sources">`, with a link and the date it was read
- Number the sources in the order they are cited, and cite them in the text as `[n]`

## Rationale rule

Every table that contains a score or a risk label has a rationale column, `<th class="rationale">`.
In the scorecard, the same column holds the overall comment.
When no comparable figure exists for a candidate on an axis, write "Not scored" in the score cell, in the report's language, and say why in the rationale.

- Lead with the figures, such as a price, a throughput, an availability, a release date, or a count
- Place the candidate against the others, such as "half the price of B" or "the most of the five"
- Say why it is not one grade higher, such as "A, not S, because the SLA is not published"
- Keep it to one or two sentences, about 15 to 30 words, so the table stays readable
- Write it as [Figures in text](#figures-in-text) describes, and give figures the reader compares across candidates their own `num` columns

This rationale leads with its figures and says what keeps it from S. "Certified to FIPS 140-3 Level 3 and supports secp256k1 natively, with a 99.999% SLA. Keys cannot be exported, which keeps it from S."

## Figures in text

Every table cell, list item, and paragraph of the report keeps its facts apart in a way the reader can scan.

- Let at most two of the parts that commas divide hold a figure. Count across the whole cell or paragraph, because a period does not start a new count
- Count citations such as [3], dates, and version numbers as figures
- The Japanese comma, and a slash, a bar, or a middle dot with a space on each side, divide parts as a comma does
- Join a third fact with "and", or move the figures to their own table columns
- Give a label its own table cell, heading, or `<dt>`, with its value in the next cell, under the heading, or in the `<dd>`, so that no line pairs a label and a value with a colon or `=`

## Components

### Callout

```html
<div class="callout"><strong>Background</strong><p>Why the comparison was needed.</p></div>
<div class="callout warn"><strong>Risk</strong><p>A risk that could rule a candidate out.</p></div>
```

### Top three picks

```html
<div class="picks">
  <div class="pick gold"><span class="place">1</span><h3>Name</h3><p>Why it is first.</p></div>
  <div class="pick silver"><span class="place">2</span><h3>Name</h3><p>Why it is second.</p></div>
  <div class="pick bronze"><span class="place">3</span><h3>Name</h3><p>Why it is third.</p></div>
</div>
<ul class="findings"><li>A finding with its number and source [3].</li></ul>
```

### Candidate cards

```html
<div class="cards">
  <div class="card">
    <h3>Name <span class="tag t1">Type</span></h3>
    <p>What it is, in three or four sentences.</p>
    <p class="pros">One strength.</p>
    <p class="cons">One weakness.</p>
  </div>
</div>
```

The tag classes `t1` to `t5` give up to five types their own color.

### Comparison table

```html
<div class="table-wrap">
<table>
  <thead><tr><th>Candidate</th><th class="num">Price per month</th><th class="center">Score</th><th class="rationale">Rationale</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td class="num">$1,200</td><td class="center"><span class="score a">A</span></td><td class="rationale">Certified to FIPS 140-3 Level 3 and supports secp256k1 natively, with a 99.999% SLA. Keys cannot be exported, which keeps it from S.</td></tr>
  </tbody>
</table>
</div>
<p class="note">Prices from each vendor's pricing page, read on 2026-11-12 [4][5].</p>
```

Right-align numbers with `num`, and center scores with `center`.

### Scores

```html
<span class="score s">S</span>  Outstanding
<span class="score a">A</span>  Strong
<span class="score b">B</span>  Good
<span class="score c">C</span>  Adequate
<span class="score d">D</span>  Weak
```

Add a `legend` under the first table that uses scores, with the labels in the report's language:

```html
<div class="legend"><span><span class="score s">S</span>Outstanding</span><span><span class="score a">A</span>Strong</span><span><span class="score b">B</span>Good</span><span><span class="score c">C</span>Adequate</span><span><span class="score d">D</span>Weak</span></div>
```

### Risk labels

```html
<span class="risk critical">Critical</span>
<span class="risk high">High</span>
<span class="risk medium">Medium</span>
<span class="risk low">Low</span>
```

### Bar chart

```html
<div class="bars">
  <h4>What is measured, and the unit</h4>
  <div class="bar"><span class="label">Name</span><span class="track"><span class="fill" style="width: 82%"></span></span><span class="value">8.2 s</span></div>
  <div class="bar muted"><span class="label">Name</span><span class="track"><span class="fill" style="width: 0%"></span></span><span class="value">Not disclosed</span></div>
</div>
```

Set each width as the value divided by the largest value in the chart.
Use `muted` for a candidate whose value was not disclosed, with a width of 0%.

### Recommendation

```html
<div class="table-wrap">
<table>
  <thead><tr><th>Recommendation</th><th>Candidate</th><th>When it is the right pick</th></tr></thead>
  <tbody>
    <tr><td>First choice</td><td>Name</td><td>The conditions under which it is the best pick.</td></tr>
    <tr><td>Alternative</td><td>Name</td><td>The conditions under which it beats the first choice.</td></tr>
    <tr><td>Fallback</td><td>Name</td><td>The conditions under which the other two cannot be used.</td></tr>
  </tbody>
</table>
</div>
```

When different users would choose differently, add the recommendations by use case under it.

```html
<div class="table-wrap">
<table>
  <thead><tr><th>Use case</th><th>Candidate</th><th>Why</th></tr></thead>
  <tbody>
    <tr><td>A site with thousands of pages</td><td>Name</td><td>Why it fits this use case, with its figure and source [3].</td></tr>
  </tbody>
</table>
</div>
```

Write the headings and the first column in the report's language, and keep each candidate in its own cell.

### Sources

```html
<ol class="sources">
  <li><a href="https://example.com/pricing">Example pricing</a> <span class="accessed">read 2026-11-12</span></li>
</ol>
```

## Colors and switches

Every color in the template is a token with a light and a dark value, so every component above follows the reader's light or dark choice on screen, and the PDF always prints in the light colors.
Write no color in the markup, such as `style="color: ..."`; the only style attribute is the width of a bar's fill.
The switches sit at the top right of the cover: English and 日本語 change the words of the switches, and Light and Dark change the colors.
The browser remembers the reader's choice, and print hides the switches.

## Page breaks

The template starts a new page after the cover, and lets the rest flow.
Table rows, cards, callouts, and charts are never split across pages.
A heading always stays on the same page as what follows it.
Add `<div class="page-break"></div>` only before a section that must start on a new page, because a forced break leaves the rest of the page empty.
