# How Repo Progress works

English · [日本語](how-it-works.ja.md)

This page explains how repositories are found, what each column means, how branches are classified, and what the plugin keeps.
Everything here is done by `skills/repo-progress/scripts/repo_progress.py`, which uses only the Python standard library, `git`, and `gh`.

## Which repositories it reads

It looks at each root folder and the folders directly inside it, then one level deeper, and keeps the ones that are git clones.
It does not look inside a clone for more clones, and it skips hidden folders and linked worktrees, which are shown under their main clone.

The root folders come from the first of these that is set.

| Source | Example |
|---|---|
| `--root` on the command line, repeatable | `--root ~/work --root ~/oss` |
| The `REPO_PROGRESS_ROOTS` environment variable, separated by `:` | `REPO_PROGRESS_ROOTS=~/work:~/oss` |
| The list saved with `--save-roots` | `~/.local/share/repo-progress/roots` |
| Common folders in your home folder that exist | `projects`, `code`, `src`, `dev`, `Developer`, `repos`, `workspace`, `work`, `git`, `Documents/GitHub`, `Desktop/projects`, `Desktop/work` |

A clone is listed only when one of its branches has a commit whose author matches your name or email, compared as plain text with `git log --author`.
The name and email come from `git config --global user.name` and `user.email`, or from `--author` or `REPO_PROGRESS_AUTHOR` when set.
When none of them is set, the script stops with exit code 2 instead of listing every clone or none.

## The columns

| Column | How it is measured |
|---|---|
| `repo` | The clone's folder, relative to its root folder, so two clones of the same repository stay apart |
| `worktrees` | Entries in `git worktree list`, not counting the clone itself |
| `issues` | Open issues from `gh issue list --state open`, up to 500 |
| `prs` | Open pull requests from `gh pr list --state open`, up to 200 |
| `uncommitted` | Lines of `git status --porcelain`, one per changed or untracked file |
| `idle` | Whole days since the last commit on the current branch, times `issues` |
| `last commit` | Time since the last commit on the current branch |
| `now` | How the current branch is classified, as the next section describes |

Rows are sorted by `idle`, highest first.
A repository with no open issues, or with a commit today, scores 0, because it is either done or moving.
`idle` does not measure importance: neither git nor GitHub records how much a repository matters.

`gh` is asked once per GitHub repository, even when the repository is cloned in several folders, and up to 8 repositories are asked at the same time.
The remote `origin` decides the repository; a remote on another host is passed to `gh` with its host name.

## When GitHub cannot be asked

When `gh` is missing, is not signed in, fails, or the remote is not on GitHub, `issues`, `prs`, and `idle` show `?` and `--json` prints `null`.
They are never shown as 0, because 0 open issues would mark every numbered branch as finished and suggest cleaning up work in progress.
Such repositories are listed after the others, and a line under the table counts them.

## How branches are classified

A branch points at an issue when its name is `<prefix>/<number>-<words>`, `<number>-<words>`, or `issue-<number>`, for example `feat/12-login`.

| Class | When |
|---|---|
| In progress | The branch points at an open issue, or has no issue number |
| To clean up | The branch points at an issue that is not open, or the worktree's folder is gone (`prunable`) |
| Unknown | The branch points at an issue, but the open issues could not be read |
| Not listed | The default branch, such as `main`, `master`, `develop`, `trunk`, or the branch `origin/HEAD` names |

An issue that is not in the open list is either closed or does not exist; both mean the branch's work is over, so the script does not ask about each number.
`--repo` lists the branches of the clone and of every linked worktree in these classes, with the open pull request whose head is the branch.
Waiting issues are the open issues that no branch in progress points at, so one issue is never counted twice.
Local branches without a worktree are not listed, because old branches pile up and do not show what is in progress.

## What it keeps

| What | Where | Until |
|---|---|---|
| The root folders you saved with `--save-roots` | `~/.local/share/repo-progress/roots`, in a folder readable only by you, or under `REPO_PROGRESS_HOME` when set | You delete it or save another list |

Nothing else is written.
The output goes only to the terminal.

## What it never does

- Change a repository: it runs only `git log`, `git status`, `git branch --show-current`, `git worktree list`, `git remote get-url`, `git symbolic-ref`, and `git config --global` to read your name
- Read the contents of your files
- Delete or move a branch or worktree, or change an issue or pull request
- Send anything other than the repository names that `gh` needs to list open issues and pull requests

## Environment variables

| Variable | Use |
|---|---|
| `REPO_PROGRESS_ROOTS` | Root folders, separated by `:` |
| `REPO_PROGRESS_AUTHOR` | The author whose commits mark a repository as yours |
| `REPO_PROGRESS_HOME` | Where the saved roots are kept |
| `REPO_PROGRESS_GH` | A command used instead of `gh`, for tests |
| `REPO_PROGRESS_NOW` | A fixed time in seconds since 1970, for tests |
