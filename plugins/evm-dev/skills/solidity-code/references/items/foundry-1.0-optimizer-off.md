---
tool: foundry
since: 1.0.0
checked: 2026-11-18
source: Foundry v1.0.0 release notes, migration guide, and config reference
---

# The optimizer is off by default

Foundry 1.0 disabled the solc optimizer by default.
A project that wants it sets `optimizer = true`, usually with `optimizer_runs = 200`, in `foundry.toml`; setting `optimizer_runs` above 0 also turns it on.
Do not change the project's optimizer settings without saying so, since they change gas costs and bytecode.
