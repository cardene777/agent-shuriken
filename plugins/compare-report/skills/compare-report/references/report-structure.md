# Report structure

What goes in each section of the report, and the markup of every component the template styles.
`templates/base.html` holds the theme, with light and dark colors, the language and light/dark switches, and the script that runs them.
Write only the markup below inside it, leave the frame and its script as they are, and add no stylesheet, script, or color of your own.

## Placeholders

Replace every placeholder in the template. `scripts/check-report.py` fails while any is left.

| Placeholder | What to put there |
|---|---|
| `{{LANG}}` | The language code of the report, such as `en` or `ja`. The report's text stays in this language, and the language switch starts from it |
| `{{TITLE}}` | The report title, such as "Static site generators compared" |
| `{{EYEBROW}}` | A short label above the title, such as "Comparison report" |
| `{{SUBTITLE}}` | One sentence on what was compared and for whom |
| `{{CANDIDATE_COUNT}}` | The number of candidate cards, as digits |
| `{{AXIS_COUNT}}` | The number of axis sections, as digits |
| `{{SOURCE_COUNT}}` | The number of sources in the sources section, as digits |
| `{{DATE}}` | The date the research was done, which is also the date of the information the report reflects, as `YYYY-MM-DD` |
| `{{AUTHOR}}` | The name the user gave for the cover, with `&`, `<`, and `>` escaped. When the user chose no name, replace it with nothing, leaving no space between the tags, and the row is hidden |
| `{{TOC}}` | One `<li><a href="#id">title</a></li>` per section, in order |
| `{{SUMMARY}}` | The summary section's content, starting with its `<h2>` |
| `{{CANDIDATES}}` | The candidates section's content |
| `{{AXES}}` | One `<section id="axis-..." class="chapter axis">` per evaluation axis |
| `{{RISKS}}` | The risks section's content |
| `{{RANKING}}` | The ranking section's content |
| `{{SOURCES}}` | The sources section's content |
| `{{FOOTER}}` | One line saying the report reflects public information on the research date, without the date itself |

The cover shows the counts, the research date, and the author in its table of facts, so write the date nowhere else in the report.
`scripts/check-report.py` fails when a count differs from the cards, the axis sections, or the sources.
Each section starts with an `<h2>`.
The template numbers the sections, so do not number the headings yourself.

## Sections

### Summary (`#summary`)

- Why the comparison was needed, as a plain paragraph right under the heading
- The top three picks as `picks`, each with one or two sentences on why
- Five to seven findings as a `findings` list

### Candidates (`#candidates`)

- A table of every candidate with its type, license or pricing model, and status
- One `card` per candidate, with a summary line, its type, who uses it, one strength, one weakness, and what it is in three or four sentences

### One section per axis (`.axis`)

