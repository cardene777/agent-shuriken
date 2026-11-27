# How Mechanism Explainer works

Mechanism Explainer turns a topic into an explainer that answers the reader's questions in order.
Material of one kind with five or fewer questions is one topic and one page, and six or more questions or more than one kind of material make two or more topics, shown as an overview page and one page per topic, opened from a side menu of three levels instead of tabs at the top.
It writes the page as Markdown in dragon's guide form, has dragon check, draw, and export it, and prints the PDF with a browser already on the machine.
The skill itself holds only the steps, the outline script, and the PDF script; the figure kinds and the page form belong to dragon.
The design rules of the outline page and the source of each are in [outline-design.md](../skills/mechanism-explainer/references/outline-design.md).

## The steps

| Step | What happens | What it runs |
|---|---|---|
| Check the setup | The agent confirms that dragon 0.89.0 runs | `npx -y @cardenelabs/dragon@0.89.0 --version` |
| Plan the outline | The agent writes `outline.json`: the title, the chapters, their pages, and their sections, each with its point in one sentence. It draws the outline as a light page, opens it in your browser, and changes it until you approve it | `scripts/outline.py` |
| Plan the figures | The agent plans the overview figure and one figure per question (two at most) under the `####` headings of the outline, and changes the plan until you agree | Nothing |
| Write | The agent writes `<name>.md` with `layout: guide` and `note: pop`, and a `glossary.md` for terms | Nothing |
| Check the Japanese prose | For a page in Japanese, when japanese-writing is installed, the agent checks the prose against `japanese-writing/rules`, which the skill follows through musubi | `musubi check`, when the `musubi` command is installed |
| Check | Every figure is checked for notation errors and for layout breaks, and each line dragon prints is fixed | `dragon check` and `dragon check --layout` |
| Export | dragon writes the page, then a copy that carries its scripts | `dragon export` and `dragon embed` |
| Print | The page is printed to a PDF on A3 paper by default | `scripts/to-pdf.py` |

## What is in the outline page

| Part | From `outline.json` | How it shows |
|---|---|---|
| Title | `title` and `point` | The heading at the top, with its point under it |
| Overview | `overview` | The parts of the overview page as headings with their points, in a white box |
| Chapter | The `name` and `point` of a chapter | A closed toggle across the whole row, with an icon on the left and the point under the name |
| Page | The `name` and `point` of a page | A heading inside the opened chapter, with its point under it |
| Section | The `name` and `point` of a section | A bold heading with its point under it, on a tinted panel |
| Button | Nothing | One button above the chapters that opens and closes every chapter |

The page has only a light color scheme.
`scripts/outline.py` refuses an outline that breaks the writing rules, and writes no page.

| Refused | Example |
|---|---|
| A name with a question mark, or a name that starts with a number | `How does DNS work?`, `1-1 Resolver` |
| An empty point | `"point": ""` |
| A point written twice | The point of a chapter repeated as the point of one of its pages |
| A line that starts with a bullet | `- the root server` |

## What is in the page

| Part | How it is written | How it shows |
|---|---|---|
| Overview | A `dragon` fence in the page lead, before the first topic | The figure of the whole mechanism at the head of the page, with the topics as the reading route under it. A box with `link: #<topic id>` opens that topic's page |
| Topic | `## <topic>` | A heading in the side menu and in the page. With two or more topics, each topic is its own page, opened from the side menu |
| Question | `### <page name> [menu: <short name>]` | A question numbered per topic in the page, listed in the side menu by its short name without a number, and shown as its own page inside its topic. The side menu lists its headings while it is open |
| Answer | `> <the point of the page>` right under the heading | The answer under the heading |
| Heading | `#### <section name>`, followed by its point | A heading that divides the question's page, listed under the question in the side menu and scrolled to when pressed |
| Figure | One sentence, a `dragon` fence, then two to four sentences, one figure per question and two at most | A figure drawn by dragon that follows the flow or the mechanism, with what to look at before it and what it shows after it |
| Table or code | A Markdown table or a code fence | Lists of values, fields of a record, and commands that need no figure |
| Card | `note:` on a box | A mark on the box, and a card just below it on a click |
| Term | A link into `glossary.md` | An underlined word that opens a card with its meaning |
| Check question | A `<details>` block | A question whose answer opens on a click |

## What runs and where

| What | Where it runs | What it connects to |
|---|---|---|
| dragon | Your machine, through `npx` | The npm registry, once, to fetch the package into npm's cache |
| `scripts/outline.py` | Your machine, with the Python 3 standard library | Nothing |
| `scripts/to-pdf.py` | Your machine, with the Python 3 standard library | Nothing |
| The browser that prints | Your machine, headless, with a throwaway profile that is removed afterwards | Nothing; the page it prints carries its scripts |

The browser is the one in `MECHANISM_EXPLAINER_BROWSER` when it is set, otherwise Playwright's headless shell, otherwise an installed Google Chrome, Chromium, Microsoft Edge, or Brave.
`to-pdf.py` writes a copy of the page with the paper size next to the page, prints the copy, and removes it.

## Where files are kept

`outline.json`, `outline.html`, the Markdown, `glossary.md`, the HTML, the offline HTML, and the PDF are written to `explainer/<name>/` of the folder you work in, or to a folder you name.
The plugin keeps no state and writes nothing outside that folder, except npm's own cache.
