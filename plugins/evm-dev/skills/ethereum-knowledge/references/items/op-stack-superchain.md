---
status: live
checked: 2026-11-11
source: Optimism's official documentation (the Lagoon hard fork, the interop readiness notice, and the Blockspace Charter), Optimism's blog (Introducing the Law of Chains), Optimism's superchain-registry repository, and Base's blog (A new, unified stack for Base Chain)
---

# The OP Stack and the Superchain

The OP Stack is the set of L2 parts Optimism releases under a permissive license (MIT); anyone can use it to launch their own chain.
The Superchain is the group of those chains (OP Chains) that follow Optimism's governance.
Chains that run the same OP Stack split by whether they join the governance.

| Point | What the official documents say |
|---|---|
| Law of Chains | A draft of governance principles (v0) Optimism published on 2023-07-25. It applies only to OP Chains that decided to join the Superchain, and calls itself a social contract, not a legal one. Chains that only use the OP Stack are not bound |
| Record of who joins the governance | The list in Optimism's superchain-registry has a `governed_by_optimism` field for each chain. In the list seen on 2026-11-11, four mainnets have it true: OP Mainnet, Ink, Soneium, and Unichain |
| Chains outside the governance | In the same list, Celo and World Chain have `governed_by_optimism` false. Mantle, Manta Pacific, and opBNB are not on the list |
| Records of chains leaving the governance | The entries for Base's mainnet and testnet disappeared from the list on 2026-04-27. Mode, Metal, and Zora were rewritten as outside the governance on 2026-10-11 |
| The standard | The Standard Rollup Charter, the first of the Blockspace Charter, requires a governance-approved version of the OP Stack and contracts of a fixed form. Alt-DA, which keeps data outside, and modified contracts are not standard |
| Where Base moved | Base's engineering team wrote on its blog on 2026-02-18 that Base moves to one stack it runs itself (`base/base`), and that node operators move to Base's client. Right after the move it keeps compatibility with the OP Stack specification, continues with Optimism as an OP Enterprise customer, and adds independent signers to Base's Security Council in place of Optimism |
| Interoperability | Superchain interoperability comes with the Lagoon hard fork. The pair of OP Sepolia and Unichain Sepolia is planned to activate on 2026-12-03, with the exact time not yet decided |

## Current status

OP Stack chains are live.
The chains that join the governance are fewer; in the list of 2026-11-11, only four mainnets have the value true.
Reports of 2026-02 that Base left the OP Stack are backed by Base's blog, which says "Base moves to a stack it runs", and by the record of its removal from the registry on 2026-04-27.
Base's blog, however, says it keeps compatibility with the OP Stack specification right after the move.

The Lagoon specification is not final yet, and the hard fork page of Optimism's documentation gives the default dates for both mainnet and testnet as undecided.
Activation on the mainnets of OP Mainnet and Unichain waits for governance approval.
The interop readiness notice gives the mainnet date differently in two places, as 2026-12-15 and 2027-01-11.

Many of the "chains using the OP Stack" listed in a 2023 post are now outside the governance or gone from the list.

## Not yet shipped

The mainnet activation date of Lagoon waits for governance approval and a decision on the time.
Which version of the OP Stack Mantle, Manta Pacific, and opBNB forked from has not been checked in each chain's official documentation.
Whether the hard fork (V1) that Base's blog said moves to TEE and ZK proofs runs on mainnet has not been checked.
The Standard Rollup Charter page names the `superchain_level` field as the mark of the standard, but the registry removed this field on 2026-07-21, and how the standard is judged today has not been checked.
