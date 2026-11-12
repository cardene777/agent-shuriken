<div align="center">

<img src="assets/icon.svg" width="96" alt="agent-shuriken icon">

# agent-shuriken

**Careful plugins for Claude Code and Codex.**

Each plugin hands a tedious chore to your agent and keeps you in charge of every irreversible step.
The same plugin installs in Claude Code and in Codex.

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
| [account-cleanup](plugins/account-cleanup) | Finds web accounts you no longer use without reading any passwords, then cancels subscriptions and deletes the accounts you approve | `/account-cleanup:account-cleanup` in Claude Code, or **Account Cleanup** after typing `$` in Codex. It also starts when you describe the task | [0.1.1](plugins/account-cleanup/CHANGELOG.md) |
| [compare-report](plugins/compare-report) | Researches the candidates for a choice and writes an HTML and PDF comparison report, with a source for every claim and a rationale for every score | `/compare-report:compare-report` in Claude Code, or **Compare Report** after typing `$` in Codex. It also starts when you ask for a comparison | [0.1.0](plugins/compare-report/CHANGELOG.md) |
| [pc-tidy](plugins/pc-tidy) | Lists what has gone unused on your Mac and deletes only the items you pick, to free up disk space | `/pc-tidy:pc-tidy` in Claude Code, or **PC Tidy** after typing `$` in Codex. It starts only when you call it | [0.1.1](plugins/pc-tidy/CHANGELOG.md) |
| [root-cause](plugins/root-cause) | Finds the cause of a bug from evidence before changing any code, then fixes only the cause, starting with a test that fails | `/root-cause:root-cause` in Claude Code, or **Root Cause** after typing `$` in Codex. It also starts when you describe a bug | [0.1.0](plugins/root-cause/CHANGELOG.md) |

Each plugin's README explains what it does, what it reads and sends, and what it needs.

## Install

Add this repository as a marketplace once, then install the plugins you want.

**Claude Code**

```
/plugin marketplace add cardene777/agent-shuriken
/plugin install pc-tidy@agent-shuriken
```

**Codex**

```
codex plugin marketplace add cardene777/agent-shuriken
codex plugin add pc-tidy@agent-shuriken
```

Replace `pc-tidy` with any plugin name in the table.
Installing a plugin copies only that plugin's folder.
[Getting started](docs/getting-started.md) covers running, updating, pinning a version, and removing plugins.

## Docs

| Page | For |
|---|---|
| [Getting started](docs/getting-started.md) | Installing, running, updating, and removing plugins in Claude Code and Codex |
| [Safety](docs/safety.md) | The guarantees every plugin keeps when it touches your accounts and files |
| [Creating a plugin](docs/creating-a-plugin.md) | Adding a new plugin to this repository |
| [Releasing](docs/releasing.md) | How plugin versions and repository versions are released |
| [Publishing](docs/publishing.md) | Submitting a plugin to Anthropic's and OpenAI's plugin directories |

Every page is also available in Japanese.

## Versions

Each plugin has its own version, released with a tag such as `pc-tidy--v0.1.0`.
The repository also has a version, released with a tag such as `v0.2.0`, which records the set of plugin versions in the marketplace at that point.
Both follow semantic versioning and are listed on the [releases page](https://github.com/cardene777/agent-shuriken/releases).

## Contributing

Issues and pull requests are welcome.
Read [Creating a plugin](docs/creating-a-plugin.md) and [`AGENTS.md`](AGENTS.md) first, and run `bash scripts/check.sh` before opening a pull request.

## Security

Report vulnerabilities privately as described in [`SECURITY.md`](SECURITY.md).

## License

[MIT](LICENSE). Each plugin folder carries a copy of the license and lists its bundled third-party material.
