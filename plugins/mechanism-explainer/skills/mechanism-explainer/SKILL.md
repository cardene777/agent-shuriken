---
name: mechanism-explainer
description: Writes an explainer of a system, a mechanism, or a piece of research as one HTML page that reads top to bottom, where each section answers one question with two to four figures drawn in the dragon notation, and prints it to a PDF. Use when the user asks for an explainer, a learning guide, a document with figures, or an overview of how something works, from a topic, notes, or a Markdown file.
---

# Mechanism explainer

Write an explainer as one page that answers the reader's questions in order.
Each section is one question, its one-sentence answer, and two to four figures that look at the question from different sides, such as the parts, a decision table, a comparison, or one case traced step by step.
The figures come first and the prose follows them, and every long explanation sits in a card that opens just below the box it belongs to.
dragon draws the figures and exports the page, so this skill plans the questions, writes the page in dragon's Markdown, checks it, exports it, and prints the PDF.

Talk to the user in the language they write in, and write the page in that language.
Where it says to ask the user, use AskUserQuestion in Claude Code, and ask in the chat with numbered options in other agents.

All files are next to this `SKILL.md`, and the commands below set `D` to the absolute path of that folder at the start of the same shell command.
The examples write into `explainer/<slug>/` of the folder the user works in; use another folder when the user names one.

## 1. Check the setup

The page is drawn by dragon 0.80.1, fetched by npm into its cache on first use.

```bash
npx -y @cardenelabs/dragon@0.80.1 --version
```

- When `npx` is missing, stop and tell the user to install Node.js 20 or later from nodejs.org.
- Always run dragon with this exact version. Another version may read the notation differently.

## 2. Plan the questions and figures

Before writing anything, find out who reads the page and what they should be able to do after reading it.
Read the material the user gave (a topic, notes, a Markdown file, or files in the project), and ask the user only for what the material does not say.

When the `dragon` skill is installed, write in the `plan` format of the `dragon` skill: open the `dragon` skill by name and read the file it names for `plan`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `dragon` skill is not installed, go on without the `plan` of `dragon`.

The plan follows these rules whichever way it is written.

- Plan one overview figure of the whole mechanism first: the parts, what goes between them, and which topic explains which part. It is the map the reader sees before any question.
- Split the topic into the questions the reader asks, usually two to five per topic. Each question becomes one section.
- Give each question a short menu name that keeps its key word: at most 12 characters for Japanese and 24 characters for English, so it fits on one line of the side menu.
- Give each section one question, a one-sentence answer, and two to four figures.
- Make the figures of one question look at it from different sides. Two figures that show the same thing the same way are one figure too many.
- Pick kinds by what the question asks: the parts and what goes between them, which cases pass and which stop, how two cases differ, one case step by step, or an amount against a limit.

Show the plan to the user as a short list, one line per figure with its kind and what the reader sees in it, and change it until the user agrees.
Do not write the page before the user agrees with the plan.

## 3. Write the page

Write the page as Markdown in `explainer/<slug>/<slug>.md`, each figure in the dragon notation, with its parts picked from dragon's cheatsheet.

When the `dragon` skill is installed, write in the `page` format of the `dragon` skill: open the `dragon` skill by name and read the file it names for `page`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `dragon` skill is not installed, go on without the `page` of `dragon`.

When the `dragon` skill is installed, write in the `notation` format of the `dragon` skill: open the `dragon` skill by name and read the file it names for `notation`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `dragon` skill is not installed, go on without the `notation` of `dragon`.

When the `dragon` skill is installed, write in the `cheatsheet` format of the `dragon` skill: open the `dragon` skill by name and read the file it names for `cheatsheet`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `dragon` skill is not installed, go on without the `cheatsheet` of `dragon`.

Without the `dragon` skill, follow the shape below and dragon's [notation guide](https://github.com/cardene777/dragon/blob/main/packages/dragon/examples/quick-start.en.md).

The page starts with `layout: guide` and `note: pop` between `---` lines.
dragon lists every topic (`##`) and its questions (`###`) in a side menu, runs the topics one after another, numbers the questions across them, and turns every box note into a card that opens on a click.

Write the page lead, after the `#` title and before the first topic, in this order.

