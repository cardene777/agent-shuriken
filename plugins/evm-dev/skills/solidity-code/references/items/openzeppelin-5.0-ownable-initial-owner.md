---
tool: openzeppelin
since: 5.0.0
checked: 2026-11-18
source: OpenZeppelin Contracts changelog, 5.0.0
detect: \bOwnable\(\s*\)
---

# Ownable takes its first owner in the constructor

OpenZeppelin Contracts 5.0.0 added an `initialOwner` parameter to the `Ownable` constructor, "making the ownership initialization explicit", and rejects `address(0)` as the initial owner.
The constructor is `constructor(address initialOwner)`, so a contract that inherits `Ownable` passes the owner:

```solidity
constructor(address owner_) ERC20("Token", "TKN") Ownable(owner_) {}
```

`Ownable()` with no argument does not match the 5.x constructor.
