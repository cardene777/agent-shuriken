# Report structure

What goes in each section of the report, and the markup of every component the template styles.
`templates/report.html` holds the theme; write only the markup below inside it, and add no stylesheet or script.

## Placeholders

Replace every placeholder in the template. `scripts/check-report.py` fails while any is left.

| Placeholder | What to put there |
|---|---|
| `{{LANG}}` | The language code of the report, such as `en` or `ja` |
| `{{TITLE}}` | The report title, such as "Static site generators compared" |
| `{{EYEBROW}}` | A short label above the title, such as "Comparison report" |
| `{{SUBTITLE}}` | One sentence on what was compared and for whom |
| `{{STATS}}` | Three `<div><dt>label</dt><dd>value</dd></div>` items: candidates, axes, and sources |
| `{{DATE}}` | The date the research was done |
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
- One `card` per candidate: what it is in three or four sentences, who uses it, one strength and one weakness, and a `tag` for its type

### One section per axis (`.axis`)

- A table that compares every candidate on the axis, with a score and a rationale
- A `bars` chart when the axis has numbers to compare
- A `note` under each table or chart saying where the data comes from and under which conditions it was measured
- Keep measurements taken under the same conditions apart from each vendor's own figures

### Risks (`#risks`)

- A table of candidate, risk, severity as a `risk` label, mitigation, and rationale
- A `callout warn` for each risk that could rule a candidate out

### Ranking (`#ranking`)

- A scorecard table: one row per candidate, one score per axis, and an overall comment in the rationale column
- The recommendation: the first choice, an alternative, and a fallback, each with the conditions under which it is the right pick
- Recommendations by use case when different users would choose differently

### Sources (`#sources`)

- Every source as an `<li>` in `<ol class="sources">`, with a link and the date it was read
- Number the sources in the order they are cited, and cite them in the text as `[n]`

## Rationale rule

Every table that contains a score or a risk label has a rationale column, `<th class="rationale">`.
In the scorecard, the same column holds the overall comment.
When no comparable figure exists for a candidate on an axis, write "Not scored" in the score cell, in the report's language, and say why in the rationale.

- Put numbers first: prices, throughput, availability, release dates, counts
- Place the candidate against the others, such as "half the price of B" or "the most of the five"
- Say why it is not one grade higher, such as "A, not S, because the SLA is not published"
- Keep it to one or two sentences, about 15 to 30 words, so the table stays readable

An example of a rationale: "FIPS 140-3 Level 3 certified, supports secp256k1 natively, and offers a 99.999% SLA. Keys cannot be exported, which keeps it from S."

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
    <tr><td>Name</td><td class="num">$20</td><td class="center"><span class="score a">A</span></td><td class="rationale">Why it gets this score.</td></tr>
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

### Sources

```html
<ol class="sources">
  <li><a href="https://example.com/pricing">Example pricing</a> <span class="accessed">read 2026-11-12</span></li>
</ol>
```

## Page breaks

The template starts a new page after the cover, and lets the rest flow.
Table rows, cards, callouts, and charts are never split across pages.
A heading always stays on the same page as what follows it.
Add `<div class="page-break"></div>` only before a section that must start on a new page, because a forced break leaves the rest of the page empty.
