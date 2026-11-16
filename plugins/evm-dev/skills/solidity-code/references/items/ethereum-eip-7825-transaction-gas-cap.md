---
tool: ethereum
checked: 2026-11-16
source: EIP-7825 (Final) and EIP-7607 (the Fusaka meta EIP)
---

# One transaction can use at most 16,777,216 gas

EIP-7825 introduced "a protocol-level cap on the maximum gas used by a transaction to 16,777,216 (2^24)".
It went live on mainnet with Fusaka on 2025-12-03; a transaction above the cap is invalid.

A deployment, a batch, or a loop that needs more gas than this in one transaction fails even when the block has room.
Split such work across transactions, or deploy large systems in several steps.
