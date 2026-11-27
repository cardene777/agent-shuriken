# Changelog

Releases of the agent-guards plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- Every Bash check reads a command in the body of `if`, `while`, `until`, and `for`, in an `else` or `elif` branch, after `!` and `coproc`, and inside a backtick, a `$(...)` in double quotes, and a `<(...)` or `>(...)` process substitution, so `if true; then rm -rf ~; fi`, `` echo `git reset --hard` ``, and `echo "$(cat ~/.ssh/id_ed25519)"` are refused like the plain commands. Text in single quotes stays text
- The process check refuses ending a terminal app, such as Terminal, iTerm2, ghostty, wezterm-gui, alacritty, kitty, gnome-terminal-server, konsole, or xterm, with `killall`, `pkill`, or `kill`, since it closes the agent's own window
- The process check no longer refuses `kill <PID> 2>&1` and other commands with a redirect, which it read as PID 1, and it passes a `kill -0` probe whose target comes from a variable, such as `kill -0 $PPID`
- The process check reads every `-s` and `-n` option of `kill`, so `kill -0 -s 9 1`, which sends SIGKILL to PID 1, is refused instead of passing as a probe, and a second signal word, as in `kill -0 -9 1`, is judged as ending processes

## [0.5.0] - 2026-11-27

- The delete hook refuses `kill` of PID 1, PID 0, or a negative PID such as `-1`, `kill` of a system process such as launchd, WindowServer, Finder, systemd, or sshd, `pkill` and `killall` of a system process or that pick processes only by user, and targets taken from a variable or a command substitution. It asks `ps` and `pgrep` which processes a command names. Turn it off with `AGENT_GUARDS_PROCESSES=off`

## [0.4.0] - 2026-11-27

- The delete hook also refuses writing over a place in `~/.config/agent-guards/protected-paths`: `cp`, `install`, `ln`, `rsync`, `scp`, or `mv` into it (also with `-t` or `--target-directory`), `tee`, `dd of=`, `sed -i`, `truncate`, and redirects into it, and `git rm` of it. Copying out of the place and the agent's Write and Edit tools stay allowed

## [0.3.0] - 2026-11-27

- The secret write hook refuses a write through a file that has a second name (hard link), since a harmless name can overwrite a key file under its other name. Turn it off with `AGENT_GUARDS_HARD_LINKS=off`
- The secret write hook refuses a key written into a shell startup file such as `.zshrc`, `.bashrc`, `.profile`, or the fish config, also in a dotfiles folder or under a chezmoi source name, by the file tools, a Codex patch, or a command such as `echo ... >> ~/.zshrc`. Turn it off with `AGENT_GUARDS_STARTUP_KEYS=off`
- The outbound hook refuses chain transactions sent to a target that is not on this machine: `cast send`, `cast publish`, the sending forms of `cast rpc` and `cast erc20-token`, `forge script --broadcast`, `forge create`, and `hardhat ignition deploy`. Turn it off with `AGENT_GUARDS_CHAIN=off`
- With a list of your GitHub owners in `~/.config/agent-guards/own-owners`, the outbound hook refuses issues, pull requests, comments, reviews, and edits sent with `gh` or `gh api` to repositories of other owners, a `git push` to them, GraphQL mutations, and repositories held in variables. Turn it off with `AGENT_GUARDS_OTHER_REPOS=off`
- The delete hook refuses `mount`, `umount`, `chroot`, `pfctl`, `mkfs`, and `osascript` running a shell script with administrator privileges. Turn it off with `AGENT_GUARDS_SYSTEM=off`
- The new checks run in the process of the hook they belong to, so no hook starts on a call that did not start before, and a hook exits at once only when every check it runs is off

## [0.2.1] - 2026-11-26

- The hooks skip the value of a wrapper option, so `sudo -u root rm -rf /`, `nice -n 10 op read`, and `env -C /tmp git push --force` are judged like the command alone, and they read the string of `env -S`, the command `xargs` runs, each command after `find -exec`, `-execdir`, `-ok`, and `-okdir`, and the text `watch` runs. The secret read hook refuses `find -exec` that hands a found secret file to a reader through `{}`

## [0.2.0] - 2026-11-25

- A secret write hook refuses writes to `.env` files, key files, and the places in `secret-paths` from a shell command (`>`, `>>`, `tee`, `cp`, `mv`, `sed -i`, `truncate`, `dd`), the Write, Edit, MultiEdit, and NotebookEdit tools, and a Codex patch. Turn it off with `AGENT_GUARDS_SECRET_WRITE=off`
- A 1Password hook lets through only the `op` commands that print no stored value and delete nothing, such as `op whoami`, `op item list`, and `op document create`, and refuses `op read`, `op item get`, `op run`, `op signin`, and the rest. Turn it off with `AGENT_GUARDS_ONEPASSWORD=off`
- The delete hook also refuses `chmod -R`, `chown -R`, and `chgrp -R` on the root, the home folder, the current folder, system folders, and the places in `protected-paths`

## [0.1.0] - 2026-11-24

- Four hooks for Claude Code and Codex that run before each shell command and file read: secret read, outbound, git, and delete
- The secret read hook refuses reads of `.env` files, private keys, credential files, shell histories, the private data of macOS apps, and Claude Code's conversation records, and refuses a read whose file comes from a variable or a command substitution
- The outbound hook refuses `gh` sends and `git commit` whose command, body file, or staged change holds a key-shaped value, naming the kind and the line without the value, and refuses a body it cannot read
- The git hook refuses force pushes, `git reset --hard`, `--no-verify`, `git clean -f`, and commands that throw away uncommitted changes, and the delete hook refuses deletes of the root, the home folder, the current folder, and system folders; both show the refused command with a leading `!`
- `~/.config/agent-guards/secret-paths` and `protected-paths` add your own places, each hook turns off with its own `AGENT_GUARDS_*` variable, and `AGENT_GUARDS_RECORD=on` writes one line per refusal

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/agent-guards--v0.5.0...HEAD
[0.5.0]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-guards--v0.5.0
[0.4.0]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-guards--v0.4.0
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-guards--v0.3.0
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-guards--v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-guards--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-guards--v0.1.0
