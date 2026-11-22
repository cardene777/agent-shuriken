---
name: product-deck
description: Makes a product introduction deck. Takes screenshots of the real product, decides the structure from a base of ten slides, writes the files that build the slides in the user's repository, and renders the HTML, PDF, and PowerPoint to hand out. All the text stays in one file and the layout code holds no words; three machine checks are run to zero before the slides are looked at full size. Use when asked for a product deck, a service introduction deck, product slides, or a deck that explains a product.
---

# Product Deck

This skill makes a deck that explains one product: what it is, the problem it answers, how it is used, and how it differs.
It has no company profile, no prices, and no contact page.

Talk to the user in the language they write in.
When a step below says to ask the user, ask the user in the chat and wait for the answer.

Read `references/deck-structure.md` first: it holds the base structure of ten slides.

## Where the tools are

The scripts are in the `scripts/` folder next to this file. Set the folder once and use it in every step:

```bash
S=<folder that contains this SKILL.md>/scripts
```

The scripts that drive a browser (`capture.mjs`, `audit.mjs`, `shoot.mjs`, `render.mjs`, `glyph-fit.mjs`) take Playwright from the user's project.
Set `PLAYWRIGHT_FROM` to a project folder where `@playwright/test` is installed; when it cannot be resolved, the script stops with exit 2 and says so.
When the user has no such project, ask the user in the chat where Playwright may be installed.

## What it holds and what the deck holds

| Layer | Where it lives |
|---|---|
| The structure (which slides, in what order) | This skill |
| Every word that appears on a slide | `build/deck-data.mjs` of the deck in the user's repository |
| How each slide is laid out, figures, type, colors | `build/deck-faces*.mjs` and `build/deck-styles.mjs` of the deck |
| The rules of layout and writing | `references/` of this skill |
| The machine checks | `scripts/` of this skill and `build/measure-*.mjs` of the deck |

**Do not put the words and the layout in the same file.** Words written into the layout code cannot be picked up by the editing screen and show up as items that cannot be edited; `references/writing-rules.md`, "Do not write the slide text into the layout code", gives the reason and the fix.

## Steps

### 1. Take screenshots of the product

**Take them before deciding the structure.** Decide which screen goes where after seeing what could be taken.

```bash
PLAYWRIGHT_FROM=<project with Playwright> node "$S/capture.mjs" \
  --url <URL> --out <out-dir>/assets/<name>.png [--wait-for <CSS selector>]
```

For a screen behind a login, ask the user in the chat for a URL that carries a token, or for the path of a screenshot already taken.

**Do not take empty screens.** A screen without data does not show the product working; wait with `--wait-for` until the content appears.

Look at each screenshot and confirm what it shows before going on.

Samples of how to place screenshots are read only when the user keeps them. List them with these two lines:

```bash
samples="$HOME/.product-deck/samples"
[ -d "$samples" ] && ls "$samples"
```

When the folder lists images, look at them before placing screenshots; without it, follow `references/layout-rules.md`.

### 2. Decide the structure

Start from the ten slides of `references/deck-structure.md`.
Add and remove slides to fit the material, and write the plan in `<out-dir>/plan.md`:

```markdown
# Structure: <product name>

Reader: <who it is shown to>

| # | Slide | Claim | Screen | Figure |
|---|---|---|---|---|
| 1 | Cover | <one sentence> | — | — |
| 2 | Overview | <one sentence> | <path> | yes |
| ... | | | | |

Changes from the base
- <slides split, and how>
- <slides added, and why they are needed>
```

| Column | Content |
|---|---|
| `Slide` | A name of the ten base slides, or of an added slide |
| `Claim` | The one sentence the slide asserts, not a noun phrase |
| `Screen` | The path of the image to place, or `—` |
| `Figure` | `yes` or `—`. What the figure is gets decided when building (step 5) |

**Put the overview second.** Do not start from the problem and hide the product until the second half.
**Give each feature with a screenshot a slide of its own.** Features and How to use it grow to three to five slides with the material.
**Keep the whole deck within 20 slides**; split the deck when it would be longer.
Write the reason for each added or removed slide under "Changes from the base".

### 3. Write the text of each slide

**Read `references/writing-rules.md` first.** Each section comes from a sentence a reader called machine-like or meaningless.

Write the text slide by slide in `<out-dir>/content.md`:

```markdown
## <number> <slide name>

### Claim
<one sentence, as in plan.md>

### Body
<two to four sentences, one per line>

### Notes
- <up to two, if any>

### What the figure should show
<one sentence: what the figure should make clear. No elements and no layout>

### Table
<only on slides shown as a table, as a Markdown table>
```

