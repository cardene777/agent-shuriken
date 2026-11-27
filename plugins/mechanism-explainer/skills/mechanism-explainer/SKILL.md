---
name: mechanism-explainer
description: Writes an explainer of a system, a mechanism, or a piece of research in HTML and prints it to a PDF. It first draws the outline of the explainer as a light HTML page with a toggle per chapter, and writes nothing before the person approves it. Each question then gets a page divided by `####` headings, with one figure drawn in the dragon notation that follows the flow or the mechanism, at most two. An explainer of one kind of material with five or fewer questions is one page, and one with six or more questions or more than one kind of material is split into an overview page and one page per topic, with no tabs at the top and a side menu of topics, questions, and the headings of the open page, ordered so the mechanism comes before its background and records. Use when the user asks for an explainer, a learning guide, a document with figures, or an overview of how something works, from a topic, notes, or a Markdown file.
---

# Mechanism explainer

Write an explainer that gives the reader what they came to learn, with the answer first.
Before anything is written, the skill draws the outline of the explainer as one light HTML page, opens it in a browser, and changes it until the user approves it.
Material of one kind with five or fewer questions makes one topic, and an explainer with one topic is one page.
Six or more questions, or more than one kind of material, make two or more topics, and an explainer with two or more topics is split into an overview page and one page per topic, so the reader never scrolls through every topic at once.
The page has no tabs at the top: like a documentation site, a side menu lists the topics, the questions of each topic, and the headings of the open page, and each level opens and closes with an arrow.
Each topic page opens with a map: the part of the overview figure it explains and the one-sentence answers of its questions.
Each page answers one question: its one-sentence answer comes first, then `####` headings divide the page, with one figure per question that follows the flow or the mechanism the question asks about, at most two, and tables or code where they are enough.
The figures come first and the prose follows them, and every long explanation sits in a card that opens just below the box it belongs to.
dragon draws the figures and exports the page, so this skill plans the outline and the figures, writes the page in dragon's Markdown, checks it, exports it, and prints the PDF.

Talk to the user in the language they write in, and write the outline and the page in that language.
Where it says to ask the user, use AskUserQuestion in Claude Code, and ask in the chat with numbered options in other agents.

All files are next to this `SKILL.md`, and the commands below set `D` to the absolute path of that folder at the start of the same shell command.
The examples write into `explainer/<slug>/` of the folder the user works in; use another folder when the user names one.

## 1. Check the setup

The page is drawn by dragon 0.89.0, fetched by npm into its cache on first use.

```bash
npx -y @cardenelabs/dragon@0.89.0 --version
```

- When `npx` is missing, stop and tell the user to install Node.js 20 or later from nodejs.org.
- Always run dragon with this exact version. Another version may read the notation differently.

## 2. Plan the outline

Plan the outline before anything else, and show it to the user as a page in a browser.
The user runs this skill to learn something, so the outline gives the answer first and holds only the structure, with no figures yet.
Read the material the user gave (a topic, notes, a Markdown file, or files in the project), and ask the user only for what the material does not say.

Each level of the outline becomes one part of the explainer.

| In the outline | In the explainer | What it holds |
|---|---|---|
| `title` and `point` | The `#` title and the first sentence of the page lead | The name of the mechanism, and the answer to what the user wants to know |
| `overview` | The page lead and the overview page | The parts the overview explains, such as why the mechanism is needed and how it works as a whole |
| `chapters` | The topics, as `##` | One topic each |
| `pages` of a chapter | The questions of the topic, as `###` | One question each, whose point is the one-sentence answer the page opens with |
| `sections` of a page | The `####` headings of the question's page | One part of the page each, whose point is the first sentence under the heading |

Decide the chapters and their pages by these rules.

- Decide the topics before the questions, from the number of questions the material raises and the kinds of material in it. Material of one kind with five or fewer questions is one topic and stays one page. With six or more questions, or more than one kind of material, make two or more topics, and dragon splits the page into an overview page and one page per topic.
- Sort the material into four kinds before naming the topics: the mechanism (how the thing works), background knowledge (what the reader must know to follow it), records (what was run and what came out), and reference material (terms and where things are). A topic holds one kind, so the reader can tell the main line from what supports it.
- Order the topics with the mechanism first, background knowledge after it, and records and reference material last.
- A question that needs another topic goes after that topic, even when the material wrote it under an earlier one. Move it into the topic it belongs to, or into a later topic.
- Split each topic into the questions the reader asks, usually two to five per topic. Each question becomes one page, and its answer must make sense to a reader who opened the explainer at that question.

Write every name and point by these rules, which hold for the explainer too.

