# Getting started

English · [日本語](getting-started.ja.md)

This page shows how to install, run, update, and remove the plugins in Claude Code, Codex, GitHub Copilot CLI, and Gemini CLI, and how other agents that read `SKILL.md` can use them.
The same plugin folder works in all of them, so you can install a plugin in one agent or several.

## Install

Add this repository as a marketplace once.
After that, install any plugin from the [plugin table](../README.md#plugins) by name.

| | Claude Code | Codex | GitHub Copilot CLI |
|---|---|---|---|
| Add the marketplace | `/plugin marketplace add cardene777/agent-shuriken` | `codex plugin marketplace add cardene777/agent-shuriken` | `copilot plugin marketplace add cardene777/agent-shuriken` |
| Install a plugin | `/plugin install pc-tidy@agent-shuriken` | `codex plugin add pc-tidy@agent-shuriken` | `copilot plugin install pc-tidy@agent-shuriken` |
| See what is installed | `/plugin` | `codex plugin list` | `copilot plugin list` |

Claude Code also accepts the same commands in a terminal as `claude plugin marketplace add ...` and `claude plugin install ...`.
GitHub Copilot CLI reads the same marketplace file as Claude Code, so no extra setup is needed.
Start a new session after installing so the agent loads the plugin.

Gemini CLI has no marketplace for skills, so it installs each plugin's skill folder from this repository instead.

```
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/pc-tidy/skills/pc-tidy
gemini skills list
```

Installing copies only that plugin's folder, or that skill's folder in Gemini CLI.
Nothing runs at install time.

## Run a plugin

Each plugin's README says how it starts.
Some start when you describe the task in plain words, and some start only when you call them.

| | Claude Code | Codex | GitHub Copilot CLI | Gemini CLI |
|---|---|---|---|---|
| Call a plugin's skill | `/<plugin>:<skill>`, for example `/pc-tidy:pc-tidy` | Type `$` and pick the skill, for example **PC Tidy** | Name the skill with a slash in your request, for example "use the /pc-tidy skill" | Describe the task. Gemini CLI asks you to approve the skill before it loads it |
| Describe the task | Write what you want, for example "free up disk space on my Mac" | Same | Same | Same |

The agent talks to you in the language you write in.
The pages a plugin opens default to English and have an English / 日本語 switch in the header.

Plugins read and write outside the project folder, and some use the network.
When an agent's sandbox blocks a command, as Codex can, approve it to let the plugin continue.

A plugin that starts only when you call it in Claude Code and Codex may also start when you describe its task in other agents, because they may not read the setting that stops it.
It still changes nothing until you pick the items and approve the step its README describes.

## Update

| | Claude Code | Codex | GitHub Copilot CLI | Gemini CLI |
|---|---|---|---|---|
| Fetch the newest marketplace | `claude plugin marketplace update agent-shuriken` | `codex plugin marketplace upgrade agent-shuriken` | `copilot plugin marketplace update agent-shuriken` | Not needed |
| Update a plugin | `claude plugin update pc-tidy@agent-shuriken` | `codex plugin add pc-tidy@agent-shuriken` | `copilot plugin update pc-tidy` | Run the install command again. It replaces the installed copy |

Restart the agent after updating.
Each plugin's `CHANGELOG.md` lists what changed.

## Stay on one version

Add the marketplace at a tag instead of the newest commit.
A plugin tag such as `pc-tidy--v0.1.0` or a repository tag such as `v0.2.0` both work, and every plugin in the marketplace then comes from that tag.

| | Claude Code | Codex | GitHub Copilot CLI |
|---|---|---|---|
| Add the marketplace at a tag | `/plugin marketplace add cardene777/agent-shuriken#v0.2.0` | `codex plugin marketplace add cardene777/agent-shuriken --ref v0.2.0` | `copilot plugin marketplace add cardene777/agent-shuriken#v0.2.0` |

In Gemini CLI, install the skill zip of a release, as the next section shows.
[Releasing](releasing.md) explains how plugin tags and repository tags differ.

## Install without the marketplace

Each plugin release attaches a zip of its skill folder.
Unzip it into your agent's skills folder.
GitHub Copilot CLI, Gemini CLI, and other agents that follow the Agent Skills format read `~/.agents/skills/`.

```
unzip pc-tidy-0.1.0-skill.zip -d ~/.claude/skills/   # Claude Code
unzip pc-tidy-0.1.0-skill.zip -d ~/.codex/skills/    # Codex
unzip pc-tidy-0.1.0-skill.zip -d ~/.agents/skills/   # GitHub Copilot CLI, Gemini CLI, and other agents
```

For an agent that reads another folder, unzip it there; its documentation names the folder.
A skill installed this way has no plugin prefix, so you call it as `/pc-tidy` in Claude Code.
It does not update by itself. Download a newer zip to update it.

## Remove

| | Claude Code | Codex | GitHub Copilot CLI | Gemini CLI |
|---|---|---|---|---|
| Remove a plugin | `claude plugin uninstall pc-tidy@agent-shuriken` | `codex plugin remove pc-tidy@agent-shuriken` | `copilot plugin uninstall pc-tidy` | `gemini skills uninstall pc-tidy` |
| Remove the marketplace | `claude plugin marketplace remove agent-shuriken` | `codex plugin marketplace remove agent-shuriken` | `copilot plugin marketplace remove agent-shuriken` | Not needed |

Removing a plugin does not delete the data it saved.
Each plugin's README says where its data lives.
