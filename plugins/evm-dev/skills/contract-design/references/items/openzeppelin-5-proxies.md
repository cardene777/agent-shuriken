---
topic: upgrades
subject: OpenZeppelin Contracts 5.x proxies and upgradeable contracts
checked: 2026-11-18
source: OpenZeppelin, Contracts 5.x proxy API reference, Using with Upgrades, Backwards Compatibility, Upgrades Plugins pages Writing Upgradeable Contracts and Proxy Upgrade Pattern, and the openzeppelin-contracts-upgradeable repository at v5.7.0
---

# In OpenZeppelin 5.x each transparent proxy deploys its own admin

In OpenZeppelin Contracts 5.x, a `TransparentUpgradeableProxy` deploys its own `ProxyAdmin` when it is constructed, owned by the `initialOwner` passed to it, and the admin address is immutable. There is no shared `ProxyAdmin` for many proxies as in 4.x.
A `UUPSUpgradeable` implementation must override `_authorizeUpgrade` with an access check, or anyone can upgrade it.
A contract behind a proxy inherits from the `@openzeppelin/contracts-upgradeable` variants, such as `ERC20Upgradeable` and `AccessManagedUpgradeable`, which set state in initializers instead of constructors, because the implementation's constructor never runs in the proxy's storage. Interfaces and libraries still come from `@openzeppelin/contracts`.
The upgradeable contracts of 5.x keep their state in ERC-7201 namespaced storage, so new variables can be added and the inheritance order can change without moving storage. OpenZeppelin keeps the storage layout compatible across minor and patch releases, and says a live contract is never safe to upgrade from one major release to another.

For a design:

- Name the pattern (transparent, UUPS, or beacon) and who owns the `ProxyAdmin` or holds the upgrade role; with transparent proxies, the owner of each proxy's admin is that proxy's upgrader
- Build every contract behind a proxy from the `Upgradeable` variants, lock the implementation's initializer, and say which initializer each contract calls
- Do not plan an upgrade of a deployed 4.x proxy to a 5.x implementation; deploy new contracts and migrate instead