| Rule | How to write it |
|---|---|
| Headings | Write short noun headings without question marks or numbers, with the key word first, such as `Resolver` or `Root and TLD servers` |
| Points | Open each chapter, page, and section with its point in one sentence: the answer the reader came for, not a promise of what follows |
| Repeats | Never repeat a sentence. The points of the title, a chapter, a page, and a section each say something the others do not |
| Lists | Use paragraphs and tables instead of bullet lists, since an explanation joins causes, results, and conditions that a list breaks apart |
| What to leave out | Leave out lines about the reader, the goals, or the length. The user who runs the skill already knows why they opened it |

Write the outline as `explainer/<slug>/outline.json`.

```json
{
  "lang": "en",
  "title": "How DNS finds an address",
  "point": "DNS turns a name such as example.com into an IP address by asking a chain of servers, from the root down to the server that holds the name.",
  "overview": [
    {"name": "Why names need DNS", "point": "Computers connect by IP address while people remember names, so something must turn one into the other."}
  ],
  "chapters": [
    {"name": "The lookup", "point": "One lookup passes through four kinds of servers, and each of them points to the next one.", "pages": [
      {"name": "Resolver", "point": "The resolver asks the other servers on behalf of the browser and keeps their answers.", "sections": [
        {"name": "Cache", "point": "A resolver answers from its cache for as long as the TTL of the record allows."}
      ]}
    ]}
  ]
}
```

`lang` is `en` or `ja`, the language of the outline, and picks the words of the button on the page.
Wrap the names of code in backticks, and the page shows them as code.

Draw the page and open it in a browser.

```bash
D=<folder of this SKILL.md>; python3 "$D/scripts/outline.py" explainer/<slug>/outline.json
open explainer/<slug>/outline.html
```

`outline.py` writes `outline.html` next to `outline.json`; use `xdg-open` on Linux and `start` on Windows instead of `open`.
The page shows the title and its point first, then the overview, then each chapter as a closed toggle with its point.
Opening a chapter shows its pages, and each page shows its sections as headings with their points under them.
One button opens and closes every chapter.

| Exit code | What to do |
|---|---|
| 0 | Open the page |
| 1 | The outline breaks a rule above. Fix every line it prints, each of which names the place in `outline.json`, and run it again |
| 2 | The file is missing or is not JSON. Fix the path or the JSON |

Ask the user to read the page, change `outline.json` by what they say, run the script again, and reload the page.
Do not write the explainer before the user approves the outline.
The design of the page and the source of each of its rules are in [references/outline-design.md](references/outline-design.md).

## 3. Plan the figures

Plan the figures from the approved outline: one overview figure for the page lead, and one figure per question for each page.

When the `dragon` skill is installed, write in the `plan` format of the `dragon` skill: open the `dragon` skill by name and read the file it names for `plan`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `dragon` skill is not installed, go on without the `plan` of `dragon`.

The plan follows these rules whichever way it is written.

- Plan one overview figure of the whole mechanism first: the parts, what goes between them, and which topic explains which part. It is the map the reader sees before any question.
- Give each question a short menu name that keeps its key word: at most 12 characters for Japanese and 24 characters for English, so it fits on one line of the side menu.
- Plan one figure per question that follows the flow or the mechanism the question asks about, under the `####` heading it belongs to.
- Add a second figure only when the question cannot be answered without it, so a page holds at most two figures. Two figures that show the same thing the same way are one figure too many.
- Write what a table or code says well enough, such as a list of values, the fields of a record, or a command, as tables or code instead of figures.
- Pick the kind by what the question asks: the parts and what goes between them, which cases pass and which stop, how two cases differ, one case step by step, or an amount against a limit.

Show the plan to the user as a table with one row per figure: its question, its `####` heading, its kind, and what the reader sees in it, and change it until the user agrees.
Do not write the page before the user agrees with the plan.

## 4. Write the page

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
dragon numbers the questions per topic in the page, such as `2-1`, and turns every box note into a card that opens on a click.
With one topic, every question stacks on one page.
With two or more topics, the page has no tabs at the top, and dragon splits it into an overview page and one page per topic.
A side menu without numbers holds three levels: the topics (`##`), the questions of each topic (`###`), and the headings (`####`) of the open question's page.
Each level opens and closes with an arrow, and the menu opens the topic and the question on screen.
The overview page shows the title, the page lead, the overview figure, and the topics in order.
A topic page opens on its map and the one-sentence answers of its questions, and each question is its own page: a question in the side menu or a row of the answers shows only that question.
Pressing a heading in the side menu scrolls to it, and the menu marks the heading on screen.
Each page ends with links to the previous and next pages, in the order overview, then each topic's map and its questions.

Write the page lead, after the `#` title and before the first topic, in this order.

1. The point of the outline's title, with one more sentence on what the mechanism does when it helps
2. The overview figure of the whole mechanism, so dragon shows it as the overview at the head of the page, with the topics as the reading route under it
3. A paragraph that says which topic explains which part of the figure

