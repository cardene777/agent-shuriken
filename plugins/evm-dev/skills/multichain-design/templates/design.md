# Fill in: the name of the app and of this design across chains

Fill in: one paragraph on which chains the app runs on, what moves between them, and what this design leaves out.

Each section decides one part and points to the others instead of repeating them. Open decisions holds every decision, assumption, and open question; other sections link to it.

## Purpose and chains

Fill in: what the app does on each chain, who uses it there, the chains and their chain IDs, and why each chain is in scope.
Fill in: the limits that must hold, such as the most that may move in an hour or a day, and what must never be possible on any chain.

## Deployment and addresses

Fill in: which contracts must have the same address on every chain and why, the factory and the salt that give them that address, and how the team checks that each address holds the same code.
Fill in: the contracts whose addresses differ by chain, where those addresses are recorded, and how a new chain is added.

## Assets across chains

Fill in: each asset that moves between chains, which chain issues it, and how it moves: lock and mint, burn and mint, or a native issuer's own transfer (for example Circle's CCTP for USDC).
Fill in: how the total supply across all chains stays correct, who may mint on each chain, decimals on each chain, and which token is the canonical one users should hold.

## Messages and verification

Fill in: the message or bridge protocol and its version, how a message is verified (the verifiers, how many must agree, and who runs them), how long the source chain must wait for finality, and the date each protocol was checked, written as YYYY-MM-DD.
Fill in: how a message is bound to its source chain, destination chain, sender, and nonce, so it cannot be replayed or delivered twice; and the status of each ERC as checked with the evm-standards skill.

## Partial failures

Fill in: what happens when one side completes and the other does not: a message that is sent but never delivered, delivered but fails, or delivered after the source chain reorganizes.
Fill in: how users get their assets back (retry, manual execution, refund), who may trigger it, and how stuck messages are found.

## Roles and limits

Fill in: each role on each chain (owner, bridge admin, rate limit admin, pauser), who holds it, and which changes go through a timelock.
Fill in: the rate limits per direction and per chain, what a pause stops on each chain, and what happens to messages in flight during a pause.

## Fees and gas

Fill in: who pays the message fee on the source chain and the gas on the destination chain, in which token, and what happens when the destination gas runs out.
Fill in: the fees users see before they confirm, and how fee changes are handled.

## Monitoring and environments

Fill in: what is watched on every chain (supply across chains, rate limit use, stuck messages, admin changes, verifier configuration), and where alerts go.
Fill in: the test networks used for each chain pair, and which keys, addresses, and configurations are separate per environment.

## Open decisions

Fill in: each open question and assumption, the candidates, what it affects, who decides, and by when or under what condition.