**Write what the figure should show in one sentence.** Do not decide elements or layout yet: deciding the layout before seeing the material fixes the shape early and fills the slides with rows of identical boxes.

Lean on the visual, and do not crowd a slide.

### 4. Show and fix

Give the user `plan.md` and `content.md`, sum up the structure in five lines or fewer, and ask the user in the chat what to change.
Change only these two files at this step, with no layout and no placement of images.
Repeat until the user approves.

### 5. Write the files that build the slides

In the user's repository, write the files that build the slides in `docs/decks/<name>/build/`.
**Keep the words apart from the layout**; otherwise the text cannot be edited on the screen later.

| File | What it holds |
|---|---|
| `deck-data.mjs` | Every word on the slides, as `export const faces = [...]`, one object per slide. No layout at all |
| `render.mjs` | The shared function that builds one slide. The handout and the editing screen read the same one |
| `deck-faces.mjs` | How each slide style is laid out |
| `deck-faces4.mjs` | The slides added per style, and their CSS |
| `deck-styles.mjs` | The list of styles and their colors |
| `deck-base-css.mjs` | The base CSS that every style uses |

A slide's style is chosen by its `kind`. Slides of one `kind` are built by one function, so to change the shape of one slide, add a style or add data for that slide.

**Write no words in the layout code**, including words with numbers such as "all three"; every word on a slide goes in `deck-data.mjs`.

### 6. Render

There are four renderers, and each takes `PLAYWRIGHT_FROM`:

```bash
cd docs/decks/<name>
export PLAYWRIGHT_FROM=<project with Playwright>

node build/build-deck.mjs          # the HTML to hand out, with one style; runs the layout check
node build/build-decks.mjs         # the HTML that compares the styles; runs the layout and wording checks
node build/build-slide-edit.mjs    # the screen to edit the text
node build/measure-shot-glyph.mjs  # whether the text in the screenshot cutouts is large enough to read
```

`build-deck.mjs` and `build-decks.mjs` run the checks inside and stop at a flagged slide, so a finished render means the checks passed.

**Render again only the side that changed.** Rendering everything takes over two minutes: render the handout again, look at it full size, and run the rest when it passes.

### 7. Run the checks to zero

There are three checks. `build-decks.mjs` runs the first two inside; call them directly only to run one alone.

| Check | What it sees |
|---|---|
| `scripts/audit-text.mjs` | The choice of words and how sentences are built, from the data, without rendering |
| `scripts/audit.mjs` | The layout, measured on the rendered slides |
| `<deck>/build/measure-shot-glyph.mjs` | Whether the text in each screenshot cutout is 22px or more |

**Run the wording check first**: it reads only the data, so it is fast and catches the choice of words before rendering.

```bash
node "$S/audit-text.mjs" <deck>/build/deck-data.mjs --terms <deck>/build/writing-terms.txt
```

It reads two word lists, and the plugin ships neither:

| List | Default place | What it holds |
|---|---|---|
| The words to drop | `~/.product-deck/prose-words.txt`, or `--prose-words <path>` | The user's own words to drop from any deck, by kind (wordy phrases, words the reader does not know, the maker's notes, bare English words) |
| The deck's terms | `~/.product-deck/writing-terms.txt`, or `--terms <path>` | The words this deck decided on, the core words and the slides that explain them, and the phrases it keeps |

Write the deck's terms yourself in `<deck>/build/writing-terms.txt`, from the decisions of `plan.md` and `content.md`.
When the list of words to drop is missing, the script runs no check and exits 2 naming the place it looked: ask the user in the chat where their list is, or whether to start one in `~/.product-deck/prose-words.txt`.
`docs/how-it-works.md` of the plugin shows how to write both lists.
Passives and katakana words are listed, not flagged: look at them and decide.

Then run the layout check, and **do not leave after one round**: fix, render again, and run until it prints `flagged 0 slides`.

```bash
PLAYWRIGHT_FROM=<project with Playwright> \
  node "$S/audit.mjs" <viewer HTML> <style> [style ...]
```

It exits 1 when any slide is flagged. After fixing, **always render again before checking**: judging by an old image points out a fixed defect again.

**Pass a style name exactly as the viewer shows it.** With a name it cannot find, the viewer keeps showing its first style; the script stops at that point and lists the names it can open.

To render each slide full size:

```bash
PLAYWRIGHT_FROM=<project with Playwright> node "$S/shoot.mjs" \
  <viewer HTML> <style> <output folder> [slide number ...]
```

Given slide numbers, it renders only those slides again, which makes the round trip of one fix fast.

