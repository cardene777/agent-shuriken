# Review checklist for a contract design

Go through this list after `verify` passes. A design that fails any rule in the first table is not finished: fix it and check again. Say which rules you could not judge and why.

## Rules a design must never break

| Rule | What fails it |
|---|---|
| Every state change has an owner | A function that changes state does not say who may call it, or anyone may call a function that moves funds or changes parameters |
| Invariants are checkable | The design has no invariant, or states one that a test cannot check, such as "funds are safe" |
| Amounts are exact | Decimals of each token, the units of each amount, and the rounding direction are not stated, or rounding favors the caller over the contract |
| Initializers are locked | An upgradeable contract's initializer can be called twice, or the implementation does not call `_disableInitializers` in its constructor |
| Storage layout survives upgrades | Upgradeable contracts do not use ERC-7201 namespaced storage or another stated way to keep the storage layout compatible, or are upgraded across a major version of their library |
| Prices are checked | A price is used without checking that it is stale, zero, or out of bounds, or a contract on a rollup reads a price without checking the sequencer uptime feed |
| Randomness cannot be chosen | A valuable outcome uses `block.prevrandao`, `block.timestamp`, or a block hash as randomness, instead of a VRF or a commit-reveal that no single party controls |
| Order cannot be exploited | A trade, a purchase at a moving price, or a liquidation has no minimum output (slippage limit) and no deadline, or a first-come outcome can be front-run where commit-reveal or a batch is needed |
| Calls cannot reenter | State is changed after an external call instead of following checks-effects-interactions, or a function that sends funds has no reentrancy guard where callbacks are possible |
| Funds are pulled when pushing can fail | Paying many recipients in one call lets one failing recipient block the rest, instead of letting each pull their funds |
| Tokens are handled safely | Outside tokens are moved without SafeERC20, or the design assumes the received amount equals the sent amount for a fee-on-transfer or rebasing token it accepts |
| No single key controls everything | One externally owned account holds the owner, admin, or upgrader role on mainnet, ownership moves without a two-step transfer, or there is no pauser and no way to stop the contract in an emergency |
| Changes are delayed | Parameter changes and upgrades take effect at once instead of through a timelock, except a pause |
| Nothing depends on one keeper | Finishing a sale, a draw, or a period needs one off-chain service, instead of a function anyone can call once its time has come |
| Gas is bounded | A function loops over an unbounded array or mapping that users can grow |

## Rules to check with the team

| Area | Check |
|---|---|
| Split | Each contract has one responsibility, and the design says why two contracts are not one |
| Events | Every state change that users or indexers need emits an event with the values they need |
| Libraries | Each library and service named in Contracts carries the date it was checked, and a deprecated service is not chosen |
| Testing | The invariants and the failure cases are listed so the contract-tests skill can turn them into tests |
| Limits | Caps, minimums, and time windows are enforced by the contract, not only by the frontend |
