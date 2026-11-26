# How Mechanism Explainer works

Mechanism Explainer turns a topic into an explainer that answers the reader's questions in order.
An explainer with one topic is one page, and an explainer with two or more topics is an overview page and one page per question.
It writes the page as Markdown in dragon's guide form, has dragon check, draw, and export it, and prints the PDF with a browser already on the machine.
The skill itself holds only the steps and the PDF script; the figure kinds and the page form belong to dragon.

## The steps

| Step | What happens | What it runs |
|---|---|---|
| Check the setup | The agent confirms that dragon 0.85.0 runs | `npx -y @cardenelabs/dragon@0.85.0 --version` |
| Plan | The agent writes who reads the page, the questions, and two to four figures per question, and changes the plan until you agree | Nothing |
| Write | The agent writes `<name>.md` with `layout: guide` and `note: pop`, and a `glossary.md` for terms | Nothing |
| Check | Every figure is checked for notation errors and for layout breaks, and each line dragon prints is fixed | `dragon check` and `dragon check --layout` |
| Export | dragon writes the page, then a copy that carries its scripts | `dragon export` and `dragon embed` |
| Print | The page is printed to a PDF on A3 paper by default | `scripts/to-pdf.py` |

## What is in the page

| Part | How it is written | How it shows |
|---|---|---|
| Overview | A `dragon` fence in the page lead, before the first topic | The figure of the whole mechanism at the head of the page, with the topics as the reading route under it |
| Topic | `## <topic>` | A heading in the side menu and in the page. With two or more topics, each question under it is its own page |
| Section | `### <question>? [menu: <short name>]` | A section numbered across topics, listed in the side menu by its short name |
| Answer | `> <one sentence>` right under the question | The answer under the question |
| Figure | One sentence, a `dragon` fence, then two to four sentences | A figure drawn by dragon, with what to look at before it and what it shows after it |
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
