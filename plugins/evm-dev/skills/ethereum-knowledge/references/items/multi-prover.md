---
status: live
checked: 2026-11-11
source: Taiko's official documentation (Proving System and Shasta Fork), the taiko-mono repository of taikoxyz, and the Taiko Alethia page of L2BEAT
---

# Multiple proofs (multi-prover)

A form that requires two or more proofs of different kinds for one change of a rollup's state.
Even if one proof system has a bug, an invalid state is not finalized as long as another system does not share the same bug.
Taiko Alethia combines proofs made inside Intel SGX, a TEE (trusted execution environment), with zero-knowledge proofs made in zkVMs.

| Point | What the official documents say |
|---|---|
| Verifiers | Four: `sgxGeth`, which runs Geth inside SGX; `sgxReth`, which runs reth inside SGX; `risc0`, the RISC Zero zkVM; and `sp1`, Succinct's zkVM |
| How many it requires | Exactly two proofs for each consecutive range of proposals, and the second must be a zero-knowledge proof |
| Accepted pairs | Five: `sgxGeth` with `risc0`, `sgxGeth` with `sp1`, `sgxReth` with `risc0`, `sgxReth` with `sp1`, and `risc0` with `sp1`. The SGX-only pair (`sgxGeth` with `sgxReth`) is refused |
| Contracts | `Inbox` checks the range and its link to the previous proposal, and `ZkRequiredVerifier` passes the parts of the proof to each verifier. If they pass, `Inbox` writes a checkpoint and advances finality |
| Who submits proofs | Permissioned provers can submit at once. Anyone else can submit after waiting 5 days |
| Proof deadline | A proof more than 4 hours after the proposal is treated as late. The mechanism that moves the bond when a proof is late does not work today, since the bond amount is 0 |
| Contestation | The current documentation has no contestation mechanism; once proofs pass, finality just advances |
| Fork | Taiko's current fork is Unzen, which runs on the Shasta architecture that replaced Pacaya |

## Current status

L2BEAT (whose pages now appear under the name ETHBEAT) places Taiko Alethia as a ZK Rollup at Stage 0.
The same page says two of the four verifiers are required, and at least one must be SP1 or RISC0.
It also says only two permissioned provers can submit proofs, and while they can stop the chain, they cannot finalize an invalid state.
The contracts can be upgraded immediately, so users have no window to leave.

The Guardian prover appears neither in Taiko's current documentation nor on the L2BEAT page.
In the taiko-mono repository, the parts that call the Guardian prover and verifier exist only for the Ontake fork, not for Pacaya.
Today's Taiko refuses the SGX-only pair and always requires one zero-knowledge proof, unlike the combinations at the time of a 2023 post.

## Not yet shipped

What the Guardian prover did, and the date and reason it was removed, have not been checked, because the text of Taiko's announcement could not be opened.
The date Unzen took effect on mainnet is not in the documentation and has not been checked.
Whether provers outside the permissioned set can actually submit proofs after 5 days is written differently in Taiko's documentation and on the L2BEAT page, and has not been checked.
Rollups other than Taiko that require multiple proofs have not been checked.
