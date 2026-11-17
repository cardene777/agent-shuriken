---
topic: evm
subject: The per-transaction gas cap of EIP-7825 and the contract size limits
checked: 2026-11-17
source: EIP-7825, EIP-170, and EIP-3860; Ethereum Foundation, Fusaka mainnet announcement; Offchain Labs, ArbOS 51 Dia release notes; Optimism, Upgrade 19 (Karst) notice; Base, Azul network upgrade notes; Foundry, forge script reference
---

# A transaction above 16,777,216 gas is rejected on chains that adopted EIP-7825

EIP-7825 caps the gas limit of one transaction at 2^24 = 16,777,216, whatever the block gas limit is. A transaction with a higher gas limit is invalid and never included.

| Chain | Cap per transaction | Since |
|---|---|---|
| Ethereum mainnet | 16,777,216 | 2025-12-03 (Fusaka) |
| OP Mainnet and the chains on Upgrade 19 | 16,777,216, not applied to deposit transactions from L1 | 2026-07-08 (Karst) |
| Base | 16,777,216 | 2026-05-28 (Azul) |
| Arbitrum One and Arbitrum Nova | 32,000,000 | 2026-01-08 (ArbOS 51) |

Size limits that apply on every chain that follows Ethereum:

- Runtime code at most 24,576 bytes (EIP-170)
- Creation code (initcode) at most 49,152 bytes (EIP-3860)

For a release:

- `forge script` sets each transaction's gas limit to its estimate times 130 % by default (`--gas-estimate-multiplier`), so an estimate above about 12,900,000 already crosses the cap; read each transaction's gas in the simulation
- A deployment that creates several contracts in one transaction (a factory, or a script that batches) is the usual way to cross it; split it into separate transactions
- A function that loops over an unbounded list can cross it later, as the list grows, even when today's calls fit
