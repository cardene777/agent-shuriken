# Fill in: the name of the contracts and of this design

Fill in: one paragraph on what these contracts do, what assets they hold, and what this design leaves out.

Each section decides one part and points to the others instead of repeating them. Open decisions holds every decision, assumption, and open question; other sections link to it.

## Purpose and scope

Fill in: what the contracts do, who uses them (users, operators, administrators, other contracts), the assets they hold, the chains they run on, and what is out of scope.
Fill in: the limits that must hold, such as caps, minimums, time windows, and maximum losses.

## Contracts

Fill in: each contract and library, what it is responsible for, which contracts it calls and which call it, and why the split is drawn there.
Fill in: the library and its version (for example OpenZeppelin Contracts), the compiler version, the external contracts and services the design relies on, and the date each was checked, written as YYYY-MM-DD.

## Token standards

Fill in: each token the contracts issue or accept, its standard and extensions, decimals, supply, and minting and burning rules, and the status of each ERC as checked with the evm-standards skill.
Fill in: for each token the contracts accept from outside, the behavior they must cope with: no return value, approval reset to zero, fees on transfer, rebasing, pausing, blocklists, and upgrades by the issuer.

## State and invariants

Fill in: the state each contract keeps, its states and the transitions between them, and the events each transition emits.
Fill in: the invariants that must always hold, written so a test can check them (for example, the sum of balances equals the total), and how amounts are rounded and in whose favor.

## Roles and governance

Fill in: each role (owner, admin, minter, pauser, upgrader, treasury), the functions it may call, who holds it, and how it is granted, transferred, and revoked.
Fill in: what a pause stops and what it leaves working, which changes go through a timelock and its delay, and which can run at once.

## Upgrades

Fill in: whether each contract is immutable or upgradeable, and why; the proxy pattern; who may upgrade and through what delay; how the implementation's initializer is locked; and how the storage layout is kept compatible.
Fill in: how an immutable contract is replaced if a bug is found: migration, a new deployment, or a pause.

## Prices, ordering, and randomness

Fill in: where each price comes from, how stale or wrong prices are detected and what the contract does then, and on a rollup how sequencer downtime is handled.
Fill in: which outcomes depend on transaction order and how users are protected (minimum output, deadlines, commit-reveal, batch auctions), and where randomness comes from and why it cannot be predicted or chosen.
Fill in: what is left out because no price, ordering, or randomness is involved.

## External calls and failures

Fill in: every call to another contract or token, the order of checks, state changes, and calls, protection against reentrancy, and whether funds are pushed or pulled.
Fill in: what happens when a call fails or runs out of gas, the limits on loops and array sizes, and which functions anyone can call to move the system forward.

## Open decisions

Fill in: each open question and assumption, the candidates, what it affects, who decides, and by when or under what condition.
