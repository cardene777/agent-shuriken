# Changelog

Releases of the agent-guards plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

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

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/agent-guards--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-guards--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-guards--v0.1.0
