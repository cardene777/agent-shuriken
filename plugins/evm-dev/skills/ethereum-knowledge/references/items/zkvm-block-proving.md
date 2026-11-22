---
status: live
checked: 2026-11-11
source: The Zeth repository of boundless-xyz (the README, the commit history, and the list of releases), RISC Zero's announcement of 2023-08-22 (Zeth) and of 2025-04-10 (Introducing R0VM 2.0), ZKM's official documentation and repository for Ziren, and the Ethproofs page
---

# Proving blocks in a zkVM

A form that runs the parts of an Ethereum execution client inside a general-purpose zkVM (a virtual machine that can prove the execution of any program) and proves the validity of the block itself.
It does not build the EVM directly into proving circuits but uses existing client code, so it leaves Ethereum's semantics unchanged.
RISC Zero's Zeth and ZKM's Ziren take this form.

| Point | What the official documents say |
|---|---|
| What Zeth is | It runs reth's stateless execution inside RISC Zero's zkVM. It proves everything from transaction checks to reward payment and the computation of the state root, and compares the resulting state root with the correct value in the block header |
| Zeth's input | From an archive node it takes the block header and a bundle of the prior state needed for execution (accounts, storage, and code). Fetching it needs the non-standard `debug_executionWitness` call |
| Zeth's range | By default it proves only blocks after the Merge. Blocks before the Merge can be proved with an experimental setting, but it says those proofs are not sound |
| Where Zeth lives | The repository moved from `risc0/zeth` to `boundless-xyz/zeth`. The last release is v0.3.0 of 2025-12-03; on 2026-05-12 it raised reth to 2.1.0 and added parts that speed up EVM precompiles. The last commit is from 2026-07-13 |
| Zeth's first announcement | On 2023-08-22 RISC Zero released Zeth, built on revm and running on RISC Zero's zkVM. It wrote that proving a block, which had taken hours, takes minutes |
| Proving time | In its announcement of R0VM 2.0 on 2025-04-10, RISC Zero wrote that since R0VM 1.0, proving one block (including execution) went from 35 minutes to 44 seconds. The same announcement set the goal of reaching real-time proving by 2025-07 |
| Ziren's name | ZKM's zkVM, first named zkMIPS. The repository renamed it from zkMIPS to Ziren in a commit of 2025-07-07 |
| What Ziren is | It runs Rust or Go programs converted to MIPS32r2 instructions. Its proofs are based on Plonky3, and its circuit building and recursion parts come from SP1. At the end it wraps the proof in a Groth16 or PLONK proof over BN254 and verifies it on chain |
| Ziren's claim | ZKM's documentation says Ziren proves Ethereum mainnet blocks end to end in production |

## Current status

Zeth was still updated in `boundless-xyz/zeth` until 2026-07.
On 2026-11-11, Ethproofs (a page that collects and lists each team's block proofs) placed both RISC Zero's R0VM 3.0.3 and ZKM's Ziren 2.0.0 in the column of zkVMs not running, and showed 0 machines producing proofs.
The running column of the same page lists ZisK, OpenVM, SP1, ZKsync Airbender, and others.
Across all teams, Ethproofs shows that 67.3% of blocks were proved in under 10 seconds.

## Not yet shipped

The Zeth repository does not say how many seconds Zeth now takes to prove one block.
Whether the 44 seconds in the R0VM 2.0 announcement were measured with Zeth has not been checked.
Whether RISC Zero reached real-time proving by 2025-07 has not been checked (RISC Zero's blog does not open now, and the R0VM 2.0 announcement was read from a saved copy).
ZKM's proving of mainnet blocks is a claim in ZKM's documentation, and no third-party check has been found.
Which execution client Ziren uses when proving blocks has not been checked.
