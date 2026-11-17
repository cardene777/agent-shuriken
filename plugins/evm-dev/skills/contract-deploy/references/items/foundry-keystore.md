---
topic: keys
subject: Foundry encrypted keystores (cast wallet import and --account)
checked: 2026-11-17
source: Foundry, key management best practices and the forge script and cast wallet import references; forge 1.5.1 help output
---

# Foundry signs from an encrypted keystore that the user creates with cast wallet import

`cast wallet import <name> --interactive` asks for the private key at a prompt, so it never appears in the shell history, and stores it encrypted with a password in `~/.foundry/keystores/<name>`. `forge script`, `forge create`, and `cast send` then sign with `--account <name>`, asking for the password when they sign. `cast wallet list` shows the names. Foundry's key management guide recommends Anvil's default keys for local work only, an encrypted keystore for test networks, and a hardware wallet for mainnet, and says to keep keys out of plain environment variables.

For a deployment:

- The user runs `cast wallet import` in their own terminal; the agent never sees the key or the password
- Pass `--account <name>` and `--sender <address of that account>`, so the simulation uses the same sender as the broadcast
- `--password` puts the password in the shell history; `--password-file` and `ETH_PASSWORD` keep it in a file the user must protect, so prefer the prompt
- Anvil's default keys are public; never use them on a public network
