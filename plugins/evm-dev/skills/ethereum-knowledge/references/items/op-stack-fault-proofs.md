---
status: live
checked: 2026-11-16
source: The OP Stack specification (Fault Proof and Fault Dispute Game), Offchain Labs' disclosure (Security disclosure, 2024-04-26), Optimism's official documentation (kona-client, the Karst hard fork, and the Upgrade 20 notice), proposals on Optimism's governance forum (Upgrade 18, Granite, and Karst), Optimism's blog (Permissionless fault proofs and Stage 1 arrive to the OP Stack), Optimism's superchain-registry repository, and the OP Mainnet page of L2BEAT
---

# OP Stack fault proofs

OP Stack fault proofs decide whether a claim about L2 state is correct through a dispute game on L1.
The proof program, the virtual machine (VM) that runs it one instruction at a time, and the dispute game are separate parts, and the program and the VM are connected only through the pre-image oracle.
Since the parts are separate, the program and the VM can each be replaced with another implementation.

| Point | What the official documents say |
|---|---|
| Proof program | Takes a commitment to L1 data and the disputed claim, rebuilds the L2 state transition from the L1 data, and compares it with the claim. It exits with 0 if the claim is correct and 1 if it is wrong |
| VM | Traces instructions one by one, so one instruction can be proven on L1. The specification names Cannon (MIPS64) and Asterisc (RISC-V) |
| Pre-image oracle | The only channel between the program and the VM. The first byte of a 32-byte key gives its type, which separates values only the dispute contract can provide, keccak256 and SHA-256 values, points of EIP-4844 blobs, and the results of built-in instructions (precompiles) |
| Hints | The program sends a hint before the value it wants, and the outside side prepares that value. On the VM on L1, hints do nothing |
| kona-client | A proof program written in Rust. It is compiled to a 64-bit MIPS executable and run inside Cannon, and it receives all data from `kona-host` through the pre-image oracle. It replaced the Go `op-program` |
| Upgrade 18 | The proposal of 2026-01-21 registered the kona-client game (`CANNON_KONA`, type 8) but did not change the respected game type |
| Upgrade 19 (Karst) | Changed the respected game type from `CANNON` (0) to `CANNON_KONA` (8), making kona-client the main proof program used for withdrawals. Its activation dates were 2026-06-17 on the testnet and 2026-07-08 on mainnet, and the Karst page says it is active |
| Upgrade 20 | Moves from games that dispute the output root of one chain to games that dispute a Super Root. Chains where anyone can challenge respect `SUPER_CANNON_KONA` (type 9). The notice gave 2026-09-24 as the planned date of execution on mainnet |
| The stage of OP Mainnet | Optimism's blog of 2024-06-10 says fault proofs that anyone can challenge, approved by governance, run on OP Mainnet, which reached Stage 1. On failure, the Security Council can fall back to a permissioned form |
| A temporary step back | The Granite proposal on the governance forum of 2024-08-16 says that, because an outside audit found weaknesses, the mechanism that returns to only proposers permissioned by the Optimism Foundation was triggered. There was no exploit, and it said the permissionless form would return with the L1 contract upgrade after Granite |

## The clock weakness found on the testnet

On 2024-03-22, Offchain Labs reported two weaknesses of the fault proofs running on the testnet to OP Labs, with proof-of-concept exploit code.
OP Labs confirmed both on 2024-03-25 and asked that disclosure wait until they were fixed.
Optimism's testnet was upgraded on 2024-04-25, and Offchain Labs disclosed the next day, 2024-04-26.
The disclosure says that, because of these weaknesses, the fault proofs did not add security over a form that relies only on emergency intervention by the Security Council.

The clock of the dispute game works like a chess clock: each side adds up the time it used before making its move.
A side that uses up its time loses on time.

| Point | What the disclosure says |
|---|---|
| How the weakness worked | Because a claim's clock is inherited from its grandparent claim, a bad actor's claim could inherit the time of a claim an honest actor made earlier. The bad actor inherited time just short of a win, and could declare a win on time before anyone else responded |
| The form of attack | In a dispute with many participants, a party that poses as an ally turns at the end (traitor attack). It could pass a false history or get a correct history rejected |
| The proof of concept | Two tests that act in the last second of the 3-day-and-12-hour dispute period. `test_exploit_last_second_challenge` defeats a correct claim, and `test_exploit_last_second_defend` passes a false claim |
| A third weakness | It also reported a dispute that cannot be resolved within the L1 gas limit, but left it out of the disclosure since it was already known and in public documents |
| After the fix | OP Labs changed how the clock is handled and prevented the proofs of concept. Offchain Labs says it has not analyzed the security of the changed mechanism |

The current OP Stack specification also inherits a claim's clock from its grandparent claim.
In addition, when a move is made, if the remaining time on the grandchild claim's clock is shorter than `CLOCK_EXTENSION` seconds, it is set to `CLOCK_EXTENSION` seconds.

## Current status

OP Mainnet's fault proofs are live.
The L2BEAT page (now appearing under the name ETHBEAT) places OP Mainnet as a Stage 1 optimistic rollup and says anyone can submit fault proofs.
The same page gives the dispute period as 3 days and 12 hours, and records the respected game as type 9.
After Upgrade 19 the proof program is the Rust `kona-client`, and Optimism's documentation says support for the Go `op-program` has ended.

In the list of Optimism's superchain-registry, three mainnets let anyone challenge: OP Mainnet, Ink, and Unichain.

The 2023 post's "the program and the VM can be replaced because the pre-image oracle sits between them" actually happened with the switch to kona-client.

## Not yet shipped

Which change OP Labs used to fix the clock weakness reported on 2024-03-22, and whether `CLOCK_EXTENSION` in the current specification is that fix, have not been checked in Optimism's documents.
Whether Upgrade 20 was executed on mainnet on the planned date has not been checked on Optimism's notice page.
The date the permissionless form returned after Granite has not been checked.
