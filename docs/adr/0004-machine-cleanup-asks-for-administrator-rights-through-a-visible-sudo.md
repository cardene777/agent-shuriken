# 0004. machine-cleanup asks for administrator rights through a sudo the agent runs in plain sight

## Decision

How `machine-cleanup` gets the person's approval to free rows that need administrator rights (system caches, system logs, apps root installed, and system launch daemons and systemd units), so that the agent never sees the password and an agent's command guard can still see the request.

## Chosen

The agent runs one command that starts with `sudo -A`, and sudo calls an askpass helper the plugin ships, which opens the operating system's password dialog.
The password goes from the dialog straight to sudo, never into the agent's output, and one approval frees every row the person picked.
Where sudo needs no password, as on many cloud machines, the agent runs `sudo -n` instead.
Where neither works, the rows keep their size on the page but cannot be picked, and show why.
A schedule never frees these rows, and a scan never asks for a password: it measures what it can read and shows `size unknown` for the rest.

## Rejected

| Option | Why not |
|---|---|
| A script opens the dialog itself (`osascript` with administrator privileges on macOS, `pkexec` on Linux) | The request happens inside the script, where an agent's command guard cannot see it, and WSL and many servers have no `pkexec` |
| Print one line for the person to type in their own terminal | It hands the freeing back to the person |
| Only measure and show the rows, or keep them out | Several gigabytes stay unfreed, or out of sight |
| Let a schedule free them | It needs a job that runs as root, which keeps administrator rights open all the time, and nobody is there to answer the dialog |

## Grounds

- Step 2 of #141 left these rows out because both ways in then on the table had a problem, and `machine-cleanup` said it never asks for or uses an administrator password.
- `sudo` in the command line is what an agent's command guard reads, and askpass is sudo's own way to take a password from a program other than the terminal.
- The approval has to work the same in any agent, Codex included, so nothing relies on one agent's hooks or secret prompts.
- Issue #143, decision table.

## Date

2026-11-24
