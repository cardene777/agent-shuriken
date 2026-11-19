# Example: Vesting vault for a fixed-supply token

This design lets a team build one vault that holds part of a fixed-supply ERC-20 token and releases it to contributors over a cliff and a linear period. It covers the vault's contracts, token handling, state, roles, and failures. It leaves out the token itself, voting with unvested tokens, any token sale, and the frontend.

Each section decides one part and points to the others instead of repeating them. Open decisions holds every decision, assumption, and open question; other sections link to it.

## Purpose and scope

The vault holds the project token (TKN) for contributors, each with one or more schedules: a start, a cliff, a duration, and a total. Beneficiaries release what has vested; anyone may release for a beneficiary, and the tokens always go to the beneficiary. A scheduler adds and revokes schedules, a pauser stops releases in an emergency, and the vault runs on one chain (D1). Out of scope: other tokens, staking, and delegating votes.
Limits: no schedule allocates more than the vault's unallocated balance; nothing is released before the cliff; a beneficiary never receives more than has vested; a revocation takes back only the unvested part; a duration is at most four years (D7).

## Contracts

`VestingVault` keeps the schedules, computes what has vested, and sends TKN; it calls only the TKN contract and is called by beneficiaries, anyone releasing for them, the scheduler, and the pauser. `AccessManager` from OpenZeppelin keeps the roles and their execution delays, so the delays live outside the vault. One vault with many schedules replaces one contract per beneficiary, so the balance invariant is checked in one place.
OpenZeppelin Contracts 5.7.0 or a later 5.x release, from the item on OpenZeppelin Contracts 5.x access control checked 2026-11-18, with `SafeERC20` from the item on OpenZeppelin SafeERC20 checked 2026-11-18. The compiler version is pinned when the code is written (D2). The design relies on no oracle, randomness service, relay, or keeper.

## Token standards

TKN is an ERC-20 token; the evm-standards item on ERC-20, checked 2026-11-18, gives its status as `Final` and in use on mainnet. The vault issues no token. TKN's decimals, its fixed supply, and the absence of a mint function are taken from its deployed code (D4); amounts are in TKN's smallest unit.
The vault accepts only the TKN address fixed at deployment. It moves TKN with `SafeERC20`, so a missing return value is handled, and never approves anyone, so approval resets do not arise. Funding is a plain transfer into the vault, and a schedule can only take from the measured balance minus what is already allocated, so a fee on transfer cannot over-allocate. A token that rebases, pauses, blocks addresses, or is upgraded by its issuer is assumed away in D4.

## State and invariants

Each schedule keeps its beneficiary, total, start, cliff, duration, released amount, whether it is revocable, and the time it was revoked. Its states are Waiting (before the cliff), Vesting, Vested, Closed (all released), and Revoked; `ScheduleCreated`, `Released`, `BeneficiaryChanged`, `Revoked`, `Paused`, and `Unpaused` are emitted with the schedule ID and amounts.
- The TKN balance of the vault is at least the sum of total minus released over all schedules, with a revoked schedule's total cut to what had vested when it was revoked
- For every schedule, released is at most vested, and vested is at most total
- Vested is 0 before the cliff, never decreases over time, and equals total from start plus duration on
- Total, start, cliff, and duration never change after creation
Vested is total times elapsed time divided by duration, rounded down in favor of the vault; at the end the full total vests, so no remainder is left behind.

## Roles and governance

The scheduler role creates schedules and revokes revocable ones; a multisig holds it with an execution delay (D3), so each call is scheduled, visible, and can be cancelled before it runs. The same multisig is the manager's admin with the same delay, and the scheduler role carries a grant delay of that length, so no member can be added who calls without waiting.
The pauser role, a smaller guardian multisig, stops `release` and `createSchedule`; it cannot cancel scheduled operations or change any parameter, and a pause ends on its own after a set time, or earlier when the scheduler unpauses through its delay (D5). A beneficiary changes its address in two steps: it names the new address, and the new address accepts.

## Upgrades

The vault is immutable: it holds promises to beneficiaries, and an upgrade path would let the admin change them. With no proxy there is no initializer to lock and no storage layout to keep compatible; the constructor fixes the TKN address and the manager.
If a bug is found, the pauser stops releases, the team deploys a corrected vault for new schedules, and how existing beneficiaries are made whole is decided as in D6. No function moves allocated TKN out of the vault.

## Prices, ordering, and randomness

No price, oracle, or randomness is involved: amounts are fixed in TKN, and `block.timestamp` is read only as the current time.
Order cannot change an outcome: a release sends the beneficiary only its own vested TKN, whoever sends it first. A scheduled revocation is visible during the delay, and a beneficiary may release what has vested before it runs, which is intended.

## External calls and failures

The only external calls are TKN transfers to a beneficiary in `release`, TKN transfers to the treasury when unallocated TKN is withdrawn through the scheduler's delay, and reading the vault's TKN balance. Each function checks, then updates released or allocated amounts, then transfers, and carries a reentrancy guard.
Every beneficiary pulls its own TKN, so one failing beneficiary blocks no one else; if TKN refuses a beneficiary's address, that beneficiary moves the schedule to a new address. No function loops over schedules, and anyone can call `release` for any schedule, so nothing waits on a keeper.

## Open decisions

| ID | Decision or assumption | Candidates | Affects | Who decides | By when |
|---|---|---|---|---|---|
| D1 | Assumed: the vault runs on the chain where TKN lives, one chain only | One chain; a vault per chain | Purpose and scope | Token team | Before deployment |
| D2 | Compiler version, pinned to a release the chosen OpenZeppelin version supports | Newest supported release; the release the token used | Contracts | Contract developer | When the code is written |
| D3 | Scheduler multisig signers, threshold, and execution delay; assumed 3 of 5 and 3 days | 2 days; 3 days; 7 days | Roles and governance | Token team | Before deployment |
| D4 | Assumed from TKN's code: fixed supply, no mint, no fee, no rebase, no pause, no blocklist, not upgradeable, 18 decimals | Confirm by reading the code; refuse the vault if any is false | Token standards, State and invariants | Contract reviewer | Before deployment |
| D5 | Pause length and guardian threshold; assumed 14 days and 2 of 3, with no new pause for 7 days after one ends | 7 days; 14 days; until the scheduler unpauses | Roles and governance, Upgrades | Token team | Before deployment |
| D6 | How beneficiaries are made whole after a bug in the vested math | Fund a new vault from the treasury; leave correct schedules in place | Upgrades | Token team with beneficiaries | When a bug is found |
| D7 | Longest duration and cliff; assumed four years and one year | Shorter limits per contributor group | Purpose and scope | Token team | Before the first schedule |
