---
status: specified
checked: 2026-11-18
source: ethereum/EIPs: the EIP-7692 (EOFv1 meta), EIP-663, EIP-8024, EIP-7607 (Fusaka meta), and EIP-7773 (Glamsterdam meta) documents; the Ethereum Foundation blog: the Glamsterdam posts of 2026-09-17 and 2026-10-22
can: Contract code can use a container format that is validated at deployment, with reworked jumps and functions (EOF).
---

# EIP-7692 (EOF, a reworked format for EVM code)

A bundle of standards that gives EVM code a container format, validates its contents at deployment, and reworks jumps and functions.
The umbrella is EIP-7692, which includes EIP-3540 (the format), EIP-3670 (validation at deployment), EIP-4200 (relative jumps), EIP-4750 (functions), and others.

## Current status

The status of EIP-7692 is `Stagnant`.
EOF is not in the list of included EIPs in the Fusaka meta (EIP-7607), and Fusaka, which activated on 2025-12-03, does not contain EOF.
EOF is also not in the list of EIPs planned for inclusion in the Glamsterdam meta (EIP-7773).

Instead, Glamsterdam plans to include EIP-8024 (status `Last Call`), which adds `DUPN` (`0xe6`), `SWAPN` (`0xe7`), and `EXCHANGE` (`0xe8`) to the current EVM without EOF.
The same three instructions were defined for EOF by EIP-663 (status `Stagnant`), part of the EOF bundle.

Articles from 2024 were written assuming EOF would become the next form of the EVM.
Read them now as describing a format that is not planned for inclusion.

## Not yet shipped

Activation on mainnet.
Glamsterdam, with EIP-8024, activated on Sepolia on 2026-10-06, its Hoodi activation was postponed on 2026-10-22, and no mainnet date is set.
