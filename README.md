<div align="center">

<img src="assets/icon.svg" width="96" alt="agent-shuriken icon">

# agent-shuriken

**One folder of skills, rules, and hooks for every coding agent, and careful plugins to add.**

`agent-shared` puts the skills, rules, and hooks you keep in `~/.shared` into Claude Code, Codex, and the other agents that read `SKILL.md`, so every agent reads the same files.
Each plugin hands a tedious chore to your agent and keeps you in charge of every irreversible step.
The same plugin installs in Claude Code, Codex, and GitHub Copilot CLI, and its skill works in Gemini CLI and other agents that read `SKILL.md`.

English · [日本語](README.ja.md)

[agent-shared](#agent-shared) ·
[Plugins](#plugins) ·
[Install](#install) ·
[Docs](#docs) ·
[Releases](https://github.com/cardene777/agent-shuriken/releases) ·
[Changelog](CHANGELOG.md)

</div>

## agent-shared

Keep your own skills, rules, and hooks in one folder, and `agent-shared` places them in every agent.
Install the command with [uv](https://docs.astral.sh/uv/), then deploy.

```
uv tool install "git+https://github.com/cardene777/agent-shuriken#subdirectory=agent-shared"
agent-shared deploy
```

The folder `~/.shared` has the same layout for every agent.

```
~/.shared/
  skills/<name>/SKILL.md   one folder per skill
  rules/*.md               instructions every agent reads
  hooks.json               hooks, written like the hooks in Claude Code's settings
  agents.json              optional rows that add an agent or move where one keeps its files
```

| Agent | Skills | Rules | Hooks |
|---|---|---|---|
| Claude Code | `~/.claude/skills` | `~/.claude/rules` | `~/.claude/settings.json` |
| Codex | `~/.agents/skills` | one block in `~/.codex/AGENTS.md` | `~/.codex/hooks.json`, with Codex's trust written for them |

GitHub Copilot CLI and Gemini CLI read the skills in `~/.agents/skills` too.
Skills and rules are links to the one copy in `~/.shared`, so an edit reaches every agent at once.
A repository can keep its own skills in `.shared/skills`, and running `agent-shared deploy` inside it links them into the repository's `.claude/skills` and `.agents/skills`.
Running the command again places what is new and removes only what it placed before, and it never sends anything over the network.
`agent-shared hooks --agent <name>` prints the hooks `deploy` places for one agent and writes nothing, so a guard can compare an agent's hook file with it.
`agent-shared placed --source <folder>` prints, as JSON, the skills, rules, and hooks one folder placed in each agent and writes nothing, so an app can list what it deployed.
`agent-shared off --source <folder> --agent <name> <item>` leaves one rule or hook out of one agent at every later deploy, and `agent-shared on` with the same arguments places it again; the choice is kept in `off.json` beside the record, never in the source folder.
[agent-shared](docs/agent-shared.md) explains every place it writes and every refusal.

## Plugins

| Plugin | What it does | How to run it | Latest |
|---|---|---|---|
| [account-cleanup](plugins/account-cleanup) | Finds web accounts you no longer use without reading any passwords, then cancels subscriptions and deletes the accounts you approve | `/account-cleanup:account-cleanup` in Claude Code, or **Account Cleanup** after typing `$` in Codex. It also starts when you describe the task | [0.3.0](plugins/account-cleanup/CHANGELOG.md) |
| [chainome-diagram](plugins/chainome-diagram) | Designs and reviews animated React and SVG diagrams that explain blockchain mechanics, with one active phase, state changes shown where they happen, and the prose kept apart from the diagram | `/chainome-diagram:chainome-diagram` in Claude Code, or **Chainome Diagram** after typing `$` in Codex. It also starts when you ask for an animated blockchain diagram | [0.1.0](plugins/chainome-diagram/CHANGELOG.md) |
| [compare-report](plugins/compare-report) | Researches the candidates for a choice and writes an HTML and PDF comparison report, with a source for every claim and a rationale for every score | `/compare-report:compare-report` in Claude Code, or **Compare Report** after typing `$` in Codex. It also starts when you ask for a comparison | [0.5.0](plugins/compare-report/CHANGELOG.md) |
| [convey](plugins/convey) | Writes a message that tells people what they need, with the conclusion first and nothing the reader does not need, and checks its length, formatting, and private details for Slack, Discord, an email, or a GitHub comment before copying it | `/convey:convey` in Claude Code, or **Convey** after typing `$` in Codex. It also starts when you ask to share, report, or announce something in a message | [0.2.0](plugins/convey/CHANGELOG.md) |
| [design-formats](plugins/design-formats) | Holds how documents and reports explain and look: the order of an explanation, the look rules, four pattern files with sourced rules, four HTML page templates, and a script that names each heading with a colon, facts outside a table, and missing language or theme switch | `/design-formats:page-design` in Claude Code, or **Page Design** after typing `$` in Codex. Skills that write pages open it by name | [0.1.0](plugins/design-formats/CHANGELOG.md) |
| [diagram-composer](plugins/diagram-composer) | Designs the diagram area of a slide with one visual metaphor, a meaning for every connector, and labels kept off the lines, checked by a script before the slide is rendered | `/diagram-composer:diagram-composer` in Claude Code, or **Diagram Composer** after typing `$` in Codex. It also starts when you ask for a diagram on a slide | [0.1.0](plugins/diagram-composer/CHANGELOG.md) |
| [diagram-explainer](plugins/diagram-explainer) | Writes an explainer with a figure drawn in every section as one HTML file, built from JSON and checked before you share it | `/diagram-explainer:diagram-explainer` in Claude Code, or **Diagram Explainer** after typing `$` in Codex. It also starts when you ask for an explainer | [0.2.2](plugins/diagram-explainer/CHANGELOG.md) |
| [diagram-styles](plugins/diagram-styles) | Makes figures for articles and technical books: designs each figure from the reader's question, then draws it with the agent's image generation in one of thirty-two built-in styles or a style from your own catalog in `~/.styles/`, and checks the text and connections | `/diagram-styles:article-diagram-styles` and `/diagram-styles:tech-book-figure` in Claude Code, or **Article Diagram Styles** and **Tech Book Figure** after typing `$` in Codex. A skill that writes an article opens it by name | [0.3.0](plugins/diagram-styles/CHANGELOG.md) |
| [digital-dashboard](plugins/digital-dashboard) | Judges which screens of a design are dashboards, downloads the official files of the Japanese Digital Agency's dashboard design guidebook with their fingerprints checked, and writes the request that applies them to those screens only | `/digital-dashboard:digital-dashboard` in Claude Code, or **Digital Dashboard** after typing `$` in Codex. It also starts when you ask for a dashboard | [0.1.1](plugins/digital-dashboard/CHANGELOG.md) |
| [doc-formats](plugins/doc-formats) | Holds the document formats other skills follow: the format of a design document and a script that checks every section is filled in, which the design skills of evm-dev use | `/doc-formats:design-doc` in Claude Code, or **Design Doc** after typing `$` in Codex. The design skills of evm-dev open it by name | [0.1.0](plugins/doc-formats/CHANGELOG.md) |
| [docs-publish](plugins/docs-publish) | Writes the docs of a library, command-line tool, or web service you build, public or private, in five parts, Quickstart, Concepts, API reference, Cookbook, and FAQ, in English and a second language you pick, and checks that every page has its translation and every link resolves | `/docs-publish:docs-publish` in Claude Code, or **Docs Publish** after typing `$` in Codex. It also starts when you ask for documentation for your project | [0.4.0](plugins/docs-publish/CHANGELOG.md) |
| [evm-dev](plugins/evm-dev) | Tells whether an ERC is final or an EIP is live on Ethereum mainnet, how L2 networks, the Ethereum L1 roadmap, and consensus-only EIPs stand, writes Solidity contracts and their tests for the solc, OpenZeppelin, Foundry, and Hardhat versions a project uses, deploys them without the agent touching keys and records what was deployed, checks a release against the deployed version and the target chains, and designs contracts, wallets, multichain apps, dApp architectures, and apps built on financial standards such as ISO 20022 and FIX, from dated items checked against the official documents | `/evm-dev:evm-standards`, `/evm-dev:ethereum-knowledge`, `/evm-dev:solidity-code`, `/evm-dev:contract-tests`, `/evm-dev:contract-deploy`, `/evm-dev:release-check`, `/evm-dev:contract-design`, `/evm-dev:wallet-design`, `/evm-dev:multichain-design`, `/evm-dev:dapp-architecture`, and `/evm-dev:financial-standards` in Claude Code, or **EVM Standards**, **Ethereum Knowledge**, **Solidity Code**, **Contract Tests**, **Contract Deploy**, **Release Check**, **Contract Design**, **Wallet Design**, **Multichain Design**, **dApp Architecture**, and **Financial Standards** after typing `$` in Codex. They also start when you ask about the status of an ERC or EIP, an L2, or the Ethereum L1 roadmap, ask for a contract or its tests to be written, ask for contracts to be deployed, ask whether a release is safe, or ask for the design of contracts, wallets, an app across chains, a dApp's architecture or a design built on a financial standard | [0.7.0](plugins/evm-dev/CHANGELOG.md) |
| [excalidraw-diagram](plugins/excalidraw-diagram) | Draws architecture, flow, sequence, and entity-relationship diagrams as Excalidraw files laid out by a script and checked for overlaps, crowded spacing, and labels on lines, with SVG and PNG copies | `/excalidraw-diagram:excalidraw-diagram` in Claude Code, or **Excalidraw Diagram** after typing `$` in Codex. It also starts when you ask for a diagram | [0.3.0](plugins/excalidraw-diagram/CHANGELOG.md) |
| [feedback-loop](plugins/feedback-loop) | When you correct the agent's work, records the correction, fixes the files, has an evaluator that edits nothing review the fix until every criterion passes, and keeps the lesson as a check or a rule | `/feedback-loop:feedback-loop` in Claude Code, or **Feedback Loop** after typing `$` in Codex. It also starts when you correct earlier output | [0.1.2](plugins/feedback-loop/CHANGELOG.md) |
| [init-project](plugins/init-project) | Sets up a project for local work: picks a free local port, writes a Docker setup, and links env files to 1Password with references, showing every file before it is written | `/init-project:init-project` in Claude Code, or **Init Project** after typing `$` in Codex. It also starts when you ask to set up a project | [0.3.0](plugins/init-project/CHANGELOG.md) |
| [japanese-speaking](plugins/japanese-speaking) | Writes Japanese that sounds like people talking, not reading lines, for podcast and radio dialogue, a news item one host reads and both discuss, interviews, narration, and talk scripts, with a script that points at lines that sound read from paper and a fresh reader that listens for the rest | `/japanese-speaking:japanese-speaking` in Claude Code, or **Japanese Speaking** after typing `$` in Codex. It also starts when you ask for a script, dialogue, or narration in Japanese | [0.1.0](plugins/japanese-speaking/CHANGELOG.md) |
| [japanese-writing](plugins/japanese-writing) | Writes and fixes Japanese text so that it reads naturally and adds nothing the original does not say, with scripts that point at translationese, AI-like phrasing, and metaphor verbs, and rules for Markdown kept in a repository | `/japanese-writing:japanese-writing` in Claude Code, or **Japanese Writing** after typing `$` in Codex. It also starts when you ask to write Japanese or make it natural | [0.2.0](plugins/japanese-writing/CHANGELOG.md) |
| [learning-to-skill](plugins/learning-to-skill) | Writes a lesson from a session into the instruction files your agents read, such as AGENTS.md, CLAUDE.md, or a skill's SKILL.md, once and in the place that reaches the right agents, only after you approve the diff | `/learning-to-skill:learning-to-skill` in Claude Code, or **Learning to Skill** after typing `$` in Codex. It also starts when you ask the agent to remember a lesson | [0.1.2](plugins/learning-to-skill/CHANGELOG.md) |
| [machine-cleanup](plugins/machine-cleanup) | Finds caches tools rebuild, build output git ignores, large and duplicate files, unused apps, dev servers left running, heavy processes, login items, and running containers, lets you pick on a local page, and frees only your picks, with anything another session uses shown but kept out of reach | `/machine-cleanup:machine-cleanup` in Claude Code, or **Machine Cleanup** after typing `$` in Codex. It also starts when you say the disk is full or the computer is slow | [0.1.0](plugins/machine-cleanup/CHANGELOG.md) |
| [portman](plugins/portman) | Keeps one registry of the localhost ports each project uses, shows what holds each port right now, suggests free ports that avoid common defaults, and writes a project's ports to `.env.local` and Docker Compose after you approve | `/portman:portman` in Claude Code, or **Portman** after typing `$` in Codex. It also starts when a port is already in use | [0.3.1](plugins/portman/CHANGELOG.md) |
| [product-deck](plugins/product-deck) | Makes a product introduction deck from screenshots of the real product, keeps every word in one data file, checks the layout and the wording by machine, and renders HTML, PDF, and PowerPoint | `/product-deck:product-deck` in Claude Code, or **Product Deck** after typing `$` in Codex. It also starts when you ask for a product deck | [0.1.0](plugins/product-deck/CHANGELOG.md) |
| [repo-progress](plugins/repo-progress) | Shows every repository you work on in one table, with worktrees, open issues and pull requests, uncommitted files, and the ones that have stalled first, without changing anything | `/repo-progress:repo-progress` in Claude Code, or **Repo Progress** after typing `$` in Codex. It also starts when you ask what you were working on | [0.1.2](plugins/repo-progress/CHANGELOG.md) |
| [screen-video](plugins/screen-video) | Plans a video of your web app with you, shows it as a storyboard of pictures before anything is recorded, and records it in a browser into captioned, edited, vertical, and GIF videos, blurring private values and stopping before steps that send something or pay | `/screen-video:screen-video` in Claude Code, or **Screen Video** after typing `$` in Codex. It also starts when you ask for a demo video of your app | [0.1.0](plugins/screen-video/CHANGELOG.md) |
| [secure-dotfile](plugins/secure-dotfile) | Finds API keys and tokens written into your shell startup files, `~/.npmrc`, and `~/.aws/credentials` and moves the ones you pick into the macOS Keychain, the Linux secret service, pass, or 1Password, without the agent seeing any value | `/secure-dotfile:secure-dotfile` in Claude Code, or **Secure Dotfile** after typing `$` in Codex. It also starts when you mention a secret in your shell configuration | [0.7.1](plugins/secure-dotfile/CHANGELOG.md) |
| [session-handoff](plugins/session-handoff) | Writes a short message to paste into a new agent session and saves the options already rejected, the current phase, delegated work, and things not to do for the project, refusing anything that looks like a secret | `/session-handoff:session-handoff` in Claude Code, or **Session Handoff** after typing `$` in Codex. It starts only when you call it | [0.1.1](plugins/session-handoff/CHANGELOG.md) |
| [skill-tune](plugins/skill-tune) | Measures a plugin's skill with `claude plugin eval` cases kept in the plugin, shortens its `SKILL.md`, and measures again so that no case scores lower, with the cost agreed before any run | `/skill-tune:skill-tune` in Claude Code, or **Skill Tune** after typing `$` in Codex. It also starts when you ask to measure or shorten a skill | [0.1.0](plugins/skill-tune/CHANGELOG.md) |
| [slides](plugins/slides) | Writes and checks the outline of a deck of ten or more slides, and designs a short presentation as HTML that you edit in the browser and export as PowerPoint, PDF, and HTML | `/slides:slide-builder` and `/slides:slide-forge` in Claude Code, or **Slide Builder** and **Slide Forge** after typing `$` in Codex. It also starts when you ask for a deck or a slide | [0.1.1](plugins/slides/CHANGELOG.md) |
| [techdebt](plugins/techdebt) | Ranks the files most worth fixing by combining how often they change with their size, old TODO comments, missing tests, long functions, and duplication, and explains the top ones | `/techdebt:techdebt` in Claude Code, or **Tech Debt** after typing `$` in Codex. It also starts when you ask about technical debt | [0.3.1](plugins/techdebt/CHANGELOG.md) |

Each plugin's README explains what it does, what it reads and sends, and what it needs.

## Install

Add this repository as a marketplace once, then install the plugins you want.

**Claude Code**

```
/plugin marketplace add cardene777/agent-shuriken
/plugin install techdebt@agent-shuriken
```

**Codex**

```
codex plugin marketplace add cardene777/agent-shuriken
codex plugin add techdebt@agent-shuriken
```

**GitHub Copilot CLI**

```
copilot plugin marketplace add cardene777/agent-shuriken
copilot plugin install techdebt@agent-shuriken
```

**Gemini CLI**

```
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/techdebt/skills/techdebt
```

Replace `techdebt` with any plugin name in the table.
Other agents that read `SKILL.md` can use the skill zip attached to each plugin release.
Installing a plugin copies only that plugin's folder.
[Getting started](docs/getting-started.md) covers running, updating, pinning a version, and removing plugins.

## Docs

| Page | For |
|---|---|
| [agent-shared](docs/agent-shared.md) | Deploying your own skills, rules, and hooks to every agent from `~/.shared` |
| [Getting started](docs/getting-started.md) | Installing, running, updating, and removing plugins in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents |
| [Safety](docs/safety.md) | The guarantees every plugin keeps when it touches your accounts and files |
| [Creating a plugin](docs/creating-a-plugin.md) | Adding a new plugin to this repository |
| [Releasing](docs/releasing.md) | How plugin versions and repository versions are released |
| [Publishing](docs/publishing.md) | Submitting a plugin to Anthropic's and OpenAI's plugin directories |

Every page is also available in Japanese.

## Versions

Each plugin has its own version, released with a tag such as `techdebt--v0.1.0`.
The repository also has a version, released with a tag such as `v0.2.0`, which records the set of plugin versions in the marketplace at that point.
Both follow semantic versioning and are listed on the [releases page](https://github.com/cardene777/agent-shuriken/releases).

## Contributing

Issues and pull requests are welcome.
Read [Creating a plugin](docs/creating-a-plugin.md) and [`AGENTS.md`](AGENTS.md) first, and run `bash scripts/check.sh` before opening a pull request.

## Security

Report vulnerabilities privately as described in [`SECURITY.md`](SECURITY.md).

## License

[MIT](LICENSE). Each plugin folder carries a copy of the license and lists its bundled third-party material.
