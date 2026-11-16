---
tool: foundry
since: 1.0.0
checked: 2026-11-17
source: Foundry configuration reference, the testing section, and the Foundry Book on invariant testing
---

# Foundry's invariant runs drop reverted calls unless fail_on_revert is on

From Foundry 1.0.0 on, the `[invariant]` section of `foundry.toml` defaults to `runs = 256`, `depth = 500`, `fail_on_revert = false`, and `show_metrics = true`.
With `fail_on_revert = false`, a call that reverts during a run is dropped without failing the test, so a suite whose handler calls all revert still passes and proves nothing.

- Call the contract through a handler that keeps inputs in range with `bound`, and point `targetContract` at the handler
- Read the metrics table that `show_metrics` prints, and fix a handler whose calls always revert
- Turn the setting on for one suite with `/// forge-config: default.invariant.fail-on-revert = true` above the invariant function

`afterInvariant()` runs once after each run, and a revert or a failed assertion in it fails the test.
