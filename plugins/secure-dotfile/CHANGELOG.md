# Changelog

Releases of the secure-dotfile plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.6.0] - 2026-11-14

- `scan` and `move` take `--store 1password`, which moves each picked value into 1Password through the 1Password CLI `op`: it finds the vault `op` stores new items in, named Private, Personal, or Employee, with `op vault list`, sends the value to `op item create -` inside an item JSON template on standard input, reads it back with `op read -n`, and changes the line to `"$(op read 'op://VAULT/NAME/password' 2>/dev/null)"`, or the same inside `( )` in fish. A name that already holds a different value is skipped, and so is a name that two or more items in the vault share. When `op` is not signed in or no single vault has one of those names, the move stops with exit code 3 and changes nothing
- `scan` lists 1Password as a store to choose when `op` is installed, without running `op`; only a scan or move with `--store 1password` runs it
- The docs say why Bitwarden is not a store: its `bw` command reads only with the session key `BW_SESSION` in the environment, so a new shell would get an empty variable

## [0.5.0] - 2026-11-14

- `scan` and `move` take `--store pass`, which moves each picked value into your `pass` password store on any system: `pass insert -e` gets the value on standard input, `pass show` reads it back, and the line becomes `"$(pass show NAME 2>/dev/null)"`, or the same inside `( )` in fish. A name that already holds a different value is skipped, and so is a value that cannot be read back because the GPG key is locked, with the first line `pass` printed
- `scan` prints where the move would store values and the other stores that can be used here, such as `Also available: pass (add --store pass)`, and the agent asks which one to use when there is more than one
- The docs say that KWallet from KDE Frameworks 6 serves the secret service, so `secret-tool` reaches it, and how to turn that on again when it is off

## [0.4.0] - 2026-11-14

- `move` works on Linux: it stores each picked value in the secret service (GNOME Keyring, or KeePassXC with its secret service turned on) by passing it to `secret-tool store` on standard input, reads it back, and changes the line to `"$(secret-tool lookup service NAME account "$USER" 2>/dev/null)"`, or the same inside `( )` in fish. It skips a name that already holds a different value, and an item whose secret service cannot be reached, with `secret-tool`'s own message. Before, `move` stopped with exit code 3 on every system other than macOS
- Without `secret-tool`, `move` stops with exit code 3 and names it, and `scan` gives that as the reason an item cannot be moved
- `SECURE_DOTFILE_STORE` picks `keychain` or `secret-service` for tests against a throwaway store

## [0.3.0] - 2026-11-14

- `scan` lists passwords under names ending in `PASSWORD` or `PASSWD` without an underscore, such as `PGPASSWORD`, and in `_PASS`, `_PWD`, or `_PIN`, such as `MYSQL_PWD`. Before, these names were not read as secrets at all
- Values under those password names are listed at any length, and one shorter than 8 characters has the kind `short password`, with a suggestion in the report to make it longer. Before, every value shorter than 8 characters was skipped
- The report step, the README, and How it works say that a move takes a value out of the file, not out of the environment of the programs the shell starts, that a key with wide access is safer read only for the command that needs it, and that a key a team shares belongs in the team's password manager

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Lists API keys, tokens, and passwords written as literal values in zsh, bash, and fish startup files, `.envrc`, direnv `env.d` files, and the files they source, by name, location, kind, and length, without printing any part of a value
- Says whether each value is in the git history of its file, so you know which keys to rotate
- Moves only the items you pick into the macOS Keychain, reading each value back before changing the line to load it from the Keychain at shell startup
- Skips an item with a reason when its line changed, when the Keychain holds a different value under the same name, or when its value cannot be stored exactly
- Runs the shell's syntax check on every edited file and leaves the file as it was when the check fails
- Moves a secret in the chezmoi source file instead of the file chezmoi generates
- Starts when you mention a secret in your shell configuration, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/secure-dotfile--v0.6.0...HEAD
[0.6.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.6.0
[0.5.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.5.0
[0.4.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.4.0
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.3.0
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.1.0
