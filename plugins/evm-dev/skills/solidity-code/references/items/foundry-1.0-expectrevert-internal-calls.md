---
tool: foundry
since: 1.0.0
checked: 2026-11-16
source: Foundry v1.0 migration guide and the Foundry config reference
---

# expectRevert does not catch internal calls by default

From Foundry 1.0, "`vm.expectRevert` no longer applies to internal calls by default."
A test that expects a revert from a library function or an internal call fails with "call didn't revert at a lower depth than cheatcode call depth".

Call the code through an external call, such as a contract or a harness, or allow it for one test with `/// forge-config: default.allow_internal_expect_revert = true`.
The project-wide setting is `allow_internal_expect_revert` in `foundry.toml`, `false` by default.