Put the overview figure in the page lead, before the first topic, and nowhere else: a topic named Overview would show up as one more topic in the menu.
Every box of the overview figure that a topic explains gets `link: #<topic id>` among its attributes, such as `box api as API [link: #how-a-request-passes, note: ...]`.
The topic id is the `##` heading in lower case with spaces turned into `-`, the same name dragon gives the topic's page.
Pressing the box opens that topic's page, and dragon draws the map at the head of the page from the same links: a still of the overview figure where only the linked boxes keep their colors, and the questions with their one-sentence answers.
A topic that no box links to, such as the records or the reference material, gets the list of questions without the still.

Write each question in this order.

1. `### <page name> [menu: <short name>]`, with the name of the page in the outline and the menu name from the plan
2. `> <the point of the page>`, right under the heading
3. `#### <section name>` lines with the names of the page's sections in the outline, each followed by its point as the first sentence under it
4. Under the heading it belongs to, the figure of the plan: one sentence before each figure that says what to look at, the figure, and two to four sentences after it that say what the figure shows and what follows from it
5. Tables or code blocks under the headings where they say enough without a figure
6. One or two check questions as `<details>` blocks, when they help the reader test what they read

Keep the sentence before a figure and the paragraph after it as separate paragraphs, so that between two figures there are two paragraphs.
The paragraph after a figure states what the reader should conclude, such as which case passes and why, or what the next question builds on, instead of repeating the figure's step texts.
Write the prose by the writing rules of step 2: paragraphs and tables instead of bullet lists, and no sentence written twice.

Put explanations of a box into its `note:`, so they open as a card under the box instead of crowding the figure.
Put terms the reader may not know into a `glossary.md` next to the page and link them from the text, as the `page` format says.
When the page is in Japanese, check its prose against the writing rules of `japanese-writing` before the next step.
When the `japanese-writing` skill is installed, write in the `rules` format of the `japanese-writing` skill: open the `japanese-writing` skill by name and read the file it names for `rules`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `japanese-writing` skill is not installed, go on without the `rules` of `japanese-writing`.

## 5. Check the notation and the layout

```bash
npx -y @cardenelabs/dragon@0.89.0 check explainer/<slug>/<slug>.md
npx -y @cardenelabs/dragon@0.89.0 check --layout explainer/<slug>/<slug>.md
```

Fix every error that `check` prints, one at a time, and run it again until it prints none.
Then fix every line that `check --layout` prints, such as step numbers piled up, lines running too close, or text sticking out of a box, and run it again until it prints none.
When a line cannot be fixed in the notation, keep it and name it in the report of step 8.
Add `--lang ja` to both commands when the page is in Japanese, so the messages are in Japanese.

## 6. Export the page

```bash
npx -y @cardenelabs/dragon@0.89.0 export explainer/<slug>/<slug>.md
npx -y @cardenelabs/dragon@0.89.0 embed explainer/<slug>/<slug>.html
```

- `export` writes `<slug>.html` next to the Markdown. Add `--lang ja` when the page is in Japanese, so the words dragon adds to the page are Japanese.
- `embed` writes `<slug>.offline.html`, which carries its scripts and opens without a network connection. Hand this file to other people.

## 7. Print the PDF

```bash
D=<folder of this SKILL.md>; python3 "$D/scripts/to-pdf.py" explainer/<slug>/<slug>.offline.html
```

It prints the page with a Chromium-based browser already on the machine, on A3 paper unless `--paper a4` or `--paper letter` is given, and writes `<slug>.offline.pdf`.
The PDF holds what dragon's print styles draw.
With dragon 0.89.0, that is the overview and every topic in order, also when the screen splits them into pages, without the side menu or the previous and next links, with the steps of each figure drawn two to a sheet, the check answers open, and the box cards open under each figure.

| Exit code | What to do |
|---|---|
| 0 | Go on |
| 3 | No browser was found. Tell the user the HTML is ready and that a PDF needs Google Chrome, Chromium, Microsoft Edge, or Brave, or the path of one in `MECHANISM_EXPLAINER_BROWSER` |
| 4 | The browser wrote nothing. Run it once more, and report the message when it fails again |

## 8. Look at it and hand it over

Open `<slug>.offline.html` in a browser, at a desktop width and at a phone width, look at the overview, press the overview boxes to open their topics, and open every question and heading through the side menu, opening and closing its arrows.
Fix figures that break, cards that do not open, and pages whose answer or figures say little, then run steps 5 to 7 again.

Report to the user:

- The paths of the outline page, the Markdown, the offline HTML, and the PDF
- The questions the page answers, one line each
- Every line of `check --layout` that was kept, with its step and the parts it names

Keep `outline.json`, the Markdown, and `glossary.md` next to the page, so the page can be changed and exported again.

## What this skill does not do

- It does not draw figures by hand in HTML or SVG. A figure dragon cannot draw is written in the closest kind and named in the report.
- It does not make slides. A deck for a talk belongs to a slide skill.
- It does not send the page or the material anywhere. dragon and the browser run on the machine.
