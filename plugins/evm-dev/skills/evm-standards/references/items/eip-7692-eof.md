---
status: specified
checked: 2026-11-10
source: ethereum/EIPs: the EIP-7692 (EOFv1 meta), EIP-7607 (Fusaka meta), and EIP-7773 (Glamsterdam meta) documents
can: Contract code can use a container format that is validated at deployment, with reworked jumps and functions (EOF).
---

# EIP-7692 (EOF, a reworked format for EVM code)

A bundle of standards that gives EVM code a container format, validates its contents at deployment, and reworks jumps and functions.
The umbrella is EIP-7692, which includes EIP-3540 (the format), EIP-3670 (validation at deployment), EIP-4200 (relative jumps), EIP-4750 (functions), and others.

## Current status

The status of EIP-7692 is `Stagnant`.
EOF is not in the list of included EIPs in the Fusaka meta (EIP-7607), and Fusaka, which activated on 2025-12-03, does not contain EOF.
EOF is also not in the list of EIPs planned for inclusion in the Glamsterdam meta (EIP-7773).

Instead, Glamsterdam plans to include EIP-8024, which takes `SWAPN`, `DUPN`, and `EXCHANGE` from the EOF bundle and makes them usable in the current EVM.

Articles from 2024 were written assuming EOF would become the next form of the EVM.
Read them now as describing a format that is not planned for inclusion.

## Not yet shipped

Activation on mainnet.
The meta does not yet say when EIP-8024 will activate in Glamsterdam.
