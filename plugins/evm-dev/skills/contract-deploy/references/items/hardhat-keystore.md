---
topic: keys
subject: Hardhat 3 keystore plugin and configVariable
checked: 2026-11-18
source: Hardhat, managing config values and secrets safely; Hardhat, hardhat-keystore plugin; Nomic Foundation, Hardhat 2.19.0 release introducing configuration variables
---

# Hardhat 3 reads secrets through configVariable from an encrypted keystore

In Hardhat 3, `hardhat.config.ts` names a secret with `configVariable("NAME")` instead of holding it, for example `accounts: [configVariable("SEPOLIA_PRIVATE_KEY")]`, and the value is read only when a task needs it. The `@nomicfoundation/hardhat-keystore` plugin, included in the Hardhat 3 sample projects, stores the values in an encrypted file in the user's home folder: `npx hardhat keystore set NAME` asks for the value and a password, and Hardhat asks for the password when the value is used. Its other tasks are `list`, `get`, `delete`, `change-password`, `path`, and `rename`. `keystore set --dev` writes to a separate keystore without a password, meant only for values that are not secret. Hardhat's guide says environment variables are not a safe place for secrets, for reasons including shell history. Hardhat 2's configuration variables (`vars.get`) are stored in plain text.

For a deployment:

- Write `configVariable` for every key and RPC URL in the config, and have the user run `npx hardhat keystore set` in their own terminal
- Never put a private key in the `--dev` keystore
- In a Hardhat 2 project, do not move keys into `vars`; use a hardware wallet or move the project to Hardhat 3
