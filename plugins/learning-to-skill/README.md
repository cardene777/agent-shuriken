# Learning to Skill

Turn a lesson from a session into one short rule in the instruction files your agents read, so the next session does not repeat the mistake.

English · [日本語](README.ja.md)

When you correct an agent, the correction lives only in that chat, and the next session makes the same mistake.
Writing it down by hand means knowing which file each agent reads: Codex reads `AGENTS.md`, Claude Code reads `CLAUDE.md`, Gemini CLI reads `GEMINI.md`, GitHub Copilot CLI reads `.github/copilot-instructions.md` and `AGENTS.md`, and each skill has its own `SKILL.md`.
Copying the same rule into each of them makes the files grow and drift apart.
This plugin finds the files your project's agents actually read, including the links and `@` imports between them, picks the one that reaches the right agents, checks that the rule is not already there, and shows you the change as a diff.
It writes only the diff you approve, and never commits.

```
Write the rule ──> Find the files ──> Check for copies ──> Show the diff ──> Write it
 (agent)            (agent)            (agent)              (you approve)     (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install learning-to-skill@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add learning-to-skill@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install learning-to-skill@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/learning-to-skill/skills/learning-to-skill   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask the agent to keep a lesson, for example "remember this for next time", "add this to the project rules", or "is this already in our instructions?".
When you have corrected the same mistake twice, the agent may offer it, and it asks before doing anything.
You can also call it: run `/learning-to-skill:learning-to-skill` in Claude Code, or type `$` and pick **Learning to Skill** in Codex.
In GitHub Copilot CLI, write `/learning-to-skill` in your request, and in Gemini CLI, describe the task.

1. The agent writes the lesson as one short rule
2. The agent lists the instruction files in the project and which agents read each one
3. The agent picks the file and the section, and checks that no line already says the same
4. The agent shows you the diff, the agents that will read it, and any similar lines, and you approve it, change it, or skip it
5. The agent writes exactly the change you approved, and stops if the file changed in between

The list of files looks like this.

```text
Instruction files in ~/projects/shop

  AGENTS.md                          15 lines  Codex, GitHub Copilot CLI, Claude Code (imported by CLAUDE.md)
  CLAUDE.md                           1 line   Claude Code, GitHub Copilot CLI; imports AGENTS.md
  .claude/skills/release/SKILL.md     9 lines  Claude Code, GitHub Copilot CLI; 1 more .md file in the skill folder
  .github/copilot-instructions.md     2 lines  GitHub Copilot CLI
  web/AGENTS.md                       3 lines  Codex, GitHub Copilot CLI; for work in web/

Each agent, in every session
  Claude Code         CLAUDE.md, AGENTS.md (imported by CLAUDE.md)
  Codex               AGENTS.md
  GitHub Copilot CLI  AGENTS.md, CLAUDE.md, .github/copilot-instructions.md
  Gemini CLI          nothing (it reads GEMINI.md, which is missing)

AGENTS.md reaches the most agents: Claude Code, Codex, GitHub Copilot CLI.

Repeated lines
  - Run `pnpm build` before pushing.
    AGENTS.md:6, .github/copilot-instructions.md:1
```

A proposed change looks like this, and nothing is written until you approve it.

```text
File       AGENTS.md
Read by    Codex, GitHub Copilot CLI, Claude Code (imported by CLAUDE.md)
Placement  at the end of the section "Testing", after line 11
Size       15 -> 16 lines

--- a/AGENTS.md
+++ b/AGENTS.md
@@ -9,6 +9,7 @@
 
 - Run `pnpm test` for the unit tests.
 - Put new tests next to the code they test.
+- Run `pnpm test:e2e` before opening a pull request; the unit tests do not cover checkout.
 
 ## Style
 

Similar lines already in the instruction files: none

Fingerprint  56d1c6cf161bc716
```

## Where a lesson goes

| The lesson is about | Where the agent writes it |
|---|---|
| The whole project | The file that reaches the most of your agents, usually `AGENTS.md` |
| One folder | That folder's own `AGENTS.md` or `CLAUDE.md`, when it has one |
| One skill | That skill's `SKILL.md`, or the file next to it that covers the topic |
| One agent | That agent's own file, such as `CLAUDE.md` or `GEMINI.md` |
| You, in every project | Your own file in the home folder, such as `~/.claude/CLAUDE.md`, never a file other people read |

A rule is written once.
When one of your agents does not read the chosen file, the agent offers to make that agent's file point at it, for example `@AGENTS.md` in `CLAUDE.md`, instead of copying the rule.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file it reads, which agents it counts as readers, how similar lines are found, and how a change is written.
In short:

- It reads the instruction files in your project, the `SKILL.md` files under it, and `.gemini/settings.json`, skipping dependency and build folders, other repositories, and worktrees
- With `--home`, it also reads the instruction files and skill folders of Claude Code, Codex, Gemini CLI, and GitHub Copilot CLI in your home folder
- It writes only the change you approved, to the one file it names, and never commits
- It runs no other program, sends nothing anywhere, and keeps no files of its own

## License

[MIT](LICENSE)
