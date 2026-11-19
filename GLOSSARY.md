# Glossary

Words this repository uses with one meaning.

| Word | Meaning |
|---|---|
| `agent-shared` | The command in `agent-shared/` that places the skills, rules, and hooks of one or more sources into every agent in the agent table |
| source | A folder with the `.shared` layout: `skills/<name>/SKILL.md`, `rules/*.md`, `hooks.json`, and an optional `agents.json` |
| `~/.shared` | The source that holds a person's own skills, rules, and hooks for every agent on the computer |
| a repository's `.shared` | The source in a repository's root whose skills are linked into that repository's `.claude/skills` and `.agents/skills` |
| agent table | The rows that name each agent and where it keeps skills, rules, and hooks: the default `agents.json` in the command, and the rows of `~/.shared/agents.json` |
| plugin | A folder under `plugins/` that installs through an agent's plugin command; plugins are separate from `agent-shared` |
