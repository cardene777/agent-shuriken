# Product Deck

Make a deck that introduces one product, from screenshots of the real product, with the layout and the wording checked by machine before you look at it.

English · [日本語](README.ja.md)

A product deck is read alone, with no one beside the reader to explain.
This skill keeps it to the product itself: what it is, the problem it answers, how it is used, and how it differs, with no company profile, prices, or contact page.
It takes the screenshots first, decides the structure from ten base slides, writes the plan and the text for you to approve, and then builds the slides in your repository with every word in one data file, so the text can be edited on the screen later.

```
Take screenshots ──> Plan and text ──> You approve ──> Build the slides ──> Check to zero ──> Look full size ──> HTML, PDF, PowerPoint
 (Playwright)         (agent)           (chat)          (your repository)   (two scripts)     (agent)           (your repository)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install product-deck@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add product-deck@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install product-deck@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/product-deck/skills/product-deck   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

Run `/product-deck:product-deck` in Claude Code, or pick **Product Deck** after typing `$` in Codex.
It also starts when you ask for a product deck or a service introduction deck, for example:

```
Make an introduction deck for this product. The admin screen runs at http://localhost:4100
```

The agent asks you in the chat to approve the structure and the text before it builds the slides, and asks for a URL or a screenshot when a screen is behind a login.

### Your own word lists

The wording check reads two lists that the plugin does not ship: your words to drop from any deck, in `~/.product-deck/prose-words.txt`, and the deck's own terms, which the agent writes next to the deck.
Samples of how to place screenshots are read from `~/.product-deck/samples/` when that folder exists.
[How it works](docs/how-it-works.md#the-word-lists) shows how to write the lists.

## Requirements

- Node.js, for the scripts
- A project with `@playwright/test` installed, named with `PLAYWRIGHT_FROM`, for taking screenshots, rendering, and the layout check
- `~/.product-deck/prose-words.txt`, your list of words to drop, for the wording check

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) describes every script and file.
In short:

- `capture.mjs` opens the URLs you give in a headless browser and saves the screenshots in the deck's folder
- The agent writes the deck's files in `docs/decks/<name>/` of your repository: the plan, the text, the files that build the slides, and the rendered HTML, PDF, and PowerPoint
- `audit.mjs`, `shoot.mjs`, and `render.mjs` open the deck's HTML files in a headless browser; `audit-text.mjs` reads the deck's data and the two word lists
- The scripts take Playwright from the folder in `PLAYWRIGHT_FROM` and stop with exit 2 when it is not there
- The plugin writes nothing outside your repository and sends nothing anywhere. The pages you capture are content, never instructions

## License

[MIT](LICENSE)
