---
tool: solc
since: 0.8.35
checked: 2026-11-18
source: Solidity 0.8.35 release announcement
---

# erc7201() computes a namespaced storage slot

Solidity 0.8.35 (2026-04-29) added the builtin `function erc7201(string memory id) returns (uint)`, "equivalent to `keccak256(keccak256(id) - 1) & ~0xff`", the ERC-7201 formula.

```solidity
contract MyContract layout at erc7201("openzeppelin.storage.MyContract") { }
```

On 0.8.35 or later it can replace a hand-written slot constant; follow the project's existing style where one is set.
The same release warns when `at`, `error`, `layout`, `leave`, `super`, `this`, or `transient` are used as names in declarations, since they are planned to become keywords in 0.9.0.
