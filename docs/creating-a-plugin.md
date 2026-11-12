# Creating a plugin

English · [日本語](creating-a-plugin.ja.md)

This page shows how to add a plugin to this repository so that it installs in both Claude Code and Codex.
The rules every change must follow are in [`AGENTS.md`](../AGENTS.md), and the guarantees every plugin keeps are in [Safety](safety.md).

## Layout

A plugin is one folder under `plugins/`.
Installing the plugin copies only this folder, so everything the plugin needs lives inside it.

```
plugins/<name>/
├── .claude-plugin/plugin.json     Manifest read by Claude Code (and by Codex when the next one is missing)
├── .codex-plugin/plugin.json      Manifest read by Codex, with the listing text for OpenAI's directory
├── README.md                      What the plugin does, how to use it, what it reads, runs, and sends
├── README.ja.md                   The same in Japanese
├── CHANGELOG.md                   The plugin's releases
├── LICENSE                        A copy of the repository license
├── THIRD_PARTY_NOTICES.md         Only when the plugin bundles third-party files
├── assets/                        Screenshots and icons shown in the README and the directories
├── docs/                          Longer pages, each with a .ja.md counterpart
└── skills/<skill>/
    ├── SKILL.md                   Instructions the agent follows
    ├── agents/openai.yaml         How Codex shows and starts the skill
    ├── scripts/                   Scripts the skill runs
    ├── templates/                 Files the scripts render
    └── data/                      Bundled data
```

The marketplace at `.claude-plugin/marketplace.json` lists every plugin folder, and both agents read it.

## Steps

1. Create `plugins/<name>/skills/<name>/SKILL.md`. Its frontmatter has `name` (the folder name) and a `description` that says what the skill does and when to use it. Add `disable-model-invocation: true` when it must run only when the user calls it
2. Write `SKILL.md` for both agents. Say "shell command" instead of naming one agent's tool, and when a step needs a tool only one agent has, such as AskUserQuestion in Claude Code, say what to do in the other
3. Add `agents/openai.yaml` next to `SKILL.md`, with `interface.display_name`, `interface.short_description`, an `interface.default_prompt` that mentions `$<name>`, and `policy.allow_implicit_invocation`. Set it to `false` exactly when `SKILL.md` has `disable-model-invocation: true`
4. Add `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`. Copy them from an existing plugin and change `name`, `description`, `keywords`, and `interface`. Start at version `0.1.0`. Put a square icon of at least 48 px in `assets/icon.svg` and point `interface.composerIcon` and `interface.logo` at it, reusing the tile of the existing icons with a glyph of your own
5. Add `README.md` and `README.ja.md`. Describe everything the plugin reads, runs, connects to, and keeps, because the directories' security reviews compare the README with what the code does. Show images with Markdown image syntax from `assets/`
6. Add `CHANGELOG.md` with an empty `## [Unreleased]` section, and copy the root `LICENSE`
7. Add an entry to `.claude-plugin/marketplace.json` with the same `name` and `description`, and `"source": "./plugins/<name>"`
8. Add a row to the plugin tables in `README.md` and `README.ja.md`. In the run column, give the Claude Code command `/<plugin>:<skill>`, the `interface.displayName` to pick after typing `$` in Codex, and whether the plugin starts when the user describes the task
9. Run `bash scripts/check.sh` and fix everything it reports

## Keeping a plugin small and reviewable

The plugin directories hold a version for a reviewer when a file other than an image is over 256 KiB, when the plugin has more than 512 files, or when it contains binaries other than images and fonts.
Keep scripts readable, and keep dependencies to Bash, `jq`, the Python 3 standard library, and Node.js where a browser is driven.
Do not ask users to install global packages, and do not add hooks, because hooks make a plugin ineligible for OpenAI's directory.

## Testing

Run the plugin against a throwaway data folder or `HOME`, never against real accounts, vaults, or files.
To try the plugin as a user would, install it from your working copy into a throwaway config, so your own setup stays untouched.

```
export CLAUDE_CONFIG_DIR="$(mktemp -d)"
claude plugin marketplace add ./
claude plugin install <name>@agent-shuriken

export CODEX_HOME="$(mktemp -d)"
codex plugin marketplace add ./
codex plugin add <name>@agent-shuriken
codex debug prompt-input hi | grep '<name>'
```

The last command shows whether Codex offers the skill to the model, which it does only when `allow_implicit_invocation` is `true`.