1. One or two sentences that say what the mechanism does
2. The overview figure of the whole mechanism, so dragon shows it as the overview at the head of the page, with the topics as the reading route under it
3. A paragraph that says which topic explains which part of the figure

Put the overview figure in the page lead, before the first topic, and nowhere else: a topic named Overview would show up as one more topic in the menu.

Write each section in this order.

1. `### <question>? [menu: <short name>]`, with the menu name from the plan
2. `> <the answer in one sentence>`, right under the question
3. For every figure of the plan, in order: one sentence before each figure that says what to look at, the figure, and two to four sentences after it that say what the figure shows and what follows from it
4. One or two check questions as `<details>` blocks, when they help the reader test what they read

Keep the sentence before a figure and the paragraph after it as separate paragraphs, so that between two figures there are two paragraphs.
The paragraph after a figure states what the reader should conclude, such as which case passes and why, or what the next question builds on, instead of repeating the figure's step texts.

Put explanations of a box into its `note:`, so they open as a card under the box instead of crowding the figure.
Put terms the reader may not know into a `glossary.md` next to the page and link them from the text, as the `page` format says.
When the page is in Japanese and the `japanese-writing` skill is installed, open it by name and check the prose with it before the next step.

## 4. Check the notation and the layout

```bash
npx -y @cardenelabs/dragon@0.80.1 check explainer/<slug>/<slug>.md
npx -y @cardenelabs/dragon@0.80.1 check --layout explainer/<slug>/<slug>.md
```

Fix every error that `check` prints, one at a time, and run it again until it prints none.
Then fix every line that `check --layout` prints, such as step numbers piled up, lines running too close, or text sticking out of a box, and run it again until it prints none.
When a line cannot be fixed in the notation, keep it and name it in the report of step 7.
Add `--lang ja` to both commands when the page is in Japanese, so the messages are in Japanese.

## 5. Export the page

```bash
npx -y @cardenelabs/dragon@0.80.1 export explainer/<slug>/<slug>.md
npx -y @cardenelabs/dragon@0.80.1 embed explainer/<slug>/<slug>.html
```

- `export` writes `<slug>.html` next to the Markdown. Add `--lang ja` when the page is in Japanese, so the words dragon adds to the page are Japanese.
- `embed` writes `<slug>.offline.html`, which carries its scripts and opens without a network connection. Hand this file to other people.

## 6. Print the PDF

```bash
D=<folder of this SKILL.md>; python3 "$D/scripts/to-pdf.py" explainer/<slug>/<slug>.offline.html
```

It prints the page with a Chromium-based browser already on the machine, on A3 paper unless `--paper a4` or `--paper letter` is given, and writes `<slug>.offline.pdf`.
The PDF holds what dragon's print styles draw.
With dragon 0.80.1, that is the tab open when the page loads, with its term cards and check answers open and its box cards open over their figure.
[dragon#3956](https://github.com/cardene777/dragon/issues/3956) makes the paper copy hold every tab with the box cards under each figure, and this skill moves to that version once it is released.
Tell the user which tabs the PDF holds.

| Exit code | What to do |
|---|---|
| 0 | Go on |
| 3 | No browser was found. Tell the user the HTML is ready and that a PDF needs Google Chrome, Chromium, Microsoft Edge, or Brave, or the path of one in `MECHANISM_EXPLAINER_BROWSER` |
| 4 | The browser wrote nothing. Run it once more, and report the message when it fails again |

## 7. Look at it and hand it over

Open `<slug>.offline.html` in a browser, at a desktop width and at a phone width, look at the overview, and read every topic through the side menu.
Fix figures that break, cards that do not open, and sections whose answer or figures say little, then run steps 4 to 6 again.

Report to the user:

- The paths of the Markdown, the offline HTML, and the PDF
- The questions the page answers, one line each
- Every line of `check --layout` that was kept, with its step and the parts it names

Keep the Markdown and `glossary.md` next to the page, so the page can be changed and exported again.

## What this skill does not do

- It does not draw figures by hand in HTML or SVG. A figure dragon cannot draw is written in the closest kind and named in the report.
- It does not make slides. A deck for a talk belongs to a slide skill.
- It does not send the page or the material anywhere. dragon and the browser run on the machine.
