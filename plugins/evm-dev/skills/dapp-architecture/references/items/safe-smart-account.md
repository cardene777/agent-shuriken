---
topic: admin
subject: Safe Smart Account
checked: 2026-11-17
source: Safe, Introducing Safe v1.5.0 and the safe-smart-account repository README
---

# Safe Smart Account 1.5.0 is the current release

Safe Smart Account 1.5.0, announced in July 2025, is the newest tagged release. It adds module guards, which check transactions that modules execute, and the Safe SDK's protocol kit supports it from version 7.

For a design:

- Hold admin, upgrader, and treasury roles in a Safe multisig, with the signers and the threshold written down
- Name the Safe version and whether modules or guards are used; a module can bypass the signers unless a module guard checks it
- Put a timelock between the Safe and the contracts for upgrades and parameter changes, so users can see a change before it runs
