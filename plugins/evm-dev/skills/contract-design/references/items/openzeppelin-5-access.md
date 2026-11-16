---
topic: access
subject: OpenZeppelin Contracts 5.x access control (Ownable2Step, AccessControl, AccessManager)
checked: 2026-11-17
source: OpenZeppelin, Introducing OpenZeppelin Contracts 5.0 and the Contracts 5.x access API reference
---

# OpenZeppelin 5.x offers three levels of access control

`Ownable2Step` keeps one owner and moves ownership only when the new owner accepts it, so a typo cannot hand the contract to a wrong address.
`AccessControl` gives each function a role, with an admin role for each role.
`AccessManager`, added in 5.0, keeps the permissions of many contracts in one manager: each function can be restricted to a role, and a role can carry an execution delay, so a change is scheduled and can be cancelled before it runs. Contracts that use `Ownable` or `AccessControl` can hand their ownership or admin role to a manager later.

For a design:

- Use `Ownable2Step` only when one party should control everything; use roles when minting, pausing, upgrading, and treasury moves belong to different parties
- For a system of several contracts, consider `AccessManager` so the roles and their delays live in one place
- Name who holds each role on mainnet (a multisig, a timelock, or a governor), never an externally owned account alone for admin and upgrade
