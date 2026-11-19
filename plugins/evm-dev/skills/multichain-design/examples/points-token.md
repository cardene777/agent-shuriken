# Example: Loyalty points token on two chains

This design lets a shop network issue one loyalty points token (PTS) and let members move their points between OP Mainnet and Unichain, where the shops run their checkouts. It covers addresses, how points move, how messages are verified, what happens when only one side completes, roles, fees, and monitoring. It leaves out how shops award points, rewards catalogs, and any chain beyond these two.

Each section decides one part and points to the others instead of repeating them. Open decisions holds every decision, assumption, and open question; other sections link to it.

## Purpose and chains

OP Mainnet is the home chain: the program awards points there and members redeem them there. Unichain hosts the second group of shops, where members spend and receive points. Chain IDs are read from each network at deployment and kept in the address record (D6).
Limits: at most 1,000,000 PTS may move in each direction in any 24 hours (D3); the total across both chains never exceeds what the program minted minus what was redeemed; nothing but a verified message mints PTS on Unichain.

## Deployment and addresses

The PTS token has the same address on both chains, so members, shops, and a later move to native interop see one token. It is deployed through CreateX from the deployer account whose address fills the salt's first 20 bytes, with a 21st byte other than 0x01 so the chain ID is not mixed in (item on CREATE2 factories, checked 2026-11-18). The salt and the creation code are the same on both chains; the roles of each chain are set by an initializer run in the deploying transaction.
Before deployment the team checks that CreateX exists at its published address on both chains; afterwards it compares the code at both token addresses. The bridge app, the timelocks, and the multisigs differ by chain and are recorded per environment; a new chain is added through the same steps. ERC-7955, a permissionless factory, is still a Draft, so it is not used.

## Assets across chains

PTS is issued on OP Mainnet and moves by burn and mint in both directions: sending burns PTS on the source chain, and the bridge app mints it on the destination once the message is verified. PTS has 18 decimals on both chains, so amounts and rate limits need no conversion.
Supply on OP Mainnet plus supply on Unichain plus PTS burned and not yet minted equals minted minus redeemed. On OP Mainnet the program's minter and the bridge app may mint, and redeeming burns PTS; on Unichain only the bridge app may mint. PTS at the shared address is the only canonical token; no wrapped PTS exists, and xERC20 is not used because it has no merged standard document (evm-standards item on ERC-7281, checked 2026-11-18).

## Messages and verification

Messages travel over LayerZero V2 (item on LayerZero V2 verifier configuration, checked 2026-11-18). Each pathway requires three DVNs run by independent operators, all of which must confirm, following LayerZero's advice for production apps after a single-verifier app lost about 292 million dollars in April 2026. The live configuration is read from the endpoint contract on both chains after each deployment and compared with this design.
The source chain must reach finality before the DVNs confirm; the confirmation count per chain is set in D2. Each payload carries the source chain ID, the destination chain ID, the sender, the recipient, the amount, and a per-sender nonce; the receiver accepts a message only from the configured peer on the expected source chain and records its message ID, so a second delivery mints nothing.
SuperchainERC20 (ERC-7802) interop between OP Stack chains is not live on any mainnet; Optimism targets OP Mainnet and Unichain for 11 January 2027, pending governance (item on Superchain interop, checked 2026-11-18). ERC-20 is `Final` (evm-standards item, checked 2026-11-18), and the status of ERC-7802 has no item (D1).

## Partial failures

- Sent but never delivered: the PTS stays counted as burned and in flight, and the monitor reports any message older than one hour. Anyone may execute a verified message on the destination and pay its gas (D4)
- Delivered but the mint cannot run, because the chain is paused or the inbound limit is used: the receiver records a pending mint instead of reverting, and the recipient claims it once the chain is unpaused or the limit has refilled
- Reorganized source after delivery: prevented by waiting for finality (D2); if supply ever disagrees, the pausers stop both chains
There is no refund on the source chain: every stuck message is finished on the destination, by a new execution or by the recipient's claim.

## Roles and limits

On each chain a separate multisig, with signers that differ between chains, owns the token and the bridge app. Peers, DVN configuration, and raising a rate limit go through that chain's timelock with a 48-hour delay. A guardian multisig per chain may pause, or set that chain's limits to zero, at once; it cannot raise limits or change peers.
Each direction has an outbound limit on the source and an inbound limit on the destination, set as token buckets with a capacity of 500,000 PTS and a refill of 500,000 PTS a day. A forged message could therefore take the capacity at once and then the refill, so in 24 hours at most 1,000,000 PTS. A pause stops sending and minting on that chain; messages in flight become pending mints.

## Fees and gas

The member pays the LayerZero fee on the source chain in that chain's native token when sending; the fee also pays the gas to mint on the destination (D5). When the destination gas runs out, the message is executed again with more gas, as in Partial failures.
Before confirming, the member sees the fee quoted for that send and the time to finality; the quote is fetched again for each send, so a change in fees reaches the next send.

## Monitoring and environments

A monitor the team runs (D7) watches both chains for: total supply against minted minus redeemed, rate limit use above 80 percent, messages in flight for more than an hour, pending mints, role and timelock changes, and the DVN configuration read from the endpoints each day. Alerts go to the program's on-call engineer.
OP Sepolia and Unichain Sepolia are the test pair, deployed through the same steps as mainnet; each environment has its own deployer, multisigs, guardians, and address record, and no mainnet key signs on a test network.

## Open decisions

| ID | Decision or assumption | Candidates | Affects | Who decides | By when |
|---|---|---|---|---|---|
| D1 | Whether PTS also follows ERC-7802 for later native interop; its status has no item | LayerZero only; add ERC-7802 once both chains activate interop | Messages and verification | Engineering lead | Before the token is deployed |
| D2 | Confirmations each chain waits for before DVNs confirm, read from each chain's finality | The chain's finalized block; a fixed count per chain | Messages and verification, Partial failures | Engineering lead | Before mainnet deployment |
| D3 | Assumed: 1,000,000 PTS a day per direction, from expected member moves | Lower for the first three months | Purpose and chains, Roles and limits | Program owner | Before mainnet deployment |
| D4 | Assumed: a verified LayerZero message can be executed again by anyone; confirm in the V2 documentation | Anyone executes; the team runs a retry job | Partial failures | Engineering lead | Before mainnet deployment |
| D5 | Assumed: the source fee covers destination gas, and members pay it | Members pay; the program pays for small moves | Fees and gas | Program owner | Before launch |
| D6 | Chain IDs and LayerZero endpoint IDs, recorded from each network and LayerZero's deployment list | Not copied from memory | Purpose and chains, Deployment and addresses | Engineering lead | At each deployment |
| D7 | Which monitor the team runs, and where alerts go | A self-hosted monitor; an in-house job | Monitoring and environments | Engineering lead | Before mainnet deployment |
