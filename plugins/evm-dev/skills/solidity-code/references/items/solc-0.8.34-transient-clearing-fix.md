---
tool: solc
since: 0.8.34
checked: 2026-11-18
source: Solidity blog, Transient Storage Clearing Helper Collision Bug, and the Solidity bug list entry SOL-2026-1
---

# Clearing transient variables was miscompiled on via-IR before 0.8.34

The Solidity blog post of 2026-02-18 says: "The bug affects compiler versions 0.8.28 through 0.8.33 when using the IR pipeline." and "The bug is fixed in Solidity 0.8.34." Its severity is high.
The bug list entry `TransientStorageClearingHelperCollision` applies with `viaIR` on and an EVM version of Cancun or later.
It needs both `delete` on a transient variable and a clearing of persistent storage that involves a matching value type (`delete`, `pop()`, or a shorter array overwriting a longer one) in the same bytecode; the two clearing helpers then share one name, and only one of the two locations is cleared.

When a project compiles with `via_ir` on 0.8.28 to 0.8.33 and clears a transient variable with `delete`, move it to 0.8.34 or later.
The post notes that assigning the zero value (for example `_lock = 0`) does not trigger the bug.
