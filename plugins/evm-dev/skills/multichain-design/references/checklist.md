# Review checklist for a design across chains

Go through this list after `verify` passes. A design that fails any rule in the first table is not finished: fix it and check again. Say which rules you could not judge and why.

## Rules a design must never break

| Rule | What fails it |
|---|---|
| Same address means same code | A contract meant to share an address relies on CREATE2 without naming the factory and the salt, or nobody checks after deployment that each address holds the same code |
| Messages cannot be replayed | A message is not bound to its source chain ID, destination chain ID, sender, and nonce, so it can be replayed on another chain or route |
| A message runs once | Delivering the same message twice can mint or release twice, because the receiver does not record which messages it has processed |
| Supply stays whole | The design does not say whether assets lock, burn, or mint on each chain, or the total supply across all chains can exceed the supply on the issuing chain |
| One canonical token | Users can end up with two tokens for the same asset on one chain, for example a wrapped USDC next to native USDC, without the design choosing the canonical one |
| Finality is respected | The destination acts on a message before the source chain's finality, without saying how a reorg of the source chain is handled |
| No single verifier | A message is accepted on the word of a single verifier, instead of several independent verifiers or the canonical bridge of a rollup |
| Rate limits hold | No rate limit caps how much can move in each direction, so one forged message can drain everything, or the design counts a token-bucket limit as one window's cap without adding the refill |
| Failures can be recovered | The design does not say what happens when a message is sent but not delivered, or delivered but fails: no retry, no manual execution, and no refund for stuck messages |
| Manual execution reaches the failed call | The fix for a message that ran out of gas raises a gas override that does not reach the call that failed, such as a CCIP `gasLimitOverride`, which covers the receiver's `ccipReceive` but not the token pool's mint or release |
| Pauses are per chain | A pause on one chain leaves the other chains minting or releasing, or nobody can pause a chain without a timelock |
| Admin keys are not shared | One key holds the bridge admin or rate limit admin role on every chain, or a role on any chain is held by a single externally owned account |
| Decimals match | A token has different decimals on two chains and amounts or rate limits are not converted |
| Destination gas is paid | The design does not say who pays the gas on the destination chain, or what happens when it runs out |

## Rules to check with the team

| Area | Check |
|---|---|
| Protocols | Each bridge and message protocol named in Messages and verification carries the date it was checked, and a deprecated version (for example CCTP V1) is not chosen |
| Configuration | The live verifier and rate limit configuration is read from the chain after each deployment, not assumed from defaults |
| Monitoring | Supply across chains, rate limit use, stuck messages, and changes to admin roles and verifier configuration are watched on every chain |
| Chains | Each new chain is added through the same steps, and test networks are paired the same way as their mainnets |
| Testing | The rules above are listed so the contract-tests skill can turn the contract parts into tests |
