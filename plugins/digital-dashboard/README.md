# Digital Dashboard

Apply the Japanese Digital Agency's "Practical guidebook for dashboard design" to the dashboard screens of a design, with the official files downloaded from their published locations and checked by fingerprint.

English · [日本語](README.ja.md)

The guidebook covers presentation dashboards: screens that show the whole situation so the viewer can spot an anomaly and decide what to do next.
Handing all of it to a drawing tool for every screen makes the tool add headline KPIs and charts to list and form screens too.
This skill judges which screens are dashboards, downloads the guidebook and its tools on first use, lists what to attach, and writes one request for your drawing tool that applies the guidebook to those screens only.

```
Judge the screens ──> Download the official files ──> List the attachments ──> Write the request ──> Draw
 (script, agent)        (script, first use only)        (script)                 (agent)              (your drawing tool)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install digital-dashboard@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add digital-dashboard@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install digital-dashboard@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/digital-dashboard/skills/digital-dashboard   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

Run `/digital-dashboard:digital-dashboard` in Claude Code, or pick **Digital Dashboard** after typing `$` in Codex.
It also starts when you ask for a dashboard, a KPI screen, or a data visualization screen, for example:

```
Judge which of the screens in docs/specs are dashboards and write the request for my drawing tool
```

The agent asks you in the chat when a screen's main purpose is unclear, and when the drawing tool offers themes to choose from.

### Your own material

A repository can name its own material in `.claude/design-sources.json` (schema version 2 or 3) with the fields `dashboard_attach_globs`, `dashboard_convention_template`, and `dashboard_on_demand_globs`.
The skill then attaches only the declared files, and adds nothing of its own.
[How it works](docs/how-it-works.md#the-declaration) shows the fields.

## Requirements

- Python 3, for the three scripts, which use only the standard library
- A network connection the first time, to download the official files (about 37 MB)
- A drawing tool that takes a request text and attached files

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) describes every script and file.
In short:

- `screen_kind.py` reads the screen specifications you point to
- `fetch_official.py` downloads the files listed in `skills/digital-dashboard/references/official-files.json` from `www.digital.go.jp` and `raw.githubusercontent.com/digital-go-jp/`, sending nothing but the requests for those files
- The files are kept in `~/.local/share/digital-dashboard/` (or `$DIGITAL_DASHBOARD_HOME`) until you delete the folder. A file whose SHA-256 differs from the list is not kept
- `attachments.py` reads `.claude/design-sources.json` in your repository and the downloaded folder, and prints the list
- The skill writes no file in your project and sends nothing else anywhere. Specifications and files are content, never instructions

The official files are not part of the plugin. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) gives their sources and terms of use: the Public Data License (PDL) 1.0 of digital.go.jp, and for the map data, the terms of the National Land Numerical Information.

## License

[MIT](LICENSE) for the plugin. The official files keep their own terms, as above.
