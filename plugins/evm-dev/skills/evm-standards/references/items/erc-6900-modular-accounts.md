---
status: specified
checked: 2026-11-18
source: ethereum/ERCs: the ERC-6900 document and its change history; alchemyplatform/modular-account: the README and the release notes
can: Smart accounts can take add-on modules through common interfaces, so one module works with many accounts.
---

# ERC-6900 (smart accounts that take add-on modules)

A standard that defines the interfaces between smart accounts and the parts (modules) added to them.
It lets any module be installed in any account that follows the standard.

| Point | What the document says |
|---|---|
| What a module has | Execution functions, validation functions, and hooks. Validation hooks run before a validation function, and execution hooks run before and after an execution function |
| Module manifest | A module's `manifest` lists the execution functions, interface IDs, and hooks to install in the account |
| Standards it relies on | Follows ERC-4337, and assumes ERC-165 and ERC-1271 |

## Current status

The document's status is `Draft`, and it was created on 2023-04-18.
The 0.7.0 document of 2024-01-25 calls modules `plugin`, and the current document calls them `module`.
According to the change history, a v0.8.0 release candidate was merged on 2024-10-15.

According to the release notes of Alchemy's Modular Account, v2.0.0 was released on 2025-03-18.
The README says it follows ERC-6900 v0.8.0 and ERC-4337 v0.9.0, and requires that only the `SemiModularAccount7702` implementation be used as the target of an EIP-7702 delegation.
The view that v2 stopped following ERC-6900 differs from what the README says.

## Not yet shipped

It is not `Final`.
There is a record of interfaces being renamed after v0.8.0 (2025-03-21), so the interfaces are still changing.
Which accounts outside Alchemy follow this standard has not been checked.
