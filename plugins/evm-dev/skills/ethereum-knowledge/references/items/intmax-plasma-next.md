---
status: stopped
checked: 2026-11-11
source: The INTMAX page of L2BEAT (now named ETHBEAT) (its timeline and risk section), the INTMAX2 exit documentation (the INTMAX2 Exit overview, steps, and FAQ), the Plasma Next paper on Ethereum Research, INTMAX's official site, and INTMAX's repositories (InternetMaximalism)
---

# INTMAX and Plasma Next

INTMAX is an L2 that holds almost no state: users keep the proofs of their own balances, and the chain holds only the roots and proofs of batches of transactions.
Plasma Next is a Plasma design posted to Ethereum Research by Leona Hioki and others on 2024-02-25, in which users need not watch L1; its code is in INTMAX's GitHub organization.
INTMAX2 mainnet has been stopped since 2026-02-07, and only the exit mechanism for withdrawals runs now.

| Point | What the official documents say |
|---|---|
| The form of Plasma Next | L1 holds only the root of the batched transfer tree and, for each user, the number of the block of their last withdrawal. It combines one-way payment channels with zero-knowledge proofs so that users need not be always online |
| The form of INTMAX2 | The L2BEAT page calls INTMAX a stateless, Plasma-like ZK rollup. L2BEAT places INTMAX as a Stage 0 ZK rollup and a chain for payments |
| Data store | Users keep the proofs of their own balances locally. The L2BEAT page says losing this data can mean losing funds |
| Proofs | Validity is checked with SNARK proofs, and a verifier contract on Scroll checks withdrawal proofs |
| Where it sits | The L2BEAT page says INTMAX2 is technically an L3 on Scroll, and that funds are held in a contract on Ethereum |
| Mainnet | L2BEAT's timeline says mainnet went live on 2025-06-26 |
| Shutdown | L2BEAT's timeline says operations stopped on 2026-02-07 because of a problem in the ZK proof system and users were urged to withdraw, and that withdrawals on Ethereum and block posting to Scroll stopped on 2026-02-10 |
| Vulnerability | The exit documentation says a hole was found in the circuit that checks the sender's balance, through which a balance proof could be forged under some conditions. It says there is no evidence it was used and no funds were lost |
| Exit | When a user gives a read-only key (view key) to INTMAX's server, the server recomputes the balance from scratch and files a claim with the exit contract. During a 24-hour timelock a watcher can cancel suspicious claims, after which the user withdraws to an Ethereum address |

How L2BEAT sorts stages is in the `l2beat-stages` item.

## Current status

The timeline of L2BEAT (now named ETHBEAT) says INTMAX2 operations stopped on 2026-02-07, and that the contract holding funds and the contract receiving blocks were stopped on 2026-02-10.
INTMAX2 mainnet is still stopped, and only the exit mechanism runs.
The exit documentation says that once the circuit is fixed, old balance proofs cannot be used in the new version, and there is no way to carry them over.
INTMAX's official site still says "mainnet is live" and does not mention the shutdown.
The network stopped and only the exit for withdrawals runs, so the status is `stopped`.

The claims of posts from 2024 that "gas fees are fixed" and "mainnet in October" differ from the current state.

## Not yet shipped

No shutdown notice or post-incident report published under INTMAX's name was found, and none has been checked.
The exit documentation does not name its publisher, but it was taken as INTMAX's own document because it says the key goes to INTMAX's server.
The exit documentation says a remedy for senders who do not give their key would come out by the end of 2026-02, but whether it did has not been checked.
When help with exits ends, and whether mainnet will be restarted with a fixed version, have not been checked.

INTMAX's repositories hold the circuits and contracts of INTMAX3, a payment rollup that holds almost no state, with updates as recent as 2026-11-09.
No version or release date of INTMAX3 has been given.
How far the designs of Plasma Next and INTMAX2 are the same has not been checked in the INTMAX2 paper.
Reports that Plasma Next went to a trial mainnet in 2024-02 have not been checked in official documents.
