---
tool: openzeppelin
since: 5.7.0
checked: 2026-11-16
source: OpenZeppelin Contracts changelog, 5.7.0, and the npm registry
detect: draft-I?ERC4337
---

# ERC-4337 files lost their draft- prefix

OpenZeppelin Contracts 5.7.0 (2026-07-29) renamed the ERC-4337 files now that ERC-4337 is final.
The changelog says: "Imports must be updated from `account/utils/draft-ERC4337Utils.sol` to `account/utils/ERC4337Utils.sol` and from `interfaces/draft-IERC4337.sol` to `interfaces/IERC4337.sol`."

With 5.7.0 or later installed, import them without the prefix:

```solidity
import {PackedUserOperation} from "@openzeppelin/contracts/interfaces/IERC4337.sol";
import {ERC4337Utils} from "@openzeppelin/contracts/account/utils/ERC4337Utils.sol";
```

Before 5.7.0 the `draft-` paths are the right ones, so read the installed version first.
On npm, the `latest` tag of both OpenZeppelin packages still installs 5.6.1, and 5.7.0 is under the `dev` tag, so a fresh `npm install` gets 5.6.1 while `forge install` of the latest release gets 5.7.0.
