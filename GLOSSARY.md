# Glossary

Words this repository uses with one meaning.

| Word | Meaning |
|---|---|
| `agent-shared` | The command in `agent-shared/` that places the skills, rules, and hooks of one or more sources into every agent in the agent table |
| source | A folder with the `.shared` layout: `skills/<name>/SKILL.md`, `rules/*.md`, `hooks.json`, and an optional `agents.json` |
| `~/.shared` | The source that holds a person's own skills, rules, and hooks for every agent on the computer |
| a repository's `.shared` | The source in a repository's root whose skills are linked into that repository's `.claude/skills` and `.agents/skills` |
| agent table | The rows that name each agent and where it keeps skills, rules, and hooks: the default `agents.json` in the command, and the rows of `~/.shared/agents.json` |
| switch list | `off.json` beside the record: the rules and hooks of a source that `deploy` leaves out of one agent, written only by `agent-shared off` and `agent-shared on` |
| plugin | A folder under `plugins/` that installs through an agent's plugin command; plugins are separate from `agent-shared` |
| format skill | A skill that holds a document format other skills follow, such as `design-doc` in the `doc-formats` plugin. It writes nothing on its own |
| provider skill | A skill that provides content for other skills through musubi, listed under `provides` in its `musubi.json` |
| consumer skill | A skill that follows content another skill provides, listed under `follows` in its `musubi.json`, and reads it by opening that skill by name |
