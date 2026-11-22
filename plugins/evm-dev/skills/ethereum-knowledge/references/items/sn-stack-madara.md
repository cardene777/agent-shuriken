---
status: live
checked: 2026-11-11
source: Madara's documentation (the overview and the settlement and prover pages), the README history of Madara's old repository, Madara's orchestrator repository, Herodotus' Integrity repository, Herodotus' documentation (Integrity Verifier), the Herodotus Cloud documentation (Dynamic Layout on L2 and the L2 Proof Verification entry of its table of contents), and the README of Herodotus' Bankai
---

# SN Stack and Madara

Madara is the official implementation of the SN Stack (the set of parts that launch chains with Starknet's technology).
Anyone can launch an app-specific chain (an appchain) that settles to Ethereum or Starknet.
A chain that settles to Starknet becomes an L3, and Starknet in turn settles to Ethereum.
Madara's documentation says today's Starknet production network uses parts that are not public, while Madara is entirely public.

| Point | What the official documents say |
|---|---|
| Where it settles | Ethereum or Starknet. The settlement layer needs a zero-knowledge proof verifier contract and a Starknet `core contract` that holds the state updates. Settling to Starknet uses Piltover as the `core contract` |
| Provers | The main prover available today is Stone; Stwo is under construction and not ready for use. Madara recommends having Herodotus' Atlantic make Stone proofs, and Atlantic sends the proofs to the settlement layer |
| Recursive proofs | Several proofs can be combined into one and sent to the settlement layer. For that, the settlement layer's verifier must be able to verify recursive proofs |
| Away from Substrate | Madara in 2023 was built on Substrate. On 2024-08-02, the old repository added a notice at the top of its README that support ends because it is moving to an implementation without Substrate |
| What Integrity is | Integrity is a STARK proof verifier written in Cairo by Herodotus, with contracts on Starknet mainnet and testnet (Sepolia). It verifies Stone prover proofs and records the verified proofs in a registry contract (`FactRegistry`) |
| Integrity's limits | The layouts of proofs it can verify (how the circuit is arranged when proving) are limited to six: `dex`, `recursive`, `recursive_with_poseidon`, `small`, `starknet`, and `starknet_with_keccak`. Stone versions are limited to `stone5` and `stone6` |
| Dynamic layouts | The Herodotus Cloud documentation says Integrity cannot verify proofs with the `dynamic` and `all_cairo` layouts. In that case the original proof is proven again on StarkWare's Cairo0 verifier, and Integrity verifies that proof. The README of Herodotus' Bankai says the rewrapped proof has the `recursive_with_poseidon` layout |

## Current status

Madara's documentation gives the steps for launching an appchain with Madara that settles to Ethereum or Starknet.
The old repositories of Madara's orchestrator and bootstrapper are archived (last updated in 2025-05) and say they were merged into the madara repository.

On 2026-11-11, opening the madara repository of madara-alliance on GitHub found nothing.
Other repositories of the same organization were updated in 2026-11 too.

The 2023 post's "a sequencer assembled with Substrate" differs from the current implementation.

Integrity has contracts on Starknet mainnet.
The Herodotus Cloud documentation says Atlantic uses Integrity when verifying proofs on Starknet.

## Not yet shipped

Whether chains launched with Madara that settle to Starknet actually verify their proofs with Integrity has not been checked.
Madara's documentation and the orchestrator's code say that when settling to Starknet the proofs go to Atlantic and the verifier contract's address comes from configuration, but they do not name that contract as Integrity.

Why the madara repository cannot be found, and where its code lives now, have not been checked.
The names of appchains launched with Madara and running in production have not been checked.
The date Herodotus first verified a STARK proof on Starknet mainnet has not been checked.
