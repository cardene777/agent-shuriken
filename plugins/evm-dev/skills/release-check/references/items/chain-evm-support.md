---
topic: evm
subject: The EVM version each major chain runs
checked: 2026-11-17
source: Ethereum Foundation, Fusaka mainnet announcement; Offchain Labs, ArbOS 51 Dia release notes; Optimism, Upgrade 19 (Karst) notice; Base, Azul network upgrade notes and the earlier Canyon, Ecotone, and Isthmus notes; Linea, release notes for the Beta v4 upgrades
---

# Most major chains run osaka; check a smaller chain before relying on it

| Chain | Newest EVM version | Since |
|---|---|---|
| Ethereum mainnet | `osaka` (Fusaka) | 2025-12-03 |
| Arbitrum One and Arbitrum Nova | `osaka` (ArbOS 51, Dia) | 2026-01-08 |
| OP Mainnet, Soneium, Ink, Unichain, Mode, Metal, Zora | `osaka` (Upgrade 19, Karst) | 2026-07-08 16:00:01 UTC |
| Base | `osaka` (Azul) | 2026-05-28 |
| Linea | `osaka` (Beta v4.4) | 2025-12-03 |

Earlier steps, for chains that lag behind:

- Base reached `shanghai` with Canyon on 2024-01-11, `cancun` with Ecotone on 2024-03-14, and `prague` with Isthmus on 2025-05-09; Base left the OP Stack's upgrade schedule in February 2026
- Linea reached `shanghai` on 2025-10-23, `cancun` on 2025-10-28 at 10:00 UTC, and `prague` ten minutes later
- ArbOS 51 brought `CLZ` and the precompiles of EIP-7951 (secp256r1) and EIP-2537 (BLS12-381) and the ModExp changes of EIP-7823 and EIP-7883, but not the blob and data-availability changes of Fusaka (EIP-7594, EIP-7918, EIP-7892, EIP-7917, EIP-7934, EIP-7907, EIP-7935)

For a release:

- For a chain not in the table, find its current EVM version in its official documentation, and run `opcodes` with that version
- When the documentation does not say, treat the chain as `paris` (no `PUSH0`) until it is confirmed
- A testnet may run a newer version than its mainnet; check the mainnet before deploying there
