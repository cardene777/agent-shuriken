---
status: live
checked: 2026-11-11
source: Vitalik Buterin's blog (The different types of ZK-EVMs), Polygon Labs' Polygon zkEVM page, Scroll's official documentation (Euclid Upgrade), ZKsync's official documentation (EVM Bytecode Interpreter), and RISC Zero's announcement of 2023-08-22 (Zeth)
---

# Types of ZK-EVM

The types of ZK-EVM sort EVMs that prove execution with zero-knowledge proofs by how far they are the same as Ethereum.
Vitalik Buterin sorted them into five in a blog post of 2022-08-04: Type 1, Type 2, Type 2.5, Type 3, and Type 4.
They show a trade-off: the closer to Ethereum, the more existing tools and apps run as they are; the further, the faster the proofs.

| Point | What the official documents say |
|---|---|
| Type 1 | Fully the same as Ethereum, changing no hash function, state tree, or precompile. Existing execution clients can be used, but proving is slowest. The original names the ZK-EVM Community Edition as an example |
| Type 2 | The EVM is the same, and only outer data structures such as the block format and the state tree change (for example, replacing the hash function with Poseidon). Apps that verify Merkle proofs of past blocks break |
| Type 2.5 | Type 2 plus higher gas costs only for opcodes and precompiles that are heavy to prove. The worst-case proving time shrinks |
| Type 3 | Drops features that are especially hard to build (mainly precompiles). The original places Scroll and Polygon here, as a stage on the way to Type 2, and says no team means to stay here |
| Type 4 | Converts Solidity or Vyper source code to another language that is easier to prove, and runs that. Proving is fastest, but addresses created with `CREATE2` can differ from Ethereum's. The original names ZKsync, and Starknet using Warp, which converts Solidity to Cairo, as examples |
| How types change | The original says types are not fixed. Adding features moves a project from Type 3 to Type 2, and adding a way to run EVM opcodes moves it from Type 4 to Type 3. If Ethereum changes to a form that is easier to prove, Type 2 and Type 3 become Type 1 |
| Type 0 | A name not in the original. In its announcement of 2023-08-22, RISC Zero called Zeth, which uses the same parts as an Ethereum node without changing Ethereum's semantics at all, "Type 0". Proving blocks in a zkVM is in the `zkvm-block-proving` item |

## Current status

The original's type assignments are from 2022, and the place of each implementation has moved since.
Polygon Labs' Polygon zkEVM page says the ordering mechanism (the sequencer) of Polygon zkEVM Mainnet Beta stopped on 2026-07-03 and no longer produces blocks.
Assets in wallets whose keys the user holds can be recovered through a page on Ethereum until 2027-12-31.
Assets held in contracts cannot be recovered through that page.

With the Euclid upgrade of 2025-04, Scroll dropped its halo2 circuits and moved to a proof system built on OpenVM.
In the same upgrade it changed its state tree from zkTrie to the same MPT (Merkle Patricia Trie) as Ethereum.
That moves the difference in outer data structures, which the original called the mark of Type 2, to the same form as Ethereum.

ZKsync Era's native execution environment is EraVM, which runs Solidity converted to EraVM instructions with `zksolc`.
It now also has, on top of EraVM, an interpretation layer that runs EVM opcodes as they are (EVM Bytecode Interpreter).
However, `CALLCODE` and `SELFDESTRUCT` do not work, and `delegatecall` cannot be used between EVM contracts and EraVM contracts.
ZKsync's documentation says fees are 1.5 to 4 times higher than for EraVM contracts.

## Not yet shipped

Which type Scroll, ZKsync, and Taiko call themselves today has not been checked.
Whether Starknet now has a way to run EVM opcodes has not been checked in official documentation.
The date the EVM Bytecode Interpreter took effect on ZKsync Era mainnet has not been checked.
Linea's current type has not been checked.
