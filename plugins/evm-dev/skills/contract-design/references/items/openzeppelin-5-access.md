---
topic: access
subject: OpenZeppelin Contracts 5.x access control (Ownable2Step, AccessControl, AccessManager)
checked: 2026-11-18
source: OpenZeppelin, Introducing OpenZeppelin Contracts 5.0, the Contracts 5.x access API reference, and the openzeppelin-contracts repository at v5.7.0 (`AccessManager.sol`, `AccessManaged.sol`, CHANGELOG)
---

# OpenZeppelin 5.x offers three levels of access control

`Ownable2Step` keeps one owner and moves ownership only when the new owner accepts it, so a typo cannot hand the contract to a wrong address.
`AccessControl` gives each function a role, with an admin role for each role.
`AccessManager`, added in 5.0, keeps the permissions of many contracts in one manager: each function can be restricted to a role, and each member of a role can be given an execution delay, so that member's calls are scheduled and can be cancelled before they run. A role can also carry a grant delay, the time before a new member can use it, and a member granted with an execution delay of 0 calls without scheduling. Contracts that use `Ownable` or `AccessControl` can hand their ownership or admin role to a manager later.
A target's manager can be changed only by calls from its current manager, in two ways: an admin calls `AccessManager.updateAuthority`, or an admin has the manager `execute`, after `schedule` when a delay applies, the target's own `setAuthority`. In 5.7.0 both wait for the larger of the admin's execution delay and the target's admin delay; before 5.7.0 the `execute` path could skip the target's admin delay.

For a design:

- Use `Ownable2Step` only when one party should control everything; use roles when minting, pausing, upgrading, and treasury moves belong to different parties
- For a system of several contracts, consider `AccessManager` so the roles and their delays live in one place
- When a target's admin delay must also hold for a change of its manager, use 5.7.0 or later
- Name who holds each role on mainnet (a multisig, a timelock, or a governor), never an externally owned account alone for admin and upgrade
