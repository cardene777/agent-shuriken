---
topic: tools
subject: Comparing gas with forge snapshot and contract sizes with forge build --sizes
checked: 2026-11-17
source: Foundry, forge snapshot, forge test, and forge build reference; Hardhat 3, test task reference; forge 1.5.1 run on a throwaway project
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

- Take the snapshot of the deployed version in its own folder, then run `forge snapshot --diff` against it in the new version; tests that exist in only one version have nothing to compare
- Run `forge build --sizes` with the settings used for deployment (optimizer, `via_ir`), since they change the size
