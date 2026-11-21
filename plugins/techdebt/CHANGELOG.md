# Changelog

Releases of the techdebt plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The report follows the report page of page-design more closely. A value that was not measured (hotspots outside git, unused dependencies without a package.json, deprecated calls when none of ruff, semgrep, and ESLint ran) shows as not measured instead of 0, and unused dependencies found by name say they are approximate. Each ranked row shows its score as a number with a bar that stands out in both themes, and the pressed row's measures and notes sit beside the list, with pages of 50 rows. A section under the tabs says how each value was measured and why each tool did not run. The numbers of the band sit on one line, Japanese labels break only between words, and the header lines up with the content. The Japanese words are plainer, and the test measure says it looks for a test file of a matching name, also in the summary of `scan`, which now writes hotspots outside git and dependencies without a package.json as not measured
- `musubi.json` follows the `structure` and `look` formats, the `report` page type, and `verify` of page-design in the design-formats plugin through musubi, as optional follows. When page-design is installed, the agent builds the report on them and runs page-design's verify on `report.html`; when the `musubi` command is installed, it runs `musubi check` first. Without design-formats, the report is built from the plugin's own template as before
- The report quotes what each tool wrote in code, letter for letter: the findings on the Tools and Deprecated calls tabs, and the first line of a tool that stopped, which now sits under the exit code instead of after a colon. Opened in a browser, the reports of tools with findings and of tools that stopped pass page-design's verify in English and Japanese. `scan.json` keeps the tools' words unchanged. The tool names in the Deprecated calls table no longer break in the middle on a narrow screen
- The facts under the report's title (the commit, the branch, the source files, the commits in the window, and when it was generated) are pairs of a name and a value instead of one sentence, as in the report page of page-design. Each tool on the Tools tab is headed by its name, with whether it ran on the line under it, and the Deprecated calls tab lists each tool and its result in a table. Opened in a browser, every tab passes page-design's verify in English and Japanese, and the plugin's tests check this on the opened pages
- The report's header has a Light and Dark switch next to the language switch. It follows the system setting until you choose, and keeps your choice in the browser's local storage under `techdebt-theme`. The report is titled `Technical debt in <project>` instead of `<project>: technical debt`

## [0.3.1] - 2026-11-16

- The template is `templates/base.html`, so that no file in the plugin is named `report.html`; `scan` still writes the report as `report.html`
- The `SKILL.md` is shorter: the table of measures and the weights of the score, which `docs/how-it-works.md` gives, the description of the report page, and the failures whose messages say what to fix are gone, and the description says only what the skill does and when to use it
- The plugin has `claude plugin eval` cases under `evals/` that measure the skill, run by hand

## [0.3.0] - 2026-11-14

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

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/techdebt--v0.3.1...HEAD
[0.3.1]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.3.1
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.3.0
[0.2.2]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.2.2
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.1.0
