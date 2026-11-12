# How Learning to Skill works

English · [日本語](how-it-works.ja.md)

This page explains which files the plugin reads, which agents it counts as readers of each one, how it finds similar lines, and how it writes a change.
Everything here is done by `skills/learning-to-skill/scripts/learning_to_skill.py`, which uses only the Python standard library.
It runs no other program, does not use the network, and keeps no files of its own.

## The commands

| Command | What it does | Writes |
|---|---|---|
| `files` | Lists the instruction files, who reads each one, repeated lines, and files over the size budget | Nothing |
| `check --text <line>` | Lists the lines that say the same as the rule, or come close | Nothing |
| `propose --file <file> --text <line>` | Prints the diff of a change and a fingerprint of it | Nothing |
| `apply ... --expect <fingerprint>` | Writes the change, only when it still has that fingerprint | The one file named |

## Which files it reads

The project is the nearest folder at or above the current folder that holds `.git`, or the folder given with `--root`.
When no folder above holds `.git`, the current folder is the project.

It searches the project down to 8 folders deep and skips these folders.

| Skipped | Why |
|---|---|
| `node_modules`, `vendor`, `dist`, `build`, `out`, `target`, `venv`, `env`, `__pycache__`, `coverage`, `bower_components`, `Pods`, `DerivedData` | Dependencies and build output |
| Hidden folders other than `.claude`, `.github`, `.gemini`, and `.agents` | They do not hold agent instructions |
| A folder that holds its own `.git` | Another repository, a submodule, or a worktree, which has its own instructions |
| Symbolic links to folders | They can lead outside the project. Skills linked into an agent skill folder are the exception |

It collects these files and counts these agents as their readers.
These are the places each agent reads as this release knows them. Agents add places over time.

| File | Read by |
|---|---|
| `AGENTS.md` in any folder | Codex and GitHub Copilot CLI. Claude Code too when the project has no file named `CLAUDE.md`, as its recent versions do. Gemini CLI too when its settings name `AGENTS.md` |
| `AGENTS.override.md` in any folder | Codex, which reads it in place of the `AGENTS.md` in the same folder |
| `CLAUDE.md` in any folder, and `.claude/CLAUDE.md` | Claude Code. GitHub Copilot CLI also reads the `CLAUDE.md` at the project root |
| `CLAUDE.local.md` | Claude Code. It is personal and usually not committed |
| `GEMINI.md` in any folder, or the names its settings give | Gemini CLI. GitHub Copilot CLI also reads the `GEMINI.md` at the project root |
| `.github/copilot-instructions.md` | GitHub Copilot CLI |
| `.github/instructions/**/*.instructions.md` | GitHub Copilot CLI, only for the files its `applyTo` names |
| `.claude/rules/**/*.md` | Claude Code, only for the files its `paths` names when the frontmatter has `paths` or `applyTo` |
| `SKILL.md` | The agents of the skill folder it is in, as the next table shows. A `SKILL.md` anywhere else is listed as loaded by no agent, such as a skill the project ships |

A file in a subfolder applies only for work in that folder, and the list says so.

| Skill folder | Read by |
|---|---|
| `.claude/skills/<skill>/SKILL.md` | Claude Code and GitHub Copilot CLI |
| `.agents/skills/<skill>/SKILL.md` | Codex, Gemini CLI, and GitHub Copilot CLI |
| `.github/skills/<skill>/SKILL.md` | GitHub Copilot CLI |
| `.gemini/skills/<skill>/SKILL.md` | Gemini CLI |

The skills in these folders are found even when they are symbolic links to folders elsewhere, and the list counts the other `.md` files in each skill folder.

### Links, imports, and settings

| What | How it is read |
|---|---|
| A file that is a symbolic link | The agents that read the link read the file it points at, shown as `through the link <file>`. The agent view lists the file pointed at |
| `@<path>` in a file other than `SKILL.md` that Claude Code or Gemini CLI reads | When `@` starts a line or follows a space, sits outside code blocks and inline code, and the path names an existing file, the same agents read that file, shown as `imported by <file>`. Paths are relative to the file's folder, absolute, or start with `~/`. Imports are followed 5 levels deep |
| `.gemini/settings.json` | When `context.fileName` is a name or a list of names, Gemini CLI reads those names instead of `GEMINI.md` |

### The home folder

With `--home`, it also reads these files and lists the skills in these folders, each read in every project.
Without `--home`, it reads a file in the home folder only when a project file imports it with `@~/...`, or when you name the file to `propose` or `apply`.

| File | Read by |
|---|---|
| `~/.claude/CLAUDE.md` and `~/.claude/rules/**/*.md`, or the same under `CLAUDE_CONFIG_DIR` | Claude Code |
| `~/.codex/AGENTS.override.md`, or `~/.codex/AGENTS.md` when there is no override, or the same under `CODEX_HOME` | Codex |
| `~/.gemini/GEMINI.md`, or the names that `~/.gemini/settings.json` gives | Gemini CLI |
| `~/.copilot/copilot-instructions.md` | GitHub Copilot CLI |
| `~/.claude/skills/<skill>/SKILL.md` | Claude Code and GitHub Copilot CLI |
| `~/.codex/skills/<skill>/SKILL.md` | Codex |
| `~/.agents/skills/<skill>/SKILL.md` | Codex, Gemini CLI, and GitHub Copilot CLI |
| `~/.gemini/skills/<skill>/SKILL.md` | Gemini CLI |
| `~/.copilot/skills/<skill>/SKILL.md` | GitHub Copilot CLI |

