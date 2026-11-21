# Deck outline format

The format of the Markdown outline (`slides-outline.md`) that slide-builder writes and `scripts/validate.py` checks.
The outline is written for whoever turns it into slides later: a person, another skill, or a slide tool.
It says what each slide shows and explains, in words. It does not say how the slide looks: no colors, layouts, or sizes.

`examples/slides-outline.md` is a complete ten-slide outline in this format.

## Principles

| Point | Rule |
|---|---|
| File | Plain Markdown, no YAML or JSON |
| Structure | `---` separates slides, an H2 heading starts each slide, and H3 headings start its sections |
| Words | Say in plain language what the slide shows and what it explains |
| Style | Write as you would say it: short active sentences addressed to the audience. Avoid stiff report language ("it is noted that", "is utilized") |
| Density | Around 80 to 200 words per slide. Full, not terse |
| Meta statements | None in the body: no talk length, intended audience, or "this deck covers N items". Keep the body on the content |
| Tables | Only for content that is naturally a table: a comparison, a list of items, a mapping |
| Design | None: colors, fonts, positions, and animation belong to whoever draws the slides |
| Figures | Defined in words with four parts (purpose, message, elements, what to avoid). No ASCII drawings |
| Names | No internal short codes (`R2`, `T-Q3`). Use names a first-time reader understands. Common industry abbreviations (`FAQ`, `KPI`) are fine |

## The whole file

```markdown
# <Deck title>

> meta: width=1280 height=720 lang=en

## Outline

| Part | Chapter | Slides |
|---|---|---|
| Part 1 | ... | 1-6 |

N slides in total.

---

<slide 1>

---

<slide 2>

---

...
```

The file starts with an H1 title, a meta line, and the outline table. Then come the N slides, each between `---` lines.

## One slide

Each slide has these blocks.

```markdown
---

## Slide N / M ─ <title>

> meta: type=<slide type> eyebrow="..." [more keys...]

### Takeaway

<the conclusion in one or two sentences>

### Explanation

<paragraphs, a list, or a table>

### Figure

**Purpose**: <what the figure is for, in one sentence>

**Message**: <what the audience should understand from it, in one or two sentences>

**Elements**:

- <element 1>
- <element 2>
- <element 3>

**Avoid**: <what the figure should not become>

---
```

### Slide heading (`## Slide N / M ─ <title>`)

| Part | Meaning |
|---|---|
| `Slide N / M` | N is the slide number (1 to M), and M is the number of slides |
| `─` (U+2500 BOX DRAWINGS LIGHT HORIZONTAL) | The separator. A plain `-` also works |
| `<title>` | The subject of the slide in everyday words, one line of about six words |

Example: `## Slide 03 / 10 ─ What goes wrong`

### Meta line (`> meta: ...`)

One line of `key=value` pairs separated by spaces.

| Key | Required | Value |
|---|---|---|
| `type` | Yes | `hero`, `chapter`, or `content` |
| `eyebrow` | For content and chapter slides | The small label at the top left, for example `"Part 1 · 02"` |
| `footer_label` | No | The text at the bottom left |
| `chapter_num` | Chapter slides only | The chapter number, for example `02` |

Example: `> meta: type=content eyebrow="Part 1 · 02"`

Put a value that contains spaces in `"..."`.

The headings `Takeaway`, `Explanation`, `Figure`, and the `Elements` label have a second, Japanese spelling listed in `../scripts/outline-headings.json`.
An outline written in Japanese uses that spelling, and `scripts/validate.py` reads either one.

### `### Takeaway` (required on content slides)

One slide, one conclusion. Write two to four sentences: the conclusion and why it matters, so that a reader of this block alone knows what the slide says.

```
### Takeaway

One request in ten waited more than a day for its first reply last month.
Most of these were requests that two desks each thought the other one had.
```

### `### Explanation` (required)

The body: the background, the context, a concrete example, and the details that matter, in five to ten sentences. Split it into paragraphs when that helps. Paragraphs, lists, and tables all work.

```
### Explanation

We looked at the 100 slowest requests of last month.
In 62 of them, the customer had written to two inboxes.
Each desk saw the other desk's name in the copy and waited.
The customer heard nothing for a day or more, and 14 of them cancelled their order.
```

