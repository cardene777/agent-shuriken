# agent-shared

English · [日本語](agent-shared.ja.md)

`agent-shared` places the skills, rules, and hooks you keep in one folder into every coding agent on your computer.
Skills and rules are links to the one copy in that folder, so an edit reaches every agent at once.
Your folder stays on your computer, and the command sends nothing over the network.

## Install

The command needs [uv](https://docs.astral.sh/uv/) and runs on macOS and Linux.
uv installs only the command, not the plugins of this repository, and brings Python 3.11 or later when the computer has none.

```
uv tool install "git+https://github.com/cardene777/agent-shuriken#subdirectory=agent-shared"
uv tool upgrade agent-shared
```

The second line updates the command later.

## The source folder

Put your skills, rules, and hooks in `~/.shared`.

```
~/.shared/
  skills/<name>/SKILL.md   one folder per skill
  rules/*.md               instructions every agent reads
  hooks.json               hooks, written like the hooks in Claude Code's settings
  agents.json              optional rows that add an agent or move where one keeps its files
```

`hooks.json` has the `hooks` object of Claude Code's settings.
`${CLAUDE_PLUGIN_ROOT}` in a command becomes the path of the source folder, and `tools` sends a hook only to the agents it names.

```json
{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh", "tools": ["Claude Code"]}]}]}}
```

Then run the command.

```
agent-shared deploy
```

## Where each item goes

| Agent | Skills | Rules | Hooks | A repository's skills |
|---|---|---|---|---|
| Claude Code | a link per skill in `~/.claude/skills` | a link per rule in `~/.claude/rules` | `~/.claude/settings.json` | `.claude/skills` |
| Codex | a link per skill in `~/.agents/skills` | one block in `~/.codex/AGENTS.md` | `~/.codex/hooks.json` | `.agents/skills` |

GitHub Copilot CLI and Gemini CLI read the skills in `~/.agents/skills` too.
Codex also reads `~/.codex/skills`, which Codex keeps only for older setups, so the command places nothing there and a skill is not listed twice.
Codex runs a hook only after you trust it, so the command writes that trust through `codex app-server`, the same way Codex's `/hooks` screen does.
When the `codex` command is missing or does not answer, the command says so and asks you to open `/hooks` in Codex once.

## A repository's skills

A repository can keep its own skills in `.shared/skills`.
Running `agent-shared deploy` inside the repository, or with `--repo <folder>`, links them into the repository's `.claude/skills` and `.agents/skills` with relative links, so the links work in every clone.
A repository's rules stay in its `AGENTS.md`, and its `CLAUDE.md` reads them with the line `@AGENTS.md`.

## The agent table

The command carries a table of where each agent keeps its files.
A row in `~/.shared/agents.json` with a new name adds an agent, and a row with the name of a default row replaces it.

```json
{"version": 1, "agents": [{"name": "My agent", "skills": "~/.my-agent/skills"}]}
```

| Field | Meaning |
|---|---|
| `name` | The agent's name, also used by `tools` in `hooks.json` |
| `skills` | The folder that gets a link per skill |
| `repo_skills` | The folder in a repository that gets a link per repository skill |
| `rules` | `place` and `form`: `link` puts a link per rule in the folder `place`, `block` writes the rules in one block of the file `place` |
| `hooks` | `file` gets the hooks. `trust: codex-app-server` also writes Codex's trust for them |
| `plugins` | `claude` or `codex`: skills that a plugin installed in that agent already has are not placed for it |

## More than one source

`--source <folder>` adds another folder with the same layout to the run, for example the folder an app such as ikkan-studio keeps for its own skills and hooks.
Each source removes only what it placed itself, so deploy every source in one run.

```
agent-shared deploy --source ~/apps/my-tool/.shared
```

## Skills a plugin already has

When a plugin installed in Claude Code or Codex has a skill with the same name as one in your folder, the command does not place that skill for that agent and prints the skill and the plugin.
The agent lists each skill once, and the plugin you chose to install keeps working.

## What it reads, writes, and keeps

| Kind | Paths |
|---|---|
| Reads | The source folders, `~/.claude/plugins/installed_plugins.json`, `enabledPlugins` in `~/.claude/settings.json`, `~/.codex/config.toml`, and the skill folders under `~/.codex/plugins/cache`. `placed` reads only the record and the places in the agent table |
| Writes | The places in the agent table, only for what it placed itself |
| Keeps | `~/.local/share/agent-shared/placed.json`, readable only by you, which names each link it placed. `AGENT_SHARED_STATE` moves the folder |
| Runs | `codex app-server`, to write Codex's trust for the hooks it placed. `AGENT_SHARED_CODEX_BIN` names another `codex` command |
| Sends | Nothing over the network |

## How it tells its own entries apart

| Entry | Mark |
|---|---|
| Skill and rule links | The record names each link and the target it was given |
| The rules block | The lines `<!-- agent-shared begin source=<id> -->` and `<!-- agent-shared end source=<id> -->` around it |
| Hooks | The command's last line is the shell comment `# agent-shared 1 source=<id>` |

`<id>` is the first 12 hex digits of the SHA-256 of the source folder's real path.
Hooks you wrote by hand, skills you placed yourself, and the lines of `AGENTS.md` outside the block keep their bytes.

## Printing the hooks it places

`agent-shared hooks` prints, as JSON, the hook groups `deploy` adds to one agent's hook file, with the mark and the source folder filled in.
It writes nothing, so a guard that stops settings from being weakened can compare the agent's hook file with it instead of building the hooks a second way.

```
agent-shared hooks --agent "Claude Code"
agent-shared hooks --agent Codex --source ~/work/team-shared
```

It reads the same sources as `deploy`: `~/.shared` and every `--source` folder.
`--agent` takes a name from the agent table, and a hook whose `tools` leave that agent out is not printed.
A name the table does not have, and a call without `--agent`, end with exit status 2 and print nothing.

## Listing what a source placed

`agent-shared placed` prints, as JSON, the skills, rules, and hooks one source folder placed in each agent and that are still there.
It writes nothing, so an app that deploys its own folder, such as ikkan-studio, can list what each agent got without keeping a second copy of where each agent keeps its files.

```
agent-shared placed --source ~/apps/my-tool/.shared
agent-shared placed --source ~/.shared
```

```json
{
  "source": "/path/to/apps/my-tool/.shared",
  "agents": {
    "Claude Code": {
      "skills": ["review", "release-notes"],
      "rules": ["writing.md"],
      "hooks": [{"event": "PreToolUse", "matcher": "Bash", "command": "bash /path/to/apps/my-tool/.shared/hooks/guard.sh"}]
    },
    "Codex": {
      "skills": ["review", "release-notes"],
      "rules": ["writing.md"],
      "hooks": []
    }
  }
}
```

| Field | Meaning |
|---|---|
| `source` | The full path of the source folder |
| `agents` | Every agent in the agent table, in the table's order, each with `skills`, `rules`, and `hooks` |
| `skills` | The names of the skill links the source placed for that agent that still point where they were placed |
| `rules` | The file names of the rule links, or of the rules in the source's block of the rules file |
| `hooks` | Each hook with the source's mark: its `event`, the group's `matcher` when the group has one, and its `command` without the mark |

`--source` names one folder, and only what that folder placed is printed.
A skill that a plugin already has was never placed for that agent, so it is not listed.
A link you removed or pointed elsewhere, and a hook without the mark, are not listed either.
A folder that was never deployed lists every agent with empty lists and ends with exit status 0.
A call without `--source`, a folder that does not exist, a record or hook file that is not JSON, and a broken rules block end with exit status 2 and print nothing.

## When it refuses

The command checks the whole change first, and when anything is in the way it writes nothing, prints each reason, and exits 1.

| Reason | What to do |
|---|---|
| A skill or rule name is in two sources | Rename one of them |
| A place holds something the command did not place | Move it away, or rename your skill or rule |
| A place was filled from another source | Deploy both sources in one run |
| A hand-written hook has the same command as a declared one | Remove one of them |
| An agent's settings file is not JSON | Fix the file |
| The rules block in a file is broken | Remove its marker lines by hand |
| A rule has a line that starts like a marker | Change that line |

Exit status 0 means deployed, and 2 means the command line, a source folder, the agent table, or the record could not be used.
