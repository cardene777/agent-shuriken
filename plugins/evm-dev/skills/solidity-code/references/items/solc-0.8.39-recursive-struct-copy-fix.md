---
tool: solc
since: 0.8.39
checked: 2026-11-23
source: Solidity 0.8.39 release notes and release announcement, the write-up of the overlapping recursive storage struct copy bug, and the Solidity bug list entries of SOL-2026-8
---

# Solidity 0.8.39 fixes a storage corruption when a recursive struct is overwritten by a struct nested in it

The Solidity 0.8.39 release announcement (2026-11-19) fixes a bug that silently corrupts storage when a recursive struct in storage is overwritten by copying a struct nested inside it.
The bug list gives it as SOL-2026-8, severity medium, in two entries: `OverlappingRecursiveStorageStructCopyCorruption` for 0.4.9 to 0.8.38 on the default pipeline, and `OverlappingRecursiveStorageStructCopyCorruptionViaIR` for 0.8.13 to 0.8.38 with `via_ir`.
It does not depend on the optimizer settings or the EVM version.

It happens when a struct that refers to its own type through a dynamic array, or an array of such structs, is copied from storage to storage and the target contains the source, as in `root = root.children[0]` or `roots = roots[0].children`.
The overlap is not always visible in the assignment, for example when the source is reached through a storage pointer, a mapping key, or an array index.
The elements nested in the source are lost, the members declared after the array read back as zero, and no error is reported.

When a contract built on a version from 0.4.9 to 0.8.38 copies a recursive struct between storage locations where the target may contain the source, suggest moving to 0.8.39 or later, and say why.
The write-up asks a contract that made such a copy to review the affected storage for corruption after upgrading.
Solidity scanned the verified contracts in Sourcify and found no deployed contract that makes an affected copy.

0.8.39 adds a runtime overlap check to every storage-to-storage copy of a recursive struct, so copies that do not overlap also cost more gas, growing with the number of nested structs the target holds.
The opposite direction, where the source contains the target (`root.children[0] = root`), stays unsupported and may revert.

0.8.39 also fixes nested tuple assignments that swap values, which happen only in the default pipeline; `via_ir` and the optimizer settings do not matter.
It hits a string literal in a nested tuple on the right that is assigned to a `bytes32`, `bytes`, or `string` variable: with `bytes32 z` and `uint256 a`, `((z, a), b) = (("x", 111), 222)` assigns 111 to `z` and `bytes32("x")` to `a`, with no error or warning.
The announcement does not consider it a security issue, and the bug list has no entry for it.
The announcement also says 0.8.39 is likely the last release of the 0.8 series, and that the next release will be 0.9.0.
