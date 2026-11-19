# 0001 agent-shared lives in agent-shuriken, and ikkan-studio calls it

## Decision

The command that deploys a person's skills, rules, and hooks to every coding agent is `agent-shared`, kept in this repository and installed with `uv tool install`.
It is the main feature of the repository, and the plugins are listed after it.
ikkan-studio keeps ikkan's own skills and hooks in a folder with the `.shared` layout and passes it to `agent-shared deploy --source`.

## Chosen

One public command that works from a terminal without any app, with one implementation that ikkan-studio and people without ikkan-studio both use.

## Rejected

| Option | Why it was not chosen |
|---|---|
| Move the deploy command into ikkan-studio | It would work only on computers that run the app, and people who use only this repository's plugins would still install each plugin once per agent |
| Build the command here and keep ikkan's own deploy command in ikkan-studio | The same work would have two implementations, and a fix would reach only one of them |
| Ship the command as a plugin | Each agent copies a plugin into its own cache, so the command would exist once per agent and versions could drift |
| Run the command from a clone of this repository | A clone brings every plugin's skills along with the command |

## Grounds

- Issue #250, whose decision section records each question and answer
- `.ikkan/premises/structure.md`, which places the command in `agent-shared/`
- Claude Code and Codex copy every installed plugin into their own cache, even from a local marketplace

## Date

2026-11-19
