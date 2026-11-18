---
tool: openzeppelin
since: 5.5.0
checked: 2026-11-18
source: OpenZeppelin Contracts changelog, 5.5.0, and the published contracts-upgradeable 5.5.0 package
detect: contracts-upgradeable/(utils/ReentrancyGuard(Transient)?Upgradeable|token/ERC721/utils/ERC721HolderUpgradeable|token/ERC1155/utils/ERC1155HolderUpgradeable|proxy/utils/(Initializable|UUPSUpgradeable))\.sol
---

# Upgradeable contracts import the guards from @openzeppelin/contracts

OpenZeppelin Contracts 5.5.0 (2025-10-31) flagged `ERC721Holder`, `ERC1155Holder`, `ReentrancyGuard`, and `ReentrancyGuardTransient` as stateless and stopped generating their upgradeable copies.
The changelog says: "Developers using their upgradeable variants from `@openzeppelin/contracts-upgradeable` must update their imports to use the equivalent version available in `@openzeppelin/contracts`."
`utils/ReentrancyGuardUpgradeable.sol` and `utils/ReentrancyGuardTransientUpgradeable.sol` are not in the 5.5.0 upgradeable package.

`Initializable` and `UUPSUpgradeable` are also no longer generated; the upgradeable package keeps aliases that "redirect to the corresponding files in `@openzeppelin/contracts`", and "These aliases will be removed in the next major release."

From 5.5.0, an upgradeable contract imports these four from `@openzeppelin/contracts`:

```solidity
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
```

Contracts such as `OwnableUpgradeable` still come from `@openzeppelin/contracts-upgradeable`.
