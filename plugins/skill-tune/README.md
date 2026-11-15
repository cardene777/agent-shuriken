# Skill Tune

Measure what a plugin's skill makes your agent do, shorten its `SKILL.md`, and show with the same eval cases that no case got worse.

English · [日本語](README.ja.md)

A `SKILL.md` grows as a skill gains steps, and the agent reads all of it every time the skill starts.
Much of it often says again what the skill's scripts already print or what its headings already show, but cutting by feel can drop the one sentence the agent needed.
This plugin has your agent write `claude plugin eval` cases into the plugin, measure the skill before any change, make only the cuts you agree to, and measure again.
A script runs every eval on a private copy of the plugin with a cost ceiling you set, scores each case without the graders that only show the skill ran, and lists each case as kept, higher, or lower.

```
Read the skill ──> Agree on cases and cuts ──> Write cases ──> Estimate ──> Baseline ──> Shorten ──> Compare
 (agent)            (you choose)                (agent)         (you allow)  (script)     (agent)     (script)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install skill-tune@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add skill-tune@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install skill-tune@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/skill-tune/skills/skill-tune   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask to measure or shorten a skill, for example "measure this plugin's skill with evals and shorten its SKILL.md", "why does this eval case fail?", or "which skills in this repository are longest?".
You can also call it: run `/skill-tune:skill-tune` in Claude Code, or type `$` and pick **Skill Tune** in Codex.
In GitHub Copilot CLI, write `/skill-tune` in your request, and in Gemini CLI, describe the task.

| You want | What happens |
|---|---|
| To measure and shorten a skill | Every step below |
| Eval cases only | Steps 1 to 5, without the cuts |
| To know why a case fails | The agent reads the failing runs' tool calls and names the cause |
| The longest skills in a repository | A table of every skill by length, with its eval cases, and an offer to start with one |

1. The agent measures the `SKILL.md` and lists the parts that repeat what its scripts, headings, or `--help` already say, with the words each cut would save
2. You pick the case groups and the cuts. The agent says what a run costs and asks how much you allow
3. The agent writes the cases into the plugin's `evals/` folder, each with a `fixture.sh` that builds its starting state, and adds checks for them to the plugin's test
4. The script copies the plugin and runs each case once, so a case the sandbox cannot pass is fixed before any money goes into measuring
5. From that run, the script estimates the cost of measuring. You choose how much to spend, and the script records the baseline on a fresh copy
6. The agent makes only the agreed cuts in your `SKILL.md`, and caps its size in the plugin's test
7. The script measures a copy of the new `SKILL.md` and compares it case by case. A case that scored lower is read run by run, and its cause is named before anything changes
8. The agent reports each case's score before, after, and without the plugin, with the cost, and removes the copies and the folders the eval kept

In agents other than Claude Code, the skill does steps 1 to 3 and stops, since `claude plugin eval` comes with Claude Code.

A comparison where nothing got worse looks like this.

```text
outline-first  before 1.00  after 1.00  kept
build-from-outline  before 1.00  after 1.00  kept
fix-missing-figure  before 0.83  after 1.00  higher
unrelated-request  before 1.00  after 1.00  kept
before: runs where the skill fired: 9, average 0.442 USD, 96 s, 14.2 turns
after: runs where the skill fired: 9, average 0.431 USD, 92 s, 13.6 turns
```

## The scores

Each case runs three times with the plugin and, for the baseline, three times without it.
A grader that only shows the skill ran, such as a line its script prints, is marked `with-only` in the case or named with `--indicator`, and does not count toward the score.
A run's score is the share of its other graders that passed, and a case's score is the mean over its runs.

| Status | Meaning |
|---|---|
| `kept` | The case scored the same before and after |
| `higher` | The case scored higher after |
| `lower` | The case scored lower after. `compare` exits 1 and the agent reads the runs on both sides |
| `not measured` | The case has no scored run on one side. `compare` exits 3 |

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always, version 3.9 or later |
| Claude Code | To measure: `claude plugin eval` comes with it, signed in to an account that pays for the runs. Writing cases works in any agent |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the script's commands, how results are scored, and what the data folder holds.
In short:

- The agent reads the plugin you point to, and the script reads its `SKILL.md` files, its `evals/` folder, the eval results, and the traces the eval keeps
- It writes eval cases and the agreed cuts only in that plugin, and keeps copies and results in `~/.local/share/skill-tune/`, readable only by you
- It runs `claude plugin eval` only after you agree on a cost ceiling, and passes that ceiling as `--max-cost-usd`. Each case's `fixture.sh` runs as you, so run it only on plugins you wrote or trust
- The script sends nothing itself. `claude plugin eval` sends each case's prompt and what the agent reads during the run to Anthropic's model through your own Claude Code sign-in, and the cost is billed to your account. Results are not published
- When it finishes, it removes the copies, their results, and the folders the eval kept

## License

[MIT](LICENSE)