**When you find a rule the checks do not cover, add the check to `audit.mjs` there and then.** A rule written without a check is pointed out again next time. The table in `references/layout-rules.md` maps each section to its check.

**A new check reports what it counted**: not only how many slides were seen and flagged, but how many items the check itself looked at. When that count is 0 the check looked at nothing, so stop with exit 2 instead of passing. Without the count, a check whose search no longer matches the slides returns "flagged 0 slides" while it guards nothing.

**After fixing one slide, count at once whether the same form remains on other slides.** Fixing slide by slide leaves the same break on another slide; scanning all slides for the disagreement takes seconds.

### 8. Look at full size

**Some slides are broken even when nothing is flagged.** The checks see only part of the rules (the `CHECKS` of `audit.mjs`); the rest can only be seen.
Open each rendered PNG and look at it.

| # | What to look at |
|---|---|
| 1 | No internal identifier appears on a slide |
| 2 | No text leaves its frame, and no elements overlap |
| 3 | No word is written twice, in English and in Japanese |
| 4 | The figure and the body do not say the same thing |
| 5 | The margins at the edges match on every slide |
| 6 | Each image is on the slide it belongs to |
| 7 | The text of each screenshot can be read, and the side it leaves the slide matches the cutout's shape |
| 8 | Slides of identical rows of boxes do not follow each other |
| 9 | The number of colors stays within the limit |
| 10 | The amount of text on each slide stays within the limit |

The limits of 7 to 10 are in `references/deck-structure.md`, under "Layout discipline" and "Do not"; change them there only.
After fixing, always render again before judging.

### 9. Make the text editable on the screen

After rendering, the text always goes back and forth. Editing the text on the slide itself is faster than finding it in a file.

| Part | What it does |
|---|---|
| Building a slide | The handout and the editing screen use the same function (`build/render.mjs` of the deck) |
| The editing screen (`build/build-slide-edit.mjs`) | After building the slides, wraps each text that matches a value of the text file in `contenteditable`. Keeps the edits in `localStorage` and exports them as JSON |
| The tool that writes back (`build/apply-edits.mjs`) | Finds each original value by its place in the JSON (such as `0.claim[0]`) and replaces it in the text file |

**Make one screen.** Show the slides one at a time at full size, and list the items that cannot be edited in a folded area below each slide.
A reduced overview of all slides is possible, but it can only do part of what the full-size screen does, and two screens read the same base two ways and drift apart.

**Do not treat the confirmation of an input method as Enter.** Calling `preventDefault` on `Enter` to stop new lines also stops the confirmation of Japanese input and enters the same characters twice. Skip `e.isComposing` and `keyCode === 229`, and save only after `compositionend`.

**Wrap only text that matches a value exactly**, and list the items that do not match, slide by slide. Such an item is a sign that the layout code cuts a value (`references/writing-rules.md`, "Do not write the slide text into the layout code").
When one value appears on two slides, narrow the search to the slide before replacing; otherwise it cannot be decided which to change.

### 10. Render the handouts

Render once the content is settled. Each render adds a file of nearly 4 MB to the history, so while the work moves, the renderers may be kept and their output left untracked.

```bash
node build/build-pdf.mjs    # a PDF through Chromium's printing; the text stays selectable
node build/build-pptx.mjs   # a PowerPoint with one screenshot per slide
```

Count after rendering:

| What | Passes when |
|---|---|
| Pages of the PDF | Equal to the number of slides |
| Size of the PDF | Under 4 MB |
| Selectable text in the PDF | `pdftotext` finds the slides' words |
| Slides of the PowerPoint | Equal to the number of slides |
| Relations inside the PowerPoint | One relation to a slide layout per slide |

**Do not read "made" as "opens".** A PowerPoint can pass the count, the size, and an intact zip and still ask for repair when opened; count the relations the format requires.

### 11. Hand over

Hand over the rendered HTML, PDF, and PowerPoint.
Changes to the look go back to `build/deck-faces*.mjs` and `build/deck-styles.mjs`; changes to the text go back to `deck-data.mjs` from the editing screen through `apply-edits.mjs`.
Do not edit the rendered HTML: the next render erases the edit.

## What it does not do

| Not this | Instead |
|---|---|
| Designing the product's screens | A design tool |
| A document to read | A writing or documentation tool |
| Slides for a technical talk | A slide tool |
| The content of the deck itself | `build/deck-data.mjs` of the deck |

## Gotchas

**Take the screenshots before the structure.** A structure decided first makes slides without material.

**Do not make an image frame on a slide without an image**; only the empty frame remains.

**Say nothing about quality before looking at full size.** Slides break even when the checks pass.

