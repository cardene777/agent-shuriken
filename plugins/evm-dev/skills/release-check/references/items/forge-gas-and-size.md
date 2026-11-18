---
topic: tools
subject: Comparing gas with forge snapshot and contract sizes with forge build --sizes
checked: 2026-11-18
source: Foundry, forge snapshot, forge test, and forge build reference and the 1.8.0 and 1.9.0 release notes; Hardhat 3.22.0, test task and gas analytics options; forge 1.5.1 run on a throwaway project
---

# forge snapshot compares gas per test, and forge build --sizes shows the margin to the size limits

Gas:

- `forge snapshot` runs the tests and writes each test's gas to `.gas-snapshot`; `--snap <file>` writes it elsewhere
- `forge snapshot --diff <file>` prints the change per test against a saved snapshot, and `--check <file>` fails when any test differs
- `forge test --gas-report` prints gas per function of each contract
- Hardhat 3: `npx hardhat test --gas-stats`, and `--gas-stats-json <file>` to save it

Size:

- `forge build --sizes` prints each contract's Runtime Size, Initcode Size, Runtime Margin, and Initcode Margin against 24,576 and 49,152 bytes; a negative margin cannot deploy

For a release:

- Take the snapshot of the deployed version in its own folder with the same forge version, then run `forge snapshot --diff` against it in the new version; tests that exist in only one version have nothing to compare
- An old `.gas-snapshot` taken with another forge version can differ for reasons other than the code: Foundry 1.8.0 made isolate mode the default, and 1.9.0 charges creation gas for `new` under dynamic test linking
- Run `forge build --sizes` with the settings used for deployment (optimizer, `via_ir`), since they change the size
