---
tool: solc
since: 0.8.38
checked: 2026-11-16
source: Solidity 0.8.38 release announcement
---

# Solidity 0.8.38 fixes a Yul optimizer bug from 0.8.19

The Solidity 0.8.38 release announcement (2026-10-22) describes "a low-severity bug in the Yul optimizer" and says "Versions 0.8.19 through 0.8.37 are affected."
"Only code compiled with the Yul optimizer enabled is affected." With `--via-ir`, "any code may be affected"; with the default pipeline, only compiler-generated Yul utility functions and some inline assembly blocks.

When a project compiles with `via_ir` or the optimizer on a version from 0.8.19 to 0.8.37, suggest moving to 0.8.38 or later, and say why.
0.8.38 also warns when `swapn`, `dupn`, or `exchange` are used as Yul identifiers, since they become reserved from the Amsterdam EVM version.
