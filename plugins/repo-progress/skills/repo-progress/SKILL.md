---
name: repo-progress
description: Shows where every repository the user works on stands, in one table, without changing anything. For each local clone with the user's commits it counts worktrees, open GitHub issues and pull requests, and uncommitted files, shows the time since the last commit, and puts stalled repositories first. For one repository it lists the branches in progress, the branches and worktrees to clean up, and the open issues nobody has started. Use when the user asks what they were working on, which repositories are active or stalled, what is left to do, or for an inventory of worktrees.
---

# Repo progress

This skill shows what is going on in every repository the user works on: which ones are moving, which have stalled with open issues, and which worktrees or branches point at work that is already done.
It reads each local clone with git and asks GitHub for the open issues and pull requests through `gh`.
It never changes a repository, a branch, a worktree, or an issue.

Talk to the user in the language they write in.
The commands and their output are the same in every language.

All commands live in `scripts/` next to this `SKILL.md`.
Below, `S` stands for the absolute path of that folder.
When running a command, put `S=<folder that contains this SKILL.md>/scripts` at the start of the same shell command.

This skill works in Claude Code, Codex, and other agents that read `SKILL.md`, such as GitHub Copilot CLI and Gemini CLI.
It reads folders outside the project and `gh` uses the network, so request approval for the commands when a sandbox blocks them, as Codex can.

## 1. Scan

```bash
S=<skill folder>/scripts; python3 "$S/repo_progress.py"
```

The script looks for git clones directly under each root folder and one level deeper, and keeps only the ones with a commit by the user.
It finds the user from `git config --global user.name` and `user.email`.
Without a root folder it uses common folders that exist, such as `~/projects`, `~/code`, `~/src`, `~/Developer`, and `~/Desktop/projects`.

| Exit code | Meaning | What to do |
|---|---|---|
| 0 | The table was printed | Go to step 2 |
| 1 | No repository with the user's commits was found | Ask the user which folders hold their repositories, then run `python3 "$S/repo_progress.py" --root <folder> --root <folder> --save-roots` so later scans remember them |
| 2 | The user's name is unknown | Ask the user for the name or email they commit with, and run again with `--author "<name>"` |

Add `--author "<name>"` when the user commits under a name other than their global git name, for example at work.
`python3 "$S/repo_progress.py" --show-roots` prints the folders a scan would use and where that list comes from.

## 2. Report

The table has one row per clone, with these columns.

| Column | Meaning |
|---|---|
| `repo` | The folder, relative to its root folder |
| `worktrees` | Linked worktrees, not counting the clone itself |
| `issues`, `prs` | Open issues and open pull requests on GitHub |
| `uncommitted` | Files with changes that are not committed |
| `idle` | Days since the last commit times open issues. High means many open issues and no recent work |
| `last commit` | Time since the last commit on the current branch |
| `now` | What the current branch points at: an issue, `no issue number`, `default branch`, or an issue that is no longer open |

Rows are sorted by `idle`, so stalled repositories come first.
`idle` does not say how important a repository is; it only measures how long open work has waited.

Sum up in a few sentences: the repositories that have stalled with the most open issues, the ones with uncommitted files, and the branches that point at issues that are no longer open.

A `?` means the value could not be measured, usually because `gh` is not installed, is not signed in, or the remote is not on GitHub.
Say that it is unknown, never that it is 0, and suggest `gh auth status` when every row shows `?`.
Repositories that could not be measured are listed last, and a line under the table counts them.

## 3. One repository

When the user asks about one repository, run the scan for it with the name from the `repo` column.

```bash
S=<skill folder>/scripts; python3 "$S/repo_progress.py" --repo <name>
```

| Section | Holds |
|---|---|
| In progress | Branches and worktrees whose name points at an open issue, or has no issue number, with the pull request opened from that branch |
| To clean up | Branches whose issue is no longer open, and worktrees whose folder is gone |
| Unknown | Numbered branches that could not be checked because the open issues could not be read |
| Waiting | Open issues that no branch points at |

A branch points at an issue when its name looks like `feat/12-login`, `12-login`, or `issue-12`.
Branches named after the default branch, such as `main`, are not listed.

Present the sections as they are.
The skill never deletes anything.
When the user wants a branch or worktree removed, treat it as a separate request: name each item, confirm it with the user, and check that its work is merged before removing it.

## 4. Other tools

`python3 "$S/repo_progress.py" --json` prints one JSON object per repository with the same values, `null` where a value could not be measured.
Use it when another tool or page needs the data.
