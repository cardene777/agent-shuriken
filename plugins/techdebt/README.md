# Tech Debt

Find the technical debt worth fixing first: the files your team keeps changing that are also large, untested, or full of long functions, old TODOs, and copied code.

English · [日本語](README.ja.md)

![The report's ranking, with the agent's notes on what the top two files are, why they cost the team, and the first step to fix them](assets/screenshot.png)

Linters list thousands of warnings without saying which ones matter.
Debt matters where people keep working: a 2,000-line file nobody touches costs little, and a 400-line file changed every week costs a lot.
This plugin reads your code and its git history, combines how often each file changes with its size, long functions, TODO and FIXME comments and their age, duplicated blocks, and missing tests, and ranks the files where fixing pays off first.
The agent then reads the top files and writes what each one is, why it costs the team, and the first step to fix it.

```
Measure the code and its history ──> Rank the files ──> Explain the top files ──> Show the report
 (agent)                              (agent)            (agent)                   (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install techdebt@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add techdebt@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install techdebt@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/techdebt/skills/techdebt   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask about technical debt, for example "where is the tech debt in this repo, and what should we refactor first?".
You can also call it: run `/techdebt:techdebt` in Claude Code, optionally followed by a folder, or type `$` and pick **Tech Debt** in Codex.
In GitHub Copilot CLI, write `/techdebt` in your request, and in Gemini CLI, describe the task.

1. The agent scans the repository, or a folder inside it such as one package of a monorepo
2. The agent ranks the files and reads the top ones to write what each is, why it costs the team, and the first step to fix it
3. The agent opens the report and sums up the top files and the totals in the chat

The scan of the repository in the screenshot starts like this.

```text
techdebt scan of ~/work/shop (HEAD 61d7f14 on main, 26 source files, 5 test files, 199 commits in the last 12 months)
Hotspots:       19 files changed 2 or more times
Markers:        6 (FIXME 1, HACK 1, TODO 4), oldest 360 days
Untested:       15 source files have no test file with a matching name
Long functions: 7 over 60 lines
Large files:    1 over 500 lines
Duplication:    2 blocks, 20 lines
Unused deps:    2 (approximate: names not found in imports, configs, or scripts)
Deprecated calls: 3 (eslint 3; not run: ruff, semgrep)
Tool ruff:      not run, ruff is not installed in .venv/bin or on PATH

Start here
 1  src/billing/invoice.py  score 0.97  changed 31 times, 543 lines, 3 long functions, marker weight 4, 11 duplicated lines, no test file
 2  src/api/orders.ts  score 0.67  changed 44 times, 331 lines, 1 long function, marker weight 1, 9 duplicated lines, no test file
 3  src/web/checkout.tsx  score 0.40  changed 25 times, 220 lines, 2 long functions, marker weight 2, no test file
 4  src/billing/refunds.py  score 0.36  changed 18 times, 163 lines, 1 long function, marker weight 1, 11 duplicated lines, no test file
 5  src/api/returns.ts  score 0.17  changed 13 times, 70 lines, 9 duplicated lines, no test file
```

The ranking goes on to 20 files, and the last two lines give the folders of the data and the report.

The report has a tab for the ranking and one per measure, and switches between English and Japanese.
Unused dependencies are found without knip by searching for each name in imports, config files, and `scripts`, so that count is approximate. When knip is installed, its findings are used instead.
Deprecated calls are listed by tools that are already installed: ruff with its deprecation rules, semgrep with the project's own rule files and `--metrics off`, and ESLint when its config turns on a deprecation rule. semgrep findings of security rules are left out.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always |
| `git` | For changes per file, the age of TODO comments, and the ranking. Without it the other measures still run |
| `knip` | Optional. Used when installed in the project's `node_modules/.bin` |
| `ruff` | Optional. Used when installed in `.venv/bin` or on `PATH` |
| `semgrep` | Optional. Used when installed in `.venv/bin` or on `PATH` and the project has its own rule files (`.semgrep.yml`, `.semgrep.yaml`, or `.semgrep/`) |
| `eslint` | Optional. Used when installed in the project's `node_modules/.bin` and its config turns on a deprecation rule |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains each measure, the ranking, and what is skipped.
In short:

- It reads the source files of the folder you scan and its git history (`git log`, `git blame`)
- It runs `knip`, `ruff`, `semgrep`, and `eslint` only when they are already installed, and never downloads or installs anything
- It runs semgrep with `--metrics off` and `--disable-version-check`, only with the project's rule files, never with registry rules, and keeps semgrep's settings and log in a temporary folder that it removes
- It never changes a file in your project
- It connects to nothing on the network
- It keeps `scan.json`, the agent's notes, and `report.html` in `~/.local/share/techdebt/<project>/`, readable only by you, until you delete them
- It keeps up to 200 characters of each marker line, with text that looks like a key, a token, or a password replaced with `***` and your home folder with `~`

## License

[MIT](LICENSE)
