---
topic: admin
subject: Safe Smart Account
checked: 2026-11-18
source: Safe, Introducing Safe v1.5.0, the safe-smart-account repository releases and changelog, the safe-core-sdk release that ships protocol-kit 7.0.0, and the safe-modules 4337 module changelog and `Safe4337Module` source
---

# Safe Smart Account 1.5.0 is the current release

Safe Smart Account 1.5.0, announced in July 2025, is the newest tagged release. It adds module guards, which check transactions that modules execute, and the Safe SDK's protocol kit supports it from version 7.
A Safe works as an ERC-4337 account through the separate `Safe4337Module`. Its newest release, 0.3.0 (re-tagged as 0.3.0-1 in June 2024 without contract changes), supports only EntryPoint v0.7.0 at 0x0000000071727De22E5E9d8BAf0edAc6f37da032, and each deployment of the module fixes its EntryPoint address in the constructor.

For a design:

- Hold admin, upgrader, and treasury roles in a Safe multisig, with the signers and the threshold written down
- Name the Safe version and whether modules or guards are used; a module can bypass the signers unless a module guard checks it
- When a Safe is the ERC-4337 account, pin `Safe4337Module` 0.3.0 and EntryPoint v0.7, and check that each bundler and paymaster the app uses supports v0.7
- Put a timelock between the Safe and the contracts for upgrades and parameter changes, so users can see a change before it runs
