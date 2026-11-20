# How Diagram Explainer works

English · [日本語](how-it-works.ja.md)

This page lists the steps the agent follows, what goes in the document, what is checked before you see it, and where files are kept.
The procedure is in `skills/diagram-explainer/SKILL.md`, and the pages it points to are in `skills/diagram-explainer/references/`.

## The steps

| Step | Who | What happens |
|---|---|---|
| Research | Agent | For a standard, an API, or a protocol, reads the official specification and records the version and the date. For your own system, reads the code and documents you point to |
| Outline | Agent | Lists what the reader needs to know and plans the pages, the sections, and a figure for every section |
| Agree on the outline | You | Change the sections or the figures until the outline fits |
| Write | Agent | Writes the content as JSON: pages, sections, text, figures, charts, and tables |
| Build | Agent | Turns the JSON into one HTML file with the scripts in the plugin |
| Check | Agent | Runs the document check, fixes everything it reports in the JSON, and builds again |
| Reread | Agent | Rereads the text for numbers, units, and whether each figure shows what the text says, and looks at every section at a desktop width and a phone width |
| Revise | You and the agent | You ask for changes, and the agent edits the JSON and rebuilds the document |

## What is in the document

| Part | Contents |
|---|---|
| Contents list | The sections of the current page. Picking one shows that section alone |
| Header | Shown when there are two or more topics: the title, one tab per page, the date, and the PDF button |
| Sections | Text, a figure, and any of these: key numbers, cards to compare, notes and warnings, a before-and-after comparison, tables, code, and collapsed details |
| Phone layout | A bar with the current section and a button that slides the contents list in |
| Print layout | Every section in order, one per sheet, with the header and contents hidden. The PDF button prints the current page or all pages |

Every figure is drawn inside the page:

| Figure | Good for |
|---|---|
| Boxes and arrows in HTML | Parts and how they connect, flows, layers, who owns what |
| Time band | Opening hours and the times things happen, row by row |
| Capped bar | An amount against a limit, before and after trimming |
| Bar chart | Comparing two or more numbers |
| Period chart | Periods on a year axis |
| Step ladder | Steps that each carry several items, such as what is called, the check, and who acts |

The buttons and labels of the document follow its language, English or Japanese.

## What is checked before you see it

`scripts/check.py` fails the document until all of these hold:

- Nothing is loaded from the network: no script, stylesheet, web font, or image from a URL
- Every section has a figure, or states why it has none
- The contents list, the section headings, the header tabs, and the pages agree
- Every figure has a caption, and figure numbers on a page have no gaps or repeats
- Every table row has as many cells as the header
- No collapsed block ships open, and nothing but one lead sentence sits between a title and its first section
- Ids are unique and every reference inside figures resolves
- Words from the term tables appear neither in the text nor in the figures
- With a browser, at several screen widths: the page height does not move while the page loads, and nothing overflows sideways

For a Japanese document, the text is also checked against bundled word lists: wordy phrases, words readers may not know, progress notes left in the text, spelling variants, commas in headings, and identifiers used as the subject of a figurative verb.
Paragraph and sentence lengths, repeated sentences, and names that appear only in figures are counted, not failed.

## Where files are kept

Each document has its own folder, `docs/explainers/<name>/` in the project you are working in, or a folder you name.
It holds `content.json` (the source), step ladder definitions if any, the term table if any, and the finished `<name>.html`.
A PDF, when you ask for one, is written next to the HTML file.
Nothing is kept anywhere else, and temporary files from checking are removed when the check ends.

## What it runs and connects to

- The code and documents you point to, and for public topics your agent's web search and web page reading, with only the names of the topic, standards, products, and vendors in searches
- `python3` to build and check the document
- A Chromium-based browser already on your computer (Chrome, Chromium, Edge, Brave, or Playwright's headless shell), in headless mode with a throwaway profile that is removed afterwards, to measure the layout and to print the PDF. Set `DIAGRAM_EXPLAINER_BROWSER` to choose one

The plugin installs nothing, and the document it writes loads nothing from the network.
