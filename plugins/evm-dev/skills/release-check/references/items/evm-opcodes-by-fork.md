---
topic: evm
subject: Opcodes added by each EVM version, and the version solc and Foundry compile for by default
checked: 2026-11-18
source: Ethereum execution specifications (the opcode lists per fork); EIP-7773 and EIP-7843; Solidity documentation, Using the compiler (Target options) and the 0.8.30, 0.8.31, 0.8.36, and 0.8.37 release notes; Foundry, 1.7.0 release notes and the default evm_version change; Hardhat 3.22.0, default EVM targets table; forge 1.5.1 and solc 0.8.30 run on a throwaway project
---

# Code compiled for a newer EVM version may use opcodes an older chain rejects

solc emits opcodes for the EVM version it targets, also where the source never names them: copying memory compiles to `MCOPY` from `cancun` on, and pushing a zero compiles to `PUSH0` from `shanghai` on. A chain that has not reached that version rejects the opcode, so the deployment or the call reverts.

| Version | Opcodes it added |
|---|---|
| `byzantium` | `RETURNDATASIZE` (0x3d), `RETURNDATACOPY` (0x3e), `STATICCALL` (0xfa), `REVERT` (0xfd) |
| `constantinople` | `SHL` (0x1b), `SHR` (0x1c), `SAR` (0x1d), `EXTCODEHASH` (0x3f), `CREATE2` (0xf5) |
| `istanbul` | `CHAINID` (0x46), `SELFBALANCE` (0x47) |
| `london` | `BASEFEE` (0x48) |
| `shanghai` | `PUSH0` (0x5f) |
| `cancun` | `TLOAD` (0x5c), `TSTORE` (0x5d), `MCOPY` (0x5e), `BLOBHASH` (0x49), `BLOBBASEFEE` (0x4a) |
| `osaka` | `CLZ` (0x1e) |

The versions in order: `homestead`, `tangerineWhistle`, `spuriousDragon`, `byzantium`, `constantinople`, `petersburg`, `istanbul`, `berlin`, `london`, `paris`, `shanghai`, `cancun`, `prague`, `osaka`. `prague` added no opcode. solc 0.8.36 and later also accept `amsterdam` (the Glamsterdam fork), which Ethereum mainnet has not activated as of 2026-11-18; `block.slotnum` compiles to `SLOTNUM` (0x4b), which needs it.

Defaults when the project sets no `evm_version`:

- solc 0.8.30 targets `prague`; solc 0.8.31 and later target `osaka`
- Foundry 1.7.0 and later pass `osaka` to solc; forge 1.5.1 passed `prague`
- Hardhat uses `osaka` for solc 0.8.31 and later

For a release:

- Set `evm_version` in `foundry.toml` or in the Hardhat solidity settings to the oldest version among the target chains, instead of relying on the default
- `transient` state variables and `tload`, `tstore`, and `mcopy` in inline assembly need `cancun`; compiling for an older version fails, so the code itself must change
