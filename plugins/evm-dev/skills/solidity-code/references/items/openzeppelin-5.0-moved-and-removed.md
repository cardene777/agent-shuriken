---
tool: openzeppelin
since: 5.0.0
checked: 2026-11-18
source: OpenZeppelin Contracts changelog, 5.0.0, and the published 5.0.0 package
detect: utils/Counters\.sol|utils/math/(Signed)?SafeMath\.sol|security/(Pausable|ReentrancyGuard)\.sol
---

# Counters and SafeMath are gone, and the security folder moved

OpenZeppelin Contracts 5.0.0 removed `Counters`, `SafeMath`, and `SignedSafeMath`, and moved `ReentrancyGuard` and `Pausable` to the `utils` folder.

| Before 5.0.0 | From 5.0.0 |
|---|---|
| `security/ReentrancyGuard.sol` | `utils/ReentrancyGuard.sol` |
| `security/Pausable.sol` | `utils/Pausable.sol` |
| `utils/Counters.sol` | A plain `uint256` counter |
| `utils/math/SafeMath.sol` | Solidity's checked arithmetic; the `try*` functions moved into `Math` |
