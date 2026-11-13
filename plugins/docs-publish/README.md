# Docs Publish

Write the public documentation of an open source project in five parts, in English and a second language you pick, with every translation and every link checked.

English · [日本語](README.ja.md)

Good documentation for an open source project has a quick start, an explanation of its ideas, a reference, worked tasks, and answers to common questions, and readers of another language need the same pages in their language.
Kept by hand, two languages drift apart: a page is added in one and not the other, a translation falls behind its source, and links break when files move.
This plugin has your agent write the pages from your project's own code and examples, in five parts, in English and a second language such as Japanese, with one file per page in each language.
A script lays out the folders, keeps a translation map, and checks every page and link, so the two languages stay in step.

```
Read the project ──> Agree on the plan ──> Lay out and write ──> Translate ──> Check every page
 (agent)              (you approve)         (script, agent)       (agent)       (script)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install docs-publish@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add docs-publish@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install docs-publish@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/docs-publish/skills/docs-publish   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for documentation, for example "write the docs for this library in English and Japanese" or "translate our docs into Japanese and keep them in step".
You can also call it: run `/docs-publish:docs-publish` in Claude Code, or type `$` and pick **Docs Publish** in Codex.
In GitHub Copilot CLI, write `/docs-publish` in your request, and in Gemini CLI, describe the task.

1. The agent reads your project: the README, the package manifest, the public API, the examples, the tests, and any existing docs
2. The agent proposes the second language, the docs folder, and the pages: three to five concepts, one API page per function, class, or command, and one Cookbook page per task. You confirm or change them
3. The script lays out the folders and starter pages, and the agent writes each page in the source language, usually English
4. The agent translates every page into the second language, and the script records each translation
5. The script checks every page and link, and the agent fixes what it reports until nothing is left
6. With your agreement, the agent links the docs from your README. Nothing is committed, so you review the new files first

While work is left, the check looks like this.

```text
docs: 11 pages in en, ja, translated from en

stale        en/concepts/checkout.md changed after ja/concepts/checkout.md was translated from it
link         ja/cookbook/apply-a-coupon.md:43: ../api/applycoupon.md differs in letter case from the file on disk, so it breaks on GitHub and most web servers
crosslink    ja/faq.md:15: ../en/quickstart.md points into en/; link the page in ja/ instead
orphan       ja/faq.md cannot be reached by following links from ja/README.md

4 problems. Links: 85 checked, 1 broken.
```

When the docs are ready, it looks like this.

```text
docs: 11 pages in en, ja, translated from en
No problems. Links: 86 checked, 0 broken.
```

## The layout

Each language has its own folder with the same pages at the same paths, so a page and its translation are always easy to find.

```text
docs/
├── _translation-map.json
├── en/
│   ├── README.md                 the index: what the project is, and the five parts
│   ├── quickstart.md             from nothing to a first working result
│   ├── concepts/                 README.md, then one page per idea, each with a diagram
│   ├── api/                      README.md, then one page per function, class, or command
│   ├── cookbook/                 README.md, then one page per task
│   └── faq.md                    common questions and errors
└── ja/                           the same pages, translated
```

Every page has a line under its title that links the same page in the other language.
`_translation-map.json` lists the languages, source first, and the pages.
For each translation it keeps the sha256 of the source page as it was when the translation was recorded, so the check notices when a source page changes later.

A finished Cookbook page looks like this, here `docs/en/cookbook/apply-a-coupon.md` for a made-up library called Acme Shop.
Its translation at `docs/ja/cookbook/apply-a-coupon.md` has the same headings, lists, and code blocks.

````markdown
# Apply a coupon

English · [日本語](../../ja/cookbook/apply-a-coupon.md)

Take a coupon code at checkout and lower the cart total before the customer pays.
The discount stays on the cart until the order is placed.

## Before you start

- Acme Shop installed, as in the [Quickstart](../quickstart.md)
- A cart made with [`createCart`](../api/createCart.md)

## Steps

1. Apply the code to the cart.

   ```ts
   import { applyCoupon } from "acme-shop";

   const result = await applyCoupon(cart, "SPRING10");
   ```

2. Tell the customer when the code cannot be used.

   ```ts
   if (!result.ok) {
     showError(result.reason); // "expired", "unknown", or "minimum-not-met"
   }
   ```

## Check the result

```ts
console.log(cart.total, cart.discounts);
```

```text
4500 [ { code: 'SPRING10', amount: 500 } ]
```

## Related

- [`applyCoupon`](../api/applyCoupon.md)
- [`createCart`](../api/createCart.md)
- [Cookbook](README.md)
````

## The checks

| Check | What it catches |
|---|---|
| Counterparts | A page that is missing in one language, or a page file that is not in the map |
| To-do notes | A section of a starter page that has not been written |
| Content | A concept page without a Mermaid diagram, or a Quickstart, API, or Cookbook page without a code example |
| Structure | A translation whose headings, code blocks, or table rows differ from its source |
| Freshness | A translation that was never recorded, or whose source page changed after it was recorded |
| Links | A relative link or image that points at nothing, or whose letter case differs from the file, resolved from the page's own folder. Code is not read for links |
| Language | A link into the other language's folder other than the language switch, or a page without a link to its counterpart |
| Reach | A page that cannot be reached by following links from its language's index |

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always, version 3.9 or later |
| `gh` | Only to read your project's issues for FAQ material, signed in to GitHub, and only when you agree. Everything else works without it |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the plan, the map, every check, and the script's commands.
In short:

- The agent reads your project's files, such as the README, the source code, the examples, and existing docs, to write the pages, and the script reads only the docs folder
- It writes only inside the docs folder, and adds links to your README only when you agree. It never overwrites, moves, or deletes a file
- It runs its own Python script, and runs your Quickstart and Cookbook commands to show their real output when they need nothing new installed. It asks before installing anything
- With your agreement, it runs `gh issue list` and `gh issue view` on your project, which sends the repository's name to GitHub through your own `gh` sign-in
- It keeps nothing outside your project. The pages and the translation map stay in your docs folder until you delete them

## License

[MIT](LICENSE)
