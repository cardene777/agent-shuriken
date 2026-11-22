# Changelog

Releases of the digital-dashboard plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-22

- The `digital-dashboard` skill judges which screens of a design are presentation dashboards in two passes: `screen_kind.py` marks a screen whose item definitions have a chart and a total as a candidate, in Japanese or English specifications, and the agent keeps the candidates whose main purpose is to read the whole situation and decide the next action, asking the user in the chat when it cannot tell
- `fetch_official.py` downloads the 24 official files of the Digital Agency's dashboard design guidebook (the guidebook and its plain-text version, the manual, the worksheet, the prototyping kit, the checklist, the summary format, seven Power BI templates, seven color themes, and three maps) from digital.go.jp and the Agency's GitHub repository into `~/.local/share/digital-dashboard/`. Each file is kept only when its SHA-256 matches `references/official-files.json`; a file already in place is not downloaded again, and a file that differs is not kept
- `attachments.py` lists the files to attach: the material declared in the repository's `.claude/design-sources.json` (schema versions 2 and 3), or else the downloaded files with the skill's rules on choosing charts, writing numbers, time axes, colors, and the conventions of finance, medical, SaaS, and public sector dashboards. With a theme it leaves out the files that only set colors and asks for the theme's colors instead of the guidebook's palette
- The agent writes one request for the user's drawing tool that applies the guidebook to the dashboard screens only, and checks the drawn screens itself
- `THIRD_PARTY_NOTICES.md` gives the source and the terms of use of every downloaded file: the Public Data License (PDL) 1.0 of digital.go.jp, and the terms of the National Land Numerical Information for the maps

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/digital-dashboard--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/digital-dashboard--v0.1.0
