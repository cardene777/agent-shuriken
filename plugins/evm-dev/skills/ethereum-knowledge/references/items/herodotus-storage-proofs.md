---
status: live
checked: 2026-11-11
source: The Herodotus Cloud documentation (the `Storage Proofs API` introduction and the `Satellite Contracts` deployments) and Herodotus' Satellite repository (its README and the list of production deployments)
---

# Herodotus `Storage Proofs`

`Storage Proofs` let a contract on one chain read, with a proof, a storage value or a balance of another chain.
Herodotus says data can be read across chains and layers without adding a new trust assumption.
Requests to make proofs go to the Herodotus API, and the verified values are read from the Satellite contract deployed on the destination chain.

| Point | What the official documents say |
|---|---|
| Request flow | A request with an API key goes to Herodotus' Mission Control and names the destination chain. After watching the request's status, the value is read from the destination's Satellite contract when it is done |
| Block records | Satellite holds the hashes of every past block in an MMR (a kind of Merkle tree that can be appended to). The newest 256 blocks take their hashes from an EVM opcode, and older blocks are added by following parent hashes |
| Lowering the cost | The computation that adds old blocks in bulk is written in Cairo0, SHARP makes a STARK proof, and the proof is verified on Ethereum. The contract updates only when the MMR values in the proof match its own |
| Carrying to another chain | The MMR and parent hashes travel over each chain's native message path. The sending parts the README lists send from L1 to Starknet, chains of the Optimism type, ZKsync, and Arbitrum, and from Arbitrum to ApeChain |
| Trust | The README says a value in Satellite can be called correct without trusting the owner or anyone else |
| Production links | The list of production deployments shows links from Ethereum to four L2s (Arbitrum One, World Chain, Base, and Starknet) and from Arbitrum One to ApeChain |
| Test network links | It shows links from Sepolia to the test networks of five L2s (Arbitrum Sepolia, OP Sepolia, World Chain Sepolia, Base Sepolia, and Starknet Sepolia) and from Arbitrum Sepolia to ApeChain's test network (Curtis) |

## Current status

The Satellite repository was updated in 2026-08 too, and its list of production deployments gives the contract addresses on each chain.
The Herodotus Cloud documentation gives the request endpoint and how to read the `Storage Proofs API` in its current form.

The directions that can be read are L1 (Ethereum) state on an L2, and Arbitrum One state on ApeChain.
The README's list has no sending part that reads L2 state on L1 or on another L2.
The part that adds Starknet blocks to the MMR is marked in the README as not built yet.

The claim of a 2023 post that "the state of other L1s and L2s can be read without going through a bridge or an oracle" is, in production today, limited to carrying from Ethereum to four L2s and from Arbitrum One to ApeChain.
The path it travels is each chain's native message path, not a bridge Herodotus set up separately.

## Not yet shipped

A connection to the API's health endpoint on 2026-11-11 got no response.
Whether the request endpoint responds now has not been checked.

The part that sends to ZKsync is in the README, but ZKsync is not in the list of production deployments.
Whether the link to ZKsync is used in production has not been checked.
The current status of Turbo, named in Herodotus' old documentation site, has not been checked.