**The layout rules are in `references/layout-rules.md` and the writing rules in `references/writing-rules.md`.** Check against both before building and after rendering.

**Do not call one thing by different words.** Give one word to each thing in the deck, write the words decided against in the deck's banned words (`audit.mjs --words <path>`, starting from `references/banned-words.txt`), and the `synonym` lines of the terms.

**Add the check when adding a rule**, and **run the checks to zero before looking at full size**: in the other order, you search by eye for defects a machine finds.

### Found in rendered decks

Each was met once and fixed; none is a guess.

**Do not add `<html lang="ja">`.** It changes how Chromium embeds fonts in the PDF, and the handout grew from 3.9 MB to 9.6 MB (from 228 to 293 embedded glyph fonts). Narrowing the fonts or switching to system fonts did not bring it back.

**Do not use `span` to keep a katakana word from breaking.** When the layout CSS styles bare `span`s (stacking heading lines, rounding labels, turning ticks into panels), the style hits the wrapper and breaks the slide. A tag whose name has a hyphen (`<no-break>`) matches no rule.

**Do not put the invisible word joiner (U+2060) between letters.** It stays in the text layer of the PDF, and searching for a word on the slide finds nothing.

**Fix one to three letters left on the last line with `text-wrap: balance`.** Column widths differ per slide, so the sentences cannot be written to fit each width.

**PowerPoint requires one relation to a slide layout per slide.** Without it, opening asks for repair; the zip is intact and the count matches, so a zip check does not find it.

**`getClientRects()` returns fragments of boxes, not lines.** A tag inside the text splits a line into two or three; join rectangles with the same top into one line before measuring.

**Match a figure's aspect ratio to its frame.** Otherwise margin appears in the direction it shrinks, and only the figure's content shifts to one side (43px in one case).

**After fixing the horizontal alignment, count the vertical room.** A figure widened to the full width grows taller and pushes the explanation into the bottom margin, and the checks limit how much of that margin may be used.

### Alignment

| Form | Alignment |
|---|---|
| A box with a heading and a two-line explanation | Left, at the same distance from the box's left edge |
| A heading and an explanation below a figure | On the figure's center |
| A one-line label in a box | Centered |

**Do not derive the rule from counts alone.** Counting centered items makes them the majority, but most are explanations below figures, which have another role than the text in boxes. Separate them by place before counting.

## Done when

- [ ] The product's screens were taken, and each was looked at
- [ ] `plan.md` is written, with the reasons for the changes from the base
- [ ] `content.md` is written, and each figure is described in one sentence
- [ ] The headings and explanations were read aloud in one go against each section of `references/writing-rules.md`
- [ ] The user approved the structure
- [ ] Every word on the slides is in `build/deck-data.mjs`, and the layout code holds no words
- [ ] `node build/build-deck.mjs` printed `flagged 0 slides`
- [ ] `node build/build-decks.mjs` printed `flagged 0 slides` for both the layout and the wording
- [ ] `node build/measure-shot-glyph.mjs` reported no cutout under 22px
- [ ] Each rule found without a check got its check in `audit.mjs`, reporting what it counted
- [ ] Each rendered slide was looked at full size
- [ ] The slides were checked against each section of `references/layout-rules.md`
- [ ] After each fix, the other slides were scanned for the same form
- [ ] On the editing screen, the items that match no value are not words written into the layout code
- [ ] The PDF has as many pages as slides, is under 4 MB, and has selectable text
- [ ] The PowerPoint has as many slides as the deck, each with one relation to a slide layout
- [ ] The rendered HTML, PDF, and PowerPoint were handed over

## Files

| File | What it holds |
|---|---|
| `references/deck-structure.md` | The base structure of ten slides. Read it first |
| `references/layout-rules.md` | The layout rules. Check before building and after rendering |
| `references/writing-rules.md` | The writing rules. Check before writing and after rendering |
| `references/banned-words.txt` | Words that must not appear on a slide; `audit.mjs` reads it by default |
| `scripts/capture.mjs` | Takes a screenshot of one page |
| `scripts/audit.mjs` | Checks the rendered slides. Run until nothing is flagged |
| `scripts/audit-text.mjs` | Checks the wording from the data, before rendering |
| `scripts/shoot.mjs` | Renders each slide of a style at full size |
| `scripts/render.mjs` | Renders the slides of a deck HTML to 1920x1080 PNG files |
| `scripts/glyph-fit.mjs` | Measures whether icons fit their containers |
| `scripts/load-playwright.mjs` | Resolves Playwright from `PLAYWRIGHT_FROM` for the scripts above |
