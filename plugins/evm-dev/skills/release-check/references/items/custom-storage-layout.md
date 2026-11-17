---
topic: layout
subject: Solidity's layout at, which moves a contract's storage to a chosen base slot
checked: 2026-11-17
source: Solidity documentation, Layout of State Variables in Storage (custom storage layout) and the 0.8.29 release notes; forge 1.5.1 and solc 0.8.30 run on a throwaway project
---

# layout at sets the slot where a contract's variables start

From solc 0.8.29, a contract can name a base slot after its name: `contract Vault is Base layout at 0x1000 { ... }`. Its state variables, the inherited ones first, then start at that slot instead of slot 0.

In a check with solc 0.8.30:

- A contract with `layout at 0x1000` that inherits one `uint256` and declares another showed them at slots 4096 and 4097 in `storageLayout`, so a layout comparison sees them as usual
- Inheriting from a contract that has `layout at` fails to compile, so only the most derived contract can have it
- A base written with `keccak256` fails to compile ("must evaluate to a rational number"); the base must be a number the compiler can work out, such as `0x1000`

For a release:

- Adding, changing, or removing `layout at` between versions moves every variable; the comparison reports each one as moved
