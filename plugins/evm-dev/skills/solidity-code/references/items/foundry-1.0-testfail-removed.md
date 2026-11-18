---
tool: foundry
since: 1.0.0
checked: 2026-11-18
source: Foundry v1.0 migration guide and v1.0.0 release notes
detect: function\s+testFail
---

# testFail tests are gone

Foundry 1.0 (2025-02-10) removed `testFail*` tests: "`testFail`-prefixed tests are no longer supported. Replace them with explicit revert tests".

```solidity
function test_RevertWhen_NotAuthorized() public {
    vm.expectRevert("Not authorized");
    target.doSomething();
}
```
