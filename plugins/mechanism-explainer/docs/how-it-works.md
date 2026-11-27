# How Mechanism Explainer works

Mechanism Explainer turns a topic into an explainer that answers the reader's questions in order.
Material of one kind with five or fewer questions is one topic and one page, and six or more questions or more than one kind of material make two or more topics, shown as an overview page and one page per topic, opened from a side menu of three levels instead of tabs at the top.
It writes the page as Markdown in dragon's guide form, has dragon check, draw, and export it, and prints the PDF with a browser already on the machine.
The skill itself holds only the steps and the PDF script; the figure kinds and the page form belong to dragon.

## The steps

| Step | What happens | What it runs |
|---|---|---|
| Check the setup | The agent confirms that dragon 0.89.0 runs | `npx -y @cardenelabs/dragon@0.89.0 --version` |
| Plan | The agent writes who reads the page, the questions, the `####` headings of each question, and one figure per question (two at most), and changes the plan until you agree | Nothing |
| Write | The agent writes `<name>.md` with `layout: guide` and `note: pop`, and a `glossary.md` for terms | Nothing |
| Check the Japanese prose | For a page in Japanese, when japanese-writing is installed, the agent checks the prose against `japanese-writing/rules`, which the skill follows through musubi | `musubi check`, when the `musubi` command is installed |
| Check | Every figure is checked for notation errors and for layout breaks, and each line dragon prints is fixed | `dragon check` and `dragon check --layout` |
| Export | dragon writes the page, then a copy that carries its scripts | `dragon export` and `dragon embed` |
| Print | The page is printed to a PDF on A3 paper by default | `scripts/to-pdf.py` |

## What is in the page

| Part | How it is written | How it shows |
|---|---|---|
| Overview | A `dragon` fence in the page lead, before the first topic | The figure of the whole mechanism at the head of the page, with the topics as the reading route under it. A box with `link: #<topic id>` opens that topic's page |
| Topic | `## <topic>` | A heading in the side menu and in the page. With two or more topics, each topic is its own page, opened from the side menu |
| Section | `### <question>? [menu: <short name>]` | A section numbered per topic in the page, listed in the side menu by its short name without a number, and shown as its own page inside its topic. The side menu lists its headings while it is open |
| Answer | `> <one sentence>` right under the question | The answer under the question |
| Heading | `#### <heading>` | A heading that divides the question's page, listed under the question in the side menu and scrolled to when pressed |
| Figure | One sentence, a `dragon` fence, then two to four sentences, one figure per question and two at most | A figure drawn by dragon that follows the flow or the mechanism, with what to look at before it and what it shows after it |
| Table or code | A Markdown table or a code fence | Lists of values, fields of a record, and commands that need no figure |
| Card | `note:` on a box | A mark on the box, and a card just below it on a click |
| Term | A link into `glossary.md` | An underlined word that opens a card with its meaning |
| Check question | A `<details>` block | A question whose answer opens on a click |

## What runs and where

| What | Where it runs | What it connects to |
|---|---|---|
| dragon | Your machine, through `npx` | The npm registry, once, to fetch the package into npm's cache |
| `scripts/to-pdf.py` | Your machine, with the Python 3 standard library | Nothing |
| The browser that prints | Your machine, headless, with a throwaway profile that is removed afterwards | Nothing; the page it prints carries its scripts |

The browser is the one in `MECHANISM_EXPLAINER_BROWSER` when it is set, otherwise Playwright's headless shell, otherwise an installed Google Chrome, Chromium, Microsoft Edge, or Brave.
`to-pdf.py` writes a copy of the page with the paper size next to the page, prints the copy, and removes it.

## Where files are kept

The Markdown, `glossary.md`, the HTML, the offline HTML, and the PDF are written to `explainer/<name>/` of the folder you work in, or to a folder you name.
The plugin keeps no state and writes nothing outside that folder, except npm's own cache.
