# Getting started

English · [日本語](getting-started.ja.md)

This page shows how to install, run, update, and remove the plugins in Claude Code and in Codex.
The same plugin folder works in both, so you can install a plugin in one agent or both.

## Install

Add this repository as a marketplace once.
After that, install any plugin from the [plugin table](../README.md#plugins) by name.

| | Claude Code | Codex |
|---|---|---|
| Add the marketplace | `/plugin marketplace add cardene777/agent-shuriken` | `codex plugin marketplace add cardene777/agent-shuriken` |
| Install a plugin | `/plugin install pc-tidy@agent-shuriken` | `codex plugin add pc-tidy@agent-shuriken` |
| See what is installed | `/plugin` | `codex plugin list` |

Claude Code also accepts the same commands in a terminal as `claude plugin marketplace add ...` and `claude plugin install ...`.
Start a new session after installing so the agent loads the plugin.

Installing copies only that plugin's folder into the agent's plugin cache.
Nothing runs at install time.

## Run a plugin

Each plugin's README says how it starts.
Some start when you describe the task in plain words, and some start only when you call them.

| | Claude Code | Codex |
|---|---|---|
| Call a plugin's skill | `/<plugin>:<skill>`, for example `/pc-tidy:pc-tidy` | Type `$` and pick the skill, for example **PC Tidy** |
| Describe the task | Write what you want, for example "free up disk space on my Mac" | Same |

The agent talks to you in the language you write in.
The pages a plugin opens default to English and have an English / 日本語 switch in the header.

In Codex, the plugins read and write outside the project folder, and some use the network.
When the Codex sandbox blocks a command, approve it to let the plugin continue.

## Update

| | Claude Code | Codex |
|---|---|---|
| Fetch the newest marketplace | `claude plugin marketplace update agent-shuriken` | `codex plugin marketplace upgrade agent-shuriken` |
| Update a plugin | `claude plugin update pc-tidy@agent-shuriken` | `codex plugin add pc-tidy@agent-shuriken` |

Restart the agent after updating.
Each plugin's `CHANGELOG.md` lists what changed.

## Stay on one version

Add the marketplace at a tag instead of the newest commit.
A plugin tag such as `pc-tidy--v0.1.0` or a repository tag such as `v0.2.0` both work, and every plugin in the marketplace then comes from that tag.

| | Claude Code | Codex |
|---|---|---|
| Add the marketplace at a tag | `/plugin marketplace add cardene777/agent-shuriken#v0.2.0` | `codex plugin marketplace add cardene777/agent-shuriken --ref v0.2.0` |

[Releasing](releasing.md) explains how plugin tags and repository tags differ.

## Install without the marketplace

Each plugin release attaches a zip of its skill folder.
Unzip it into your agent's skills folder.

```
unzip pc-tidy-0.1.0-skill.zip -d ~/.claude/skills/   # Claude Code
unzip pc-tidy-0.1.0-skill.zip -d ~/.codex/skills/    # Codex
```

A skill installed this way has no plugin prefix, so you call it as `/pc-tidy` in Claude Code.
It does not update by itself. Download a newer zip to update it.

## Remove

| | Claude Code | Codex |
|---|---|---|
| Remove a plugin | `claude plugin uninstall pc-tidy@agent-shuriken` | `codex plugin remove pc-tidy@agent-shuriken` |
| Remove the marketplace | `claude plugin marketplace remove agent-shuriken` | `codex plugin marketplace remove agent-shuriken` |

Removing a plugin does not delete the data it saved.
Each plugin's README says where its data lives.