Remove repetition and words that say nothing: when two sentences say the same thing, keep one.

### `### Figure` (only when the slide has a figure)

Define the figure in words with four parts. Do not use ASCII drawings, tables, or pixel shapes: leave the shape to whoever draws the slide.

1. **Purpose** (one sentence): what the figure is for
2. **Message** (one or two sentences): what the audience should understand from it
3. **Elements** (a list of three to five items): the data, people, and relationships the figure must show
4. **Avoid** (optional, one or two items): what the figure should not become, for example "not a process diagram"

```
### Figure

**Purpose**: Show that one month of requests is split across three inboxes that do not see each other.

**Message**: Most requests land in London, and no desk can see the other two inboxes.

**Elements**:

- The 1,000 requests of last month as one whole
- London 600, Paris 300, Berlin 100
- A clear separation between the three inboxes

**Avoid**: A process diagram. This slide shows where requests are, not how they move.
```

Rules.

- Fill the purpose, the message, and the elements. The elements are what specify the figure, and the validator rejects a figure without them
- List three to five elements. With six or more, split the figure across slides
- No colors ("paint it blue"), shapes ("as a bar chart"), positions ("side by side"), or pixel sizes ("80 px high")
- No ASCII drawings

Why words: whoever draws the slide can then choose the best form, a bar, a pie, nested boxes, or an icon breakdown, instead of copying a fixed drawing.

## Slide types

### type=hero (title or questions slide)

```markdown
---

## Slide 01 / 10 ─ Moving the support desk to one shared inbox

> meta: type=hero

### Takeaway

From next month, every customer request reaches one shared inbox, and each request has one person who answers it.

### Explanation

This is the update for the support, sales, and product teams.

Key numbers.

- 3 inboxes become 1
- 4 hours to the first reply
- 0 requests without an owner

---
```

`### Figure` may be left out. A short list such as "Key numbers" is fine.

### type=chapter (chapter opener)

```markdown
---

## Slide 04 / 10 ─ Chapter 2: One shared inbox

> meta: type=chapter chapter_num=02 eyebrow="Part 2"

### Takeaway

One inbox for all three desks, with one owner for every request, removes the waiting between desks.

### Explanation

This chapter has four slides.
It shows the inbox, how a request gets its owner, and what the first month showed.

---
```

### type=content (a normal slide)

The most common type, with the three blocks Takeaway, Explanation, and Figure.

## Tables

Use a table only for content that is naturally a table: a comparison, a list of items, or a mapping.

A good table (a comparison).

```markdown
### Explanation

| | Before | After |
|---|---|---|
| Inboxes | Three, one per desk | One, shared |
| Owner of a request | Unclear | The first person who opens it |
```

A table that should be a paragraph.

```markdown
### Explanation

| Key | Value |
|---|---|
| Point | One inbox for all desks |
```

Use a table when there are at least three rows and two columns to compare. Otherwise, write a paragraph.

## Chapters

H2 headings start slides. A chapter is a slide with `type=chapter` and `chapter_num`, not a separate `## Chapter N` heading, which would flatten the headings and make the outline harder to read.

The outline table at the top shows which slides belong to which chapter.

## How the format follows the readability rules

The format keeps the rules of `references/readability-rules.md`.

| Readability rule | How the format keeps it |
|---|---|
| One message per slide | One `### Takeaway` per slide |
| One action per sentence | One sentence per line in the explanation |
| Concrete examples | Numbers and people in the explanation |
| Numbers in everyday units | Added in the explanation |
| Terms explained | In a short phrase at first use |
| The figure supports the text | A slide works without `### Figure` |
| No code words | In every section |

## What the validator checks

`scripts/validate.py` checks these points and exits 1 when any error is found.

| Check | Result |
|---|---|
| Every slide has a `## Slide N / M ─ <title>` heading | Error when no slide is found |
| Slide numbers count up from 1 and every slide gives the same total | Error |
| Every slide has a `> meta:` line with `type=` | Error |
| A content slide has `### Takeaway` | Error |
| A `### Figure` section has an `Elements:` list with at least one item | Error |
| A figure lists at most five elements | Warning |
| No general code word, or word given with `--ban`, outside code and quotes | Warning |

Text inside backticks, double quotes, and code blocks is not checked for code words, so a slide can quote a term when it has to.
