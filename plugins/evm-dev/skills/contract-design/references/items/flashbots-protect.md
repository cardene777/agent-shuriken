---
topic: ordering
subject: Flashbots Protect and private transaction relays
checked: 2026-11-17
source: Flashbots, Flashbots Protect overview (updated 2025-12-16)
---

# Private relays protect only the users who send through them

Flashbots Protect sends a transaction to a private mempool, hidden from front-running and sandwich bots, includes it only if it does not revert, and can refund part of the MEV or the priority fee it creates.
It protects the users who choose that RPC; anyone else still sends through the public mempool.

For a design:

- Do not rely on a private relay to make a contract safe: every trade, purchase at a moving price, and liquidation still needs a minimum output and a deadline in the contract
- Where order decides who wins (a first-come allocation, a reveal of hidden values), use commit-reveal, a batch, or an auction instead of first-come
- The frontend may recommend a private RPC to users as an extra protection
