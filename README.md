<div align="center">

<img src="assets/icon.svg" width="96" alt="agent-shuriken icon">

# agent-shuriken

**Careful plugins for Claude Code, Codex, and other coding agents.**

Each plugin hands a tedious chore to your agent and keeps you in charge of every irreversible step.
The same plugin installs in Claude Code, Codex, and GitHub Copilot CLI, and its skill works in Gemini CLI and other agents that read `SKILL.md`.

English · [日本語](README.ja.md)

[Plugins](#plugins) ·
[Install](#install) ·
[Docs](#docs) ·
[Releases](https://github.com/cardene777/agent-shuriken/releases) ·
[Changelog](CHANGELOG.md)

</div>

## Plugins

| Plugin | What it does | How to run it | Latest |
|---|---|---|---|
| [account-cleanup](plugins/account-cleanup) | Finds web accounts you no longer use without reading any passwords, then cancels subscriptions and deletes the accounts you approve | `/account-cleanup:account-cleanup` in Claude Code, or **Account Cleanup** after typing `$` in Codex. It also starts when you describe the task | [0.2.1](plugins/account-cleanup/CHANGELOG.md) |
| [compare-report](plugins/compare-report) | Researches the candidates for a choice and writes an HTML and PDF comparison report, with a source for every claim and a rationale for every score | `/compare-report:compare-report` in Claude Code, or **Compare Report** after typing `$` in Codex. It also starts when you ask for a comparison | [0.2.1](plugins/compare-report/CHANGELOG.md) |
| [diagram-explainer](plugins/diagram-explainer) | Writes an explainer with a figure drawn in every section as one HTML file, built from JSON and checked before you share it | `/diagram-explainer:diagram-explainer` in Claude Code, or **Diagram Explainer** after typing `$` in Codex. It also starts when you ask for an explainer | [0.2.1](plugins/diagram-explainer/CHANGELOG.md) |
| [docs-publish](plugins/docs-publish) | Writes the public docs of an open source project in five parts, Quickstart, Concepts, API reference, Cookbook, and FAQ, in English and a second language you pick, and checks that every page has its translation and every link resolves | `/docs-publish:docs-publish` in Claude Code, or **Docs Publish** after typing `$` in Codex. It also starts when you ask for documentation for your project | [0.1.1](plugins/docs-publish/CHANGELOG.md) |
| [excalidraw-diagram](plugins/excalidraw-diagram) | Draws architecture, flow, sequence, and entity-relationship diagrams as Excalidraw files laid out by a script and checked for overlaps, crowded spacing, and labels on lines, with SVG and PNG copies | `/excalidraw-diagram:excalidraw-diagram` in Claude Code, or **Excalidraw Diagram** after typing `$` in Codex. It also starts when you ask for a diagram | [0.2.0](plugins/excalidraw-diagram/CHANGELOG.md) |
| [feedback-loop](plugins/feedback-loop) | When you correct the agent's work, records the correction, fixes the files, has an evaluator that edits nothing review the fix until every criterion passes, and keeps the lesson as a check or a rule | `/feedback-loop:feedback-loop` in Claude Code, or **Feedback Loop** after typing `$` in Codex. It also starts when you correct earlier output | [0.1.1](plugins/feedback-loop/CHANGELOG.md) |
| [init-project](plugins/init-project) | Sets up a project for local work: picks a free local port, writes a Docker setup, and links env files to 1Password with references, showing every file before it is written | `/init-project:init-project` in Claude Code, or **Init Project** after typing `$` in Codex. It also starts when you ask to set up a project | [0.1.1](plugins/init-project/CHANGELOG.md) |
| [learning-to-skill](plugins/learning-to-skill) | Writes a lesson from a session into the instruction files your agents read, such as AGENTS.md, CLAUDE.md, or a skill's SKILL.md, once and in the place that reaches the right agents, only after you approve the diff | `/learning-to-skill:learning-to-skill` in Claude Code, or **Learning to Skill** after typing `$` in Codex. It also starts when you ask the agent to remember a lesson | [0.1.1](plugins/learning-to-skill/CHANGELOG.md) |
| [portman](plugins/portman) | Keeps one registry of the localhost ports each project uses, shows what holds each port right now, suggests free ports that avoid common defaults, and writes a project's ports to `.env.local` and Docker Compose after you approve | `/portman:portman` in Claude Code, or **Portman** after typing `$` in Codex. It also starts when a port is already in use | [0.1.0](plugins/portman/CHANGELOG.md) |
| [repo-progress](plugins/repo-progress) | Shows every repository you work on in one table, with worktrees, open issues and pull requests, uncommitted files, and the ones that have stalled first, without changing anything | `/repo-progress:repo-progress` in Claude Code, or **Repo Progress** after typing `$` in Codex. It also starts when you ask what you were working on | [0.1.1](plugins/repo-progress/CHANGELOG.md) |
| [secure-dotfile](plugins/secure-dotfile) | Finds API keys and tokens written into your shell startup files and moves the ones you pick into the macOS Keychain, without the agent seeing any value | `/secure-dotfile:secure-dotfile` in Claude Code, or **Secure Dotfile** after typing `$` in Codex. It also starts when you mention a secret in your shell configuration | [0.2.0](plugins/secure-dotfile/CHANGELOG.md) |
| [session-handoff](plugins/session-handoff) | Writes a short message to paste into a new agent session and saves the options already rejected, the current phase, delegated work, and things not to do for the project, refusing anything that looks like a secret | `/session-handoff:session-handoff` in Claude Code, or **Session Handoff** after typing `$` in Codex. It starts only when you call it | [0.1.0](plugins/session-handoff/CHANGELOG.md) |
| [techdebt](plugins/techdebt) | Ranks the files most worth fixing by combining how often they change with their size, old TODO comments, missing tests, long functions, and duplication, and explains the top ones | `/techdebt:techdebt` in Claude Code, or **Tech Debt** after typing `$` in Codex. It also starts when you ask about technical debt | [0.2.2](plugins/techdebt/CHANGELOG.md) |

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