## What the list shows

| Part | How it is made |
|---|---|
| A row per file | The number of lines, the agents that read it, and notes such as `for work in web/`, `imports AGENTS.md`, or `link to AGENTS.md` |
| Each agent, in every session | The files each agent reads in every session: files at the project root that are not limited to some files, and the home files with `--home`. Files it reads by name come first. When an agent reads nothing, the line names the file it would read |
| The file that reaches the most agents | Among those project root files, the one with the most readers. On a tie, the one listed first |
| Repeated lines | Lines that appear more than once across the files, or twice in one file, after normalizing (next section) and when at least 12 characters remain. Up to 20 are shown |
| Over the size budget | Files over 200 lines, or 500 lines for `SKILL.md`, and folders where the `AGENTS.md` files Codex reads from the project root down add up to more than 32 KiB, the default amount Codex reads (`project_doc_max_bytes`) |

## How similar lines are found

Only lines of text are compared: not headings, code blocks, YAML frontmatter, or the separator rows of tables.
Each line is normalized: the list marker and a checkbox are dropped, letters become lower case, punctuation becomes a space, and repeated spaces become one.

| Score | When |
|---|---|
| `same` | The normalized lines are equal |
| 0.90 or more | The shorter normalized line, of at least 12 characters, is contained in the other |
| 0 to 0.99 | Otherwise, the Dice coefficient of the pairs of adjacent characters with the spaces removed, so text without spaces between words, such as Japanese, compares as well |

A line counts as similar from 0.50, which `check --threshold` can change, and the 5 highest are shown.
The score measures shared characters, not meaning, so the agent reads every match.

## How a change is placed

`propose` and `apply` change only these files.

- Files inside the project, or inside `~/.claude` (or `CLAUDE_CONFIG_DIR`), `~/.codex` (or `CODEX_HOME`), `~/.gemini`, `~/.copilot`, and `~/.agents`
- Named `AGENTS.md`, `AGENTS.override.md`, `CLAUDE.md`, `CLAUDE.local.md`, `GEMINI.md`, `copilot-instructions.md`, `SKILL.md`, or a name that `.gemini/settings.json` gives, or ending in `.instructions.md`
- Or `.md` files under `.claude/rules/`, or in a folder that holds a `SKILL.md`, or up to four folders below one

The name is checked for the given path and for the file a link points at.
A file that is not UTF-8 text is left as it is.
A line whose normalized form is already a line of the file is refused, so the same rule is not added twice.

| Option | Where the lines go |
|---|---|
| `--section <heading>` | After the last line that is not blank in that section, which ends at the next heading with as many `#` signs or fewer |
| `--new-section <heading>` | A new heading at the end of the file, with as many `#` signs as the file's top headings and at least two, then the lines |
| `--after-line <n>` | Right after line n, as given |
| `--replace-line <n>` | In place of line n, as given |
| none of these | After the last line that is not blank, below any frontmatter |

With `--section` and at the end of the file, a list item that follows a list joins it, and anything else gets a blank line before it.
In an empty file, the lines start the file.
A blank line is added after the lines when the next line is not blank.
Headings are matched without regard to case, `#` signs, and punctuation, and headings inside code blocks or YAML frontmatter are not sections.
A heading that two sections share is refused, so the change never lands in the wrong one.

The file keeps its line endings: CRLF when it has any CRLF, otherwise LF.
It keeps a final newline when it had one, a new or empty file gets one, and a byte order mark stays.

## How a change is written

`propose` prints a fingerprint: the first 16 hexadecimal digits of the SHA-256 of the file's real path, its current content, and its content after the change.
`apply` takes the same arguments with `--expect`, works the change out again from the file as it is now, and writes only when the fingerprint is the same.
A different file content, other lines, or another place give another fingerprint, and then nothing is written.

| Step | What happens |
|---|---|
| 1 | For a new file, missing folders are created, and the file gets the permissions your `umask` allows |
| 2 | The new content goes into a temporary file named `.learning-to-skill-*` in the same folder, with the permissions of the original file |
| 3 | The original is read once more, and when it changed since the fingerprint was checked, the temporary file is removed and nothing is written |
| 4 | The temporary file replaces the real file in one step. When the given path is a link, the file it points at is replaced and the link stays |
| 5 | The file is read back and compared with the new content |

When writing fails, the temporary file is removed.

## What it keeps

Nothing.
The only files it writes are the instruction files whose change you approved, and the temporary file exists only while writing.

## What it never does

- Run git or any other program, commit, or push
- Write without a fingerprint from `propose`, or when the file changed after it
- Change a file other than an instruction file, or a file outside the project and the agents' folders in your home folder
- Send anything over the network

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | `check` found a similar line, or `propose` and `apply` refused the change: the line is already in the file, the section is missing, or two sections have that heading |
| 2 | Wrong input, such as a file that is not an instruction file, a missing file without `--create`, or a line break inside `--text` |
| 3 | `apply` found the file or the change different from the proposal, and wrote nothing |

## Environment variables

| Variable | Use |
|---|---|
| `CLAUDE_CONFIG_DIR` | Claude Code's folder in place of `~/.claude`, for `--home` and for which files can be changed |
| `CODEX_HOME` | Codex's folder in place of `~/.codex`, likewise |
