# Changelog

Releases of the techdebt plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- `scan` lists unused dependencies without knip: names in the `dependencies` and `devDependencies` of each `package.json` that no import, require, config file, or `scripts` entry uses. A package that a used package needs as a peer, a plugin named by its short name, and `@types/<name>` of a used name count as used. The measure is marked approximate, and when knip ran, its unused dependencies are listed instead, once. Before, unused dependencies were found only when knip was installed
- `scan` lists deprecated calls found by tools that are already installed: ruff with its rules for deprecated APIs, semgrep with the project's own rule files, `--metrics off`, and no registry rules, and ESLint when its config turns on a deprecation rule. semgrep findings of security rules are left out, and its other findings are listed under the tools. The summary has a "Deprecated calls" line and the report a tab and a card, each listing the tools that did not run and why
- A ruff that stops with an error is reported as not run, with its exit code and the first line it wrote. Before, it was reported as having run with no findings
- `scan.json` has schema 3. `explain` and `report` refuse a `scan.json` from another version and ask for a new scan

## [0.2.2] - 2026-11-14

- Marker lines in `scan.json` and the report have text that looks like a key, a token, or a password replaced with `***`, and the home folder with `~`. Before, a comment quoting a token carried it into the report and into any issue that quoted the line

## [0.2.1] - 2026-11-13

- The README's summary and screenshot come from one scan of one sample repository, so their numbers agree

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Measures any git repository, or a folder inside one, with Python and `git` alone: changes per file in the last 12 months, TODO, FIXME, HACK, XXX, and deprecation markers in comments aged with `git blame`, source files without a matching test file, functions over 60 lines, files over 500 lines, and duplicated blocks of 8 or more lines
- Runs `knip` and `ruff` when they are already installed in the project or on `PATH`, and never downloads anything
- Ranks the files most worth fixing by combining the measures, weighted toward the files people change most
- Adds the agent's notes on what each top file is, why it costs the team, and the first step to fix it
- Writes one HTML report with a tab per measure, an English and Japanese switch, and pages of 50 rows, which loads nothing from the network
- Starts when you ask about technical debt, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/techdebt--v0.2.2...HEAD
[0.2.2]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.2.2
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.1.0
