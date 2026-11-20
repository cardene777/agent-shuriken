---
name: repo-progress
description: Shows where every repository the user works on stands, in one table, and what is left in one repository, without changing anything. Use when the user asks what they were working on, which repositories are active or stalled, what is left to do, or which branches and worktrees to clean up.
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

It reads folders outside the project and `gh` uses the network, so request approval for the commands when a sandbox blocks them, as Codex can.

## 1. Scan

```bash
S=<skill folder>/scripts; python3 "$S/repo_progress.py"
```

The script keeps only the clones with a commit by the user, whom it finds from the global git name and email.
When it exits with code 1, no repository with the user's commits was found. Ask the user which folders hold their repositories, then run `python3 "$S/repo_progress.py" --root <folder> --root <folder> --save-roots` so later scans remember them.
When it exits with code 2, the user's name is unknown. Ask the user for the name or email they commit with, never guess it from an account or address you know, and run again with `--author "<name>"`.
Add `--author "<name>"` when the user commits under a name other than their global git name, for example at work.
`python3 "$S/repo_progress.py" --show-roots` prints the folders a scan would use and where that list comes from.

## 2. Report

When the `page-design` skill is installed, write the report in the `structure` format of the `page-design` skill: open the `page-design` skill by name and read the file it names for `structure`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `page-design` skill is not installed, go on without the `structure` of `page-design`.

The plugin's `docs/how-it-works.md` describes each column of the table.
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

It lists the branches and worktrees in progress, the ones to clean up, the numbered branches it could not check, and the open issues that no branch points at; `docs/how-it-works.md` says how each branch is classified.
Present the sections as they are.
The skill never deletes anything.
When the user wants a branch or worktree removed, treat it as a separate request: name each item, confirm it with the user, and check that its work is merged before removing it.

## 4. Other tools

`python3 "$S/repo_progress.py" --json` prints one JSON object per repository with the same values, `null` where a value could not be measured.
Use it when another tool or page needs the data.
