# Repo Progress

See where every repository you work on stands in one table: what is moving, what has stalled with open issues, and which worktrees point at work that is already done.

English · [日本語](README.ja.md)

When you work on many repositories at once, the state is scattered.
Open issues and pull requests live on GitHub, while worktrees, uncommitted files, and the last commit live in each clone.
This plugin reads every clone with your commits under your project folders, asks GitHub for the open issues and pull requests, and puts it all in one table, with the repositories that have waited longest on open issues first.
It never changes a repository, a branch, a worktree, or an issue.

```
Find your clones ──> Read git and GitHub ──> Show the table ──> Show one repository
 (agent)              (agent)                 (agent)             (agent, when you ask)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install repo-progress@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add repo-progress@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install repo-progress@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/repo-progress/skills/repo-progress   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask what you were working on, for example "what was I in the middle of across my repos?" or "which projects have stalled?".
You can also call it: run `/repo-progress:repo-progress` in Claude Code, or type `$` and pick **Repo Progress** in Codex.
In GitHub Copilot CLI, write `/repo-progress` in your request, and in Gemini CLI, describe the task.

1. The agent finds the git clones with your commits directly under your project folders and one level deeper
2. The agent shows one row per clone and sums up what has stalled, what has uncommitted files, and which branches point at closed issues
3. When you ask about one repository, the agent lists its branches in progress, the branches and worktrees to clean up, and the open issues nobody has started

The table looks like this.

```text
repo            worktrees  issues  prs  uncommitted  idle  last commit  now
shop                    2      14    1            0   294  21 days ago  default branch
blog                    0       4    0            2    12   3 days ago  #1 Dark mode
clients/portal          0       6    0            0     0    0 min ago  default branch
dotfiles                0       ?    ?            0     ?  40 days ago  default branch

1 repository could not be measured and is listed last (idle is ?).
```

`idle` is the days since the last commit times the open issues, so a repository with many open issues and no recent work comes first.
`?` means GitHub could not be asked, for example because the remote is not on GitHub or `gh` is not signed in; it is never shown as 0.

One repository looks like this.

```text
acme/shop
  folder       shop
  branch       main
  uncommitted  0 files
  last commit  21 days ago

  [In progress]
    feat/1-partial-refund                        #1 Refund partial orders  (pull request #31)

  [To clean up]
    fix/40-old-tax                               #40 is not an open issue

  [Waiting] 13 issues
    #2       2033-05-02 Task 2
    #3       2033-05-03 Task 3
    #4       2033-05-04 Task 4
    #5       2033-05-05 Task 5
    #6       2033-05-06 Task 6
    #7       2033-05-07 Task 7
    #8       2033-05-08 Task 8
    #9       2033-05-09 Task 9
    #10      2033-05-10 Task 10
    #11      2033-05-11 Task 11
    #12      2033-05-12 Task 12
    #13      2033-05-13 Task 13
    #14      2033-05-14 Task 14
```

## Project folders

Without settings, the plugin looks in common folders that exist in your home folder, such as `~/projects`, `~/code`, `~/src`, `~/Developer`, and `~/Desktop/projects`.
If your repositories live elsewhere, tell the agent the folders and it saves them for later scans.
A repository counts as yours when it has a commit by your `git config --global user.name` or `user.email`, and you can name another author, for example the one you use at work.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always |
| `git` | Always |
| `gh` | For open issues and pull requests, signed in to GitHub. Without it those columns show `?` and everything else still works |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains how repositories are found, how branches are classified, and the idle score.
In short:

- It reads the git data of the clones under your project folders: commits, branches, worktrees, and which files have uncommitted changes, not their contents
- It runs `gh issue list` and `gh pr list` once per GitHub repository, which sends the repository names to GitHub through your own `gh` sign-in
- It never changes a repository, a branch, a worktree, or an issue
- It keeps only the folders you save, in `~/.local/share/repo-progress/roots`, readable only by you, until you delete it

## License

[MIT](LICENSE)