- One sentence right under the heading on what the axis measures and which way is better
- A table that compares every candidate on the axis, with a score and a rationale
- A bar chart when the axis has numbers to compare, drawn as [Charts with dragon](#charts-with-dragon) describes
- A `note` under each table or chart saying where the data comes from and under which conditions it was measured, written as [Figures in text](#figures-in-text) describes
- Keep measurements taken under the same conditions apart from each vendor's own figures

### Risks (`#risks`)

- A table of candidate, risk, severity as a `risk` label, mitigation, and rationale, as the example under [Risk labels](#risk-labels) shows
- A `caution` after the table for each risk that could rule a candidate out, at most two, with a title that states the risk

### Ranking (`#ranking`)

- A scorecard table with one row per candidate, one score per axis, and an overall comment in the rationale column
- A [recommendation](#recommendation) table with the first choice, an alternative, and a fallback, each with the conditions under which it is the right pick
- A table of recommendations by use case, when different users would choose differently

### Sources (`#sources`)

- Every source as an `<li>` in `<ol class="sources">`, with a link and the date it was read
- Number the sources in the order they are cited, and cite them in the text as `[n]`

## Candidate keys

Give each candidate one key of lowercase letters, digits, and hyphens, such as `quarry`, and put it as `data-candidate` on its card and on its row in every table: the candidates table, each axis table, the risks table, and the scorecard.
On screen the template shows the candidates as a list beside the details of the pressed candidate, and the details gather the card, the candidate's score and rationale from each axis table, and its rows of the risks table by this key.
The address keeps the shown candidate as `#item-<key>`, and the full view as `#item-<key>/full`.
Print and the PDF show the cards instead, in their order.
`scripts/check-report.py` fails when a card has no key or a row names a key that no card has.

## Row order

Order the rows of each axis table and its bar chart best first on that axis.
Order the candidates table, the candidate cards, and the scorecard by overall rank, with the first choice first.
Order the risks table most severe first, from critical to low.
Mark the column the rows follow with `aria-sort` on its `<th>`, `ascending` when the smallest value comes first and `descending` when the largest does.

```html
<thead><tr><th scope="col" class="short">Candidate</th><th scope="col" class="num" aria-sort="ascending">Build time (s)</th><th scope="col" class="center">Score</th><th scope="col" class="rationale">Rationale</th></tr></thead>
```

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

### Top three picks

```html
<ol class="picks">
  <li class="pick gold"><span class="place">1</span><h3>Name</h3><p>Why it is first.</p></li>
  <li class="pick silver"><span class="place">2</span><h3>Name</h3><p>Why it is second.</p></li>
  <li class="pick bronze"><span class="place">3</span><h3>Name</h3><p>Why it is third.</p></li>
</ol>
<ul class="findings"><li>A finding with its number and source [3].</li></ul>
```

### Candidate cards

```html
<ul class="cards">
  <li class="card" data-candidate="name">
    <h3>Name</h3>
    <p class="summary">What it is, in one line.</p>
    <dl>
      <dt data-t="fieldType">Type</dt><dd><span class="tag t1">Open source</span></dd>
      <dt data-t="fieldUsers">Used by</dt><dd>Who uses it, with a source [2].</dd>
      <dt data-t="fieldStrength">Strength</dt><dd>One strength.</dd>
      <dt data-t="fieldWeakness">Weakness</dt><dd>One weakness.</dd>
    </dl>
    <p>What it is, in three or four sentences.</p>
  </li>
</ul>
```

Keep the parts of every card in this order.
The template writes the four labels in the language the reader picks, so leave their `data-t` as they are.
The tag classes `t1` to `t5` give up to five types their own color, apart from the colors of scores and severities.

### Comparison table

```html
<div class="table-wrap">
<table>
  <caption>Price by candidate</caption>
  <thead><tr><th scope="col" class="short">Candidate</th><th scope="col" class="num" aria-sort="ascending">Price per month (USD)</th><th scope="col" class="center">Score</th><th scope="col" class="rationale">Rationale</th></tr></thead>
  <tbody>
    <tr data-candidate="name"><th scope="row" class="short">Name</th><td class="num">1,200</td><td class="center"><span class="score a">A</span></td><td class="rationale">Certified to FIPS 140-3 Level 3 and supports secp256k1 natively, with a 99.999% SLA. Keys cannot be exported, which keeps it from S.</td></tr>
  </tbody>
</table>
</div>
<p class="note">Prices from each vendor's pricing page, read on 2026-11-12 [4][5].</p>
```

Give every table a `<caption>` that names it, column headers as `<th scope="col">`, and the candidate's name as `<th scope="row">`.
Right-align numbers with `num`, put their unit in the column header, and center scores and "Not scored" with `center`.
Give a column of a few words, such as the candidate's name, a type, a license, or a risk label, the class `short` on its `<th>` and on each of its `<td>` or row headers.
Numbers, scores, and `short` columns stay on one line and only as wide as they need, so the columns of sentences, such as a pricing model, a mitigation, or a rationale, get the rest of the width.
Leave the columns of sentences without a class, apart from `rationale`.
The template stripes tables of six or more columns, and lets a wide table scroll sideways inside its box with the name column kept in view.

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
<div class="legend"><span><span class="score s">S</span><span data-t="scoreS">Outstanding</span></span><span><span class="score a">A</span><span data-t="scoreA">Strong</span></span><span><span class="score b">B</span><span data-t="scoreB">Good</span></span><span><span class="score c">C</span><span data-t="scoreC">Adequate</span></span><span><span class="score d">D</span><span data-t="scoreD">Weak</span></span></div>
```

### Risk labels

```html
<span class="risk critical">Critical</span>
<span class="risk high">High</span>
<span class="risk medium">Medium</span>
<span class="risk low">Low</span>
```

The template puts an icon before each word, a different one for each severity.
The risks table puts the label in a `short` column.

```html
<div class="table-wrap">
<table>
  <caption>Risks by candidate</caption>
  <thead><tr><th scope="col" class="short">Candidate</th><th scope="col">Risk</th><th scope="col" class="short" aria-sort="descending">Severity</th><th scope="col">Mitigation</th><th scope="col" class="rationale">Rationale</th></tr></thead>
  <tbody>
    <tr data-candidate="name"><th scope="row" class="short">Name</th><td>Slow release pace</td><td class="short"><span class="risk high">High</span></td><td>Check the release page again before adopting it, and keep a way to move to another candidate.</td><td class="rationale">Two releases in the last 12 months [6] against 14 for the first choice [2].</td></tr>
  </tbody>
</table>
</div>
```

### Caution

```html
<div class="caution"><h3>Brisk keeps the built site on its own servers</h3><p>The guide describes no way to download the built site, so moving away means building it again [5].</p></div>
```

Write the title as the risk itself, never a word such as "Risk" or "Warning", and keep the text to one or two sentences.
The template adds the warning icon.

### Bar chart

```html
<div class="bars">
  <h4>Build time on the published benchmark (s)</h4>
  <div class="bar"><span class="label">Name</span><span class="track"><span class="fill" style="width: 82%"></span></span><span class="value">8.2</span></div>
  <div class="bar"><span class="label">Name</span><span class="track"><span class="fill" style="width: 100%"></span></span><span class="value">10</span></div>
</div>
```

Put what is measured and its unit in the heading, and only the number in each value.
Set each width as the value divided by the largest value in the chart.
Leave a candidate whose value was not disclosed out of the chart, and say in the `note` that its figure was not disclosed.
Long names wrap in their column.

### Recommendation

```html
<div class="table-wrap">
<table>
  <caption>Recommendation</caption>
  <thead><tr><th scope="col" class="short">Recommendation</th><th scope="col" class="short">Candidate</th><th scope="col">When it is the right pick</th></tr></thead>
  <tbody>
    <tr><th scope="row" class="short">First choice</th><td class="short">Name</td><td>The conditions under which it is the best pick.</td></tr>
    <tr><th scope="row" class="short">Alternative</th><td class="short">Name</td><td>The conditions under which it beats the first choice.</td></tr>
    <tr><th scope="row" class="short">Fallback</th><td class="short">Name</td><td>The conditions under which the other two cannot be used.</td></tr>
  </tbody>
</table>
</div>
```

When different users would choose differently, add the recommendations by use case under it.

```html
<div class="table-wrap">
<table>
  <caption>Recommendation by use case</caption>
  <thead><tr><th scope="col">Use case</th><th scope="col" class="short">Candidate</th><th scope="col">Why</th></tr></thead>
  <tbody>
    <tr><th scope="row">A site with thousands of pages</th><td class="short">Name</td><td>Why it fits this use case, with its figure and source [3].</td></tr>
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

## Charts with dragon

When page-design is installed, draw each bar chart with dragon in place of the `bars` component, as the `page-design` skill draws its figures.
Put each chart in a `figure` as a still dragon block, in the report's language.

```html
<figure class="figure"><pre class="dragon" data-still>
chart Build time on the published benchmark in seconds [shape: bar]

item quarry as Quarry
item brisk as Brisk

step Benchmark
  say Build time of each candidate on its published benchmark.
  set quarry: 1.2
  set brisk: 2.9
</pre></figure>
```

Write each block's notation to a temporary `.dragon` file, run `npx -y @cardenelabs/dragon@<version> check <file>` and the same command with `--layout`, fix what they name, and remove the file.
`<version>` is the version that the `page-design` skill names for dragon.
When every section is written, put the dragon entry line that the `page-design` skill gives in the report's `<head>`, and run `npx -y @cardenelabs/dragon@<version> embed <path of report.html> --out <path of report.html>`.
`dragon embed` draws every still block as an SVG and removes the entry line, so the report reads no other file.
When the `page-design` skill is not installed, when Node.js is missing, or when `dragon embed` fails, use the `bars` component instead, and remove the entry line.
`scripts/check-report.py` fails while a dragon block is left undrawn.
Pressing a chart or a figure opens it larger in a dialog.

## Colors and switches

Every color in the template is a token with a light and a dark value, so every component above follows the reader's light or dark choice on screen, and the PDF always prints in the light colors.
Write no color in the markup, such as `style="color: ..."`; the only style attribute is the width of a bar's fill.
The switches sit at the top right of the cover.
English and 日本語 change the words of the frame and leave the report's text as written.
The frame's words are the labels of the facts, the contents heading, the controls of the list and the details, the labels of the score legend and the candidate cards, and the controls of the enlarged charts.
Light and Dark change the colors.
The browser remembers the reader's choice, and print hides the switches.

## Page breaks

The template starts a new page after the cover, and lets the rest flow.
Table rows, cards, cautions, and charts are never split across pages.
A heading and the paragraph right under it stay on the same page as what follows them, and a table's caption and header row stay with its first row.
Add `<div class="page-break"></div>` only before a section that must start on a new page, because a forced break leaves the rest of the page empty.
