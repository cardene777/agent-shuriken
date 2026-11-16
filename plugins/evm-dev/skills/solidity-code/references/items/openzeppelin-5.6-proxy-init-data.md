---
tool: openzeppelin
since: 5.6.0
checked: 2026-11-16
source: OpenZeppelin Contracts changelog, 5.6.0
detect: new\s+(ERC1967Proxy|TransparentUpgradeableProxy)\s*(\{[^}]*\}\s*)?\(.*,\s*(""|''|new\s+bytes\(0\)|bytes\(""\)|hex"")\s*\)
---

# A proxy must be deployed with its initialize call

From OpenZeppelin Contracts 5.6.0 (2026-02-25), `ERC1967Proxy` and `TransparentUpgradeableProxy` "Mandate initialization during construction. Deployment now reverts with `ERC1967ProxyUninitialized` if an initialize call is not provided."

The constructors are `constructor(address implementation, bytes memory _data)` and `constructor(address _logic, address initialOwner, bytes memory _data)`.
Pass the encoded initializer, so deployment and initialization happen in one transaction and nobody can initialize the proxy first:

```solidity
address proxy = address(new ERC1967Proxy(implementation, abi.encodeCall(Vault.initialize, (owner))));
```

Deploying with empty data and calling `initialize` afterwards reverts from 5.6.0.
A proxy that must start uninitialized overrides the internal `_unsafeAllowUninitialized` to return true; do that only when the user asks for it.
