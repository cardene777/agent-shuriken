---
tool: solc
since: 0.8.31
checked: 2026-11-18
source: Solidity changelog, 0.8.31, and the 0.8.31 release announcement
detect: \.(send|transfer)\((?:[^,()]|\([^()]*\))*\)
---

# address.send and address.transfer are deprecated

Solidity 0.8.31 warns about `send` and `transfer` on `address` values; the release announcement lists their removal among the features scheduled for the 0.9.0 breaking release.
Both forward only 2300 gas, which can fail when the receiver runs code, including a wallet with a delegation.

Send ether with a call and check the result:

```solidity
(bool ok,) = recipient.call{value: amount}("");
require(ok, TransferFailed());
```

Make the state change before the call, and guard the function against reentrancy.
`IERC20(token).transfer(to, amount)` is a token call with two arguments, not this function.
