#!/usr/bin/env bash
# Tests for contract-tests.py, the bundled items, the SKILL.md, and the eval suite. Projects, tests,
# and items written here live in a throwaway folder; nothing reaches the network and nothing runs
# forge or Hardhat.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/contract-tests.py"
ITEMS="$SKILL_DIR/references/items"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
EVALS="$PLUGIN/evals"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

run() { python3 "$SCRIPT" "$@"; }

# item <folder> <name> <field lines...>: writes one item file with the given front matter lines.
item() {
  local d="$1" name="$2" line
  shift 2
  mkdir -p "$d"
  {
    printf -- '---\n'
    for line in "$@"; do printf '%s\n' "$line"; done
    printf -- '---\n\n# %s\n\nBody.\n' "$name"
  } > "$d/$name.md"
}

# line_of <file> <text>: the number of the first line of <file> that holds <text>.
line_of() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }

# The Foundry project: one contract with every kind of point, plus declarations that must not
# count (an interface, internal functions, commented-out code, and contracts under lib/, test/,
# and script/).
foundry_project() {
  local p="$1"
  mkdir -p "$p/src" "$p/lib/forge-std/src" "$p/test" "$p/script"
  printf '[profile.default]\nsrc = "src"\nout = "out"\nlibs = ["lib"]\n' > "$p/foundry.toml"
  cat > "$p/src/Vault.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVault {
    function deposit() external payable;
}

contract Vault {
    error ZeroAmount();
    error InsufficientBalance(uint256 available, uint256 requested);
    error NotOwner(address caller);

    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    address public owner;
    bool public paused;
    mapping(address => uint256) public balanceOf;
    uint256 public totalDeposits;

    // function oldDeposit(uint256 amount) external {}
    /* function legacy(uint256 amount) external onlyOwner {}
       error Legacy();
       event Old(uint256 amount); */

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        balanceOf[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(
        uint256 amount
    ) external {
        if (amount > balanceOf[msg.sender]) revert InsufficientBalance(balanceOf[msg.sender], amount);
        balanceOf[msg.sender] -= amount;
        totalDeposits -= amount;
        emit Withdrawn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    function setPaused(bool value) external onlyOwner {
        paused = value;
    }

    function sweep(address to) external {
        require(msg.sender == owner, "owner only");
        payable(to).transfer(address(this).balance - totalDeposits);
    }

    function preview(uint256 amount) external view returns (uint256) {
        return amount > totalDeposits ? totalDeposits : amount;
    }

    function _settle(uint256 amount) internal {
        totalDeposits -= amount;
    }
}
SOL
  cat > "$p/lib/forge-std/src/Test.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
contract Test {
    function libraryHelper(uint256 value) public {}
}
SOL
  cat > "$p/script/Deploy.s.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
contract Deploy {
    function run(uint256 salt) external {}
}
SOL
}

# Foundry tests that touch every point of Vault.
foundry_full_tests() {
  cat > "$1/test/Vault.t.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

contract VaultTest is Test {
    Vault vault;

    function setUp() public {
        vault = new Vault();
    }

    function test_deposit_emits() public {
        vm.expectEmit();
        emit Vault.Deposited(address(this), 1);
        vault.deposit{value: 1}();
    }

    function test_deposit_refuses_zero() public {
        vm.expectRevert(Vault.ZeroAmount.selector);
        vault.deposit();
    }

    function testFuzz_withdraw(uint256 amount) public {
        amount = bound(amount, 1, 10 ether);
        vm.deal(address(this), amount);
        vault.deposit{value: amount}();
        vm.expectEmit();
        emit Vault.Withdrawn(address(this), amount);
        vault.withdraw(amount);
    }

    function test_withdraw_refuses_more_than_the_balance() public {
        vm.expectRevert(abi.encodeWithSelector(Vault.InsufficientBalance.selector, 0, 1));
        vault.withdraw(1);
    }

    function test_setPaused_refuses_other_accounts() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(Vault.NotOwner.selector, address(1)));
        vault.setPaused(true);
    }

    function test_sweep_refuses_other_accounts() public {
        vm.prank(address(1));
        vm.expectRevert(bytes("owner only"));
        vault.sweep(address(1));
    }

    function test_preview() public view {
        assertEq(vault.preview(0), 0);
    }

    receive() external payable {}
}

contract VaultInvariantTest is Test {
    Vault vault;

    function setUp() public {
        vault = new Vault();
        targetContract(address(vault));
    }

    function invariant_total_matches_the_balance() public view {
        assertEq(vault.totalDeposits(), address(vault).balance);
    }
}
SOL
}

# Foundry tests that touch only some points: deposit with its event, setPaused without a revert on
# its own call, and withdraw without inputs from the fuzzer. The marker must never reach the output.
foundry_partial_tests() {
  cat > "$1/test/VaultPartial.t.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

contract VaultPartialTest is Test {
    Vault vault;
    string constant NOTE = "SECRET_TEST_MARKER";

    function setUp() public {
        vault = new Vault();
    }

    function test_deposit_emits() public {
        vm.expectEmit();
        emit Vault.Deposited(address(this), 1);
        vault.deposit{value: 1}();
    }

    function test_setPaused_by_the_owner() public {
        vault.setPaused(true);
        assertTrue(vault.paused());
    }

    function test_withdraw_one() public {
        vault.deposit{value: 1}();
        vault.withdraw(1);
    }

    // Expects a revert from withdraw, not from setPaused, so setPaused's access rule stays untested.
    function test_withdraw_after_pausing() public {
        vault.setPaused(true);
        vm.expectRevert();
        vault.withdraw(1);
    }

    receive() external payable {}
}
SOL
}

# Foundry tests that call deposit, and name everything else only in comments.
foundry_comment_tests() {
  cat > "$1/test/VaultComments.t.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

contract VaultCommentTest is Test {
    Vault vault;

    function setUp() public {
        vault = new Vault();
    }

    // vault.withdraw(1); ZeroAmount InsufficientBalance NotOwner Withdrawn vault.preview(1)
    function test_deposit_emits() public {
        vm.expectEmit();
        emit Vault.Deposited(address(this), 1);
        vault.deposit{value: 1}();
        /* function invariant_total() public { Vault }
           vm.expectRevert(); vault.setPaused(true); vault.sweep(address(1)); */
    }

    receive() external payable {}
}
SOL
}

# The Hardhat 3 project: a counter with an error, an event, an access rule, and a fuzz target but no
# balances, plus a Solidity test file next to it that must not count as a contract.
hardhat_project() {
  local p="$1"
  mkdir -p "$p/contracts" "$p/test" "$p/node_modules/hardhat"
  printf 'import { defineConfig } from "hardhat/config";\nexport default defineConfig({ solidity: "0.8.28" });\n' > "$p/hardhat.config.ts"
  printf '{"name": "hardhat", "version": "3.0.0"}\n' > "$p/node_modules/hardhat/package.json"
  cat > "$p/contracts/Counter.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Counter {
    error TooLarge(uint256 by);
    error NotOwner();

    event Increment(uint256 by);

    address public owner;
    uint256 public x;

    constructor() {
        owner = msg.sender;
    }

    function inc() public {
        x++;
        emit Increment(1);
    }

    function incBy(uint256 by) public {
        if (by > 100) revert TooLarge(by);
        x += by;
        emit Increment(by);
    }

    function reset() external {
        if (msg.sender != owner) revert NotOwner();
        x = 0;
    }
}
SOL
  cat > "$p/contracts/Counter.t.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
contract CounterSolidityTest {
    function test_nothing(uint256 seed) public {}
}
SOL
}

# Hardhat TypeScript tests (node:test with viem and fast-check) that touch every point of Counter.
hardhat_full_tests() {
  cat > "$1/test/Counter.ts" <<'TS'
import { describe, it } from "node:test";
import { network } from "hardhat";
import fc from "fast-check";

describe("Counter", async function () {
  const { viem } = await network.connect();

  // Each test deploys its own counter. SECRET_TEST_MARKER
  it("inc emits Increment", async function () {
    const counter = await viem.deployContract("Counter");
    await viem.assertions.emitWithArgs(counter.write.inc(), counter, "Increment", [1n]);
  });

  it("incBy adds any amount up to 100", async function () {
    await fc.assert(
      fc.asyncProperty(fc.bigInt({ min: 0n, max: 100n }), async (by) => {
        const counter = await viem.deployContract("Counter");
        await counter.write.incBy([by]);
      }),
    );
  });

  it("incBy refuses more than 100", async function () {
    const counter = await viem.deployContract("Counter");
    await viem.assertions.revertWithCustomError(counter.write.incBy([101n]), counter, "TooLarge");
  });

  it("reset refuses other accounts", async function () {
    const counter = await viem.deployContract("Counter");
    const [, other] = await viem.getWalletClients();
    await viem.assertions.revertWithCustomError(
      counter.write.reset({ account: other.account }),
      counter,
      "NotOwner",
    );
  });
});
TS
}

FOUNDRY="$T/foundry"
foundry_project "$FOUNDRY"
HARDHAT="$T/hardhat"
hardhat_project "$HARDHAT"
VAULT="$FOUNDRY/src/Vault.sol"
COUNTER="$HARDHAT/contracts/Counter.sol"

# has <file> <line>: the output file holds exactly this line.
has() { grep -qxF -- "$2" "$1"; }

# The bundled items must pass check, and both test toolchains need at least one item.
bundled_check() {
  [ -f "$SCRIPT" ] || return 1
  run check > "$T/bundled.out" 2>&1 || return 1
  grep -rqx 'tool: hardhat' "$ITEMS" || return 1
  grep -rqxE 'tool: (foundry|forge-std)' "$ITEMS"
}
check "check passes on the bundled items and covers Foundry and Hardhat" bundled_check

bad_items_named() {
  local d="$T/bad-items" out="$T/bad.out" status
  item "$d" good 'tool: hardhat' 'since: 3.0.0' 'checked: 2026-11-16' 'source: Nomic Foundation, Hardhat 3 documentation'
  item "$d" no-source 'tool: foundry' 'since: 1.0.0' 'checked: 2026-11-16'
  item "$d" unknown-tool 'tool: truffle' 'since: 5.0.0' 'checked: 2026-11-16' 'source: Truffle documentation'
  item "$d" impossible-date 'tool: forge-std' 'since: 1.9.0' 'checked: 2026-02-30' 'source: Foundry, forge-std release notes'
  run check --dir "$d" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] || return 1
  grep -q '^no-source: ' "$out" && grep -q '^unknown-tool: ' "$out" && grep -q '^impossible-date: ' "$out" || return 1
  ! grep -q '^good: ' "$out"
}
check "check names an item with a missing field, an unknown tool, or an impossible date" bad_items_named

# 2026-08-18 is 90 days before 2026-11-16 and stays fresh; 2026-08-17 is 91 days before and is stale.
stale_marked() {
  local d="$T/stale-items" out="$T/stale.out"
  item "$d" fresh-edge 'tool: hardhat' 'since: 3.0.0' 'checked: 2026-08-18' 'source: Nomic Foundation, Hardhat 3 documentation'
  item "$d" old-edge 'tool: foundry' 'since: 1.0.0' 'checked: 2026-08-17' 'source: Foundry, release notes for v1.0'
  run list --dir "$d" --today 2026-11-16 > "$out" 2>&1 || return 1
  grep -qE '^ok +hardhat +3\.0\.0 +2026-08-18 fresh-edge$' "$out" || return 1
  grep -qE '^stale +foundry +1\.0\.0 +2026-08-17 old-edge$' "$out" || return 1
  grep -q '^2 items, 1 stale as of 2026-11-16$' "$out"
}
check "list marks the items checked more than 90 days ago" stale_marked

points_listed() {
  local out="$T/points-foundry.out" hh="$T/points-hardhat.out" v="src/Vault.sol" c="contracts/Counter.sol"
  run points "$FOUNDRY" > "$out" 2>&1 || return 1
  has "$out" "function Vault.deposit $v:$(line_of "$VAULT" 'function deposit() external payable {')" || return 1
  has "$out" "function Vault.setPaused $v:$(line_of "$VAULT" 'function setPaused(')" || return 1
  has "$out" "function Vault.sweep $v:$(line_of "$VAULT" 'function sweep(')" || return 1
  has "$out" "function Vault.preview $v:$(line_of "$VAULT" 'function preview(')" || return 1
  has "$out" "error Vault.ZeroAmount $v:$(line_of "$VAULT" 'error ZeroAmount')" || return 1
  has "$out" "error Vault.InsufficientBalance $v:$(line_of "$VAULT" 'error InsufficientBalance')" || return 1
  has "$out" "error Vault.NotOwner $v:$(line_of "$VAULT" 'error NotOwner')" || return 1
  has "$out" "event Vault.Deposited $v:$(line_of "$VAULT" 'event Deposited')" || return 1
  has "$out" "event Vault.Withdrawn $v:$(line_of "$VAULT" 'event Withdrawn')" || return 1
  has "$out" "access Vault.setPaused $v:$(line_of "$VAULT" 'function setPaused(')" || return 1
  has "$out" "access Vault.sweep $v:$(line_of "$VAULT" 'function sweep(')" || return 1
  has "$out" "invariant Vault $v:$(line_of "$VAULT" 'contract Vault {')" || return 1
  # deposit takes no number, preview changes nothing, and setPaused takes a bool: none is a fuzz target.
  ! grep -qE '^(fuzz Vault\.(deposit|preview|setPaused)|access Vault\.(deposit|withdraw|preview)) ' "$out" || return 1
  # The interface, internal functions, constructor, and the contracts under lib/ and script/ stay out.
  ! grep -qE 'IVault|_settle|constructor|libraryHelper|Deploy|\.run ' "$out" || return 1
  grep -q '^points: 14 in 1 contract$' "$out" || return 1

  run points "$HARDHAT" > "$hh" 2>&1 || return 1
  has "$hh" "function Counter.inc $c:$(line_of "$COUNTER" 'function inc()')" || return 1
  has "$hh" "fuzz Counter.incBy $c:$(line_of "$COUNTER" 'function incBy(')" || return 1
  has "$hh" "access Counter.reset $c:$(line_of "$COUNTER" 'function reset(')" || return 1
  has "$hh" "error Counter.TooLarge $c:$(line_of "$COUNTER" 'error TooLarge')" || return 1
  has "$hh" "event Counter.Increment $c:$(line_of "$COUNTER" 'event Increment')" || return 1
  # Counter keeps no balances, and the Solidity test next to it is a test, not a contract.
  ! grep -qE '^invariant |CounterSolidityTest|test_nothing' "$hh" || return 1
  grep -q '^points: 8 in 1 contract$' "$hh"
}
check "points lists the functions, errors, events, access rules, fuzz targets, and invariants of each contract" points_listed

signatures_and_comments() {
  local out="$T/points-shape.out" v="src/Vault.sol"
  run points "$FOUNDRY" > "$out" 2>&1 || return 1
  has "$out" "function Vault.withdraw $v:$(line_of "$VAULT" 'function withdraw(')" || return 1
  has "$out" "fuzz Vault.withdraw $v:$(line_of "$VAULT" 'function withdraw(')" || return 1
  ! grep -qE 'oldDeposit|legacy|Legacy|Old' "$out"
}
check "points reads signatures over several lines and skips comments" signatures_and_comments

uncovered_named() {
  local p="$T/partial" out="$T/uncovered-partial.out" status v="src/Vault.sol"
  foundry_project "$p"
  foundry_partial_tests "$p"
  run uncovered "$p" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] || return 1
  has "$out" "uncovered function Vault.sweep $v:$(line_of "$VAULT" 'function sweep(')" || return 1
  has "$out" "uncovered function Vault.preview $v:$(line_of "$VAULT" 'function preview(')" || return 1
  has "$out" "uncovered error Vault.ZeroAmount $v:$(line_of "$VAULT" 'error ZeroAmount')" || return 1
  has "$out" "uncovered error Vault.InsufficientBalance $v:$(line_of "$VAULT" 'error InsufficientBalance')" || return 1
  has "$out" "uncovered error Vault.NotOwner $v:$(line_of "$VAULT" 'error NotOwner')" || return 1
  has "$out" "uncovered event Vault.Withdrawn $v:$(line_of "$VAULT" 'event Withdrawn')" || return 1
  has "$out" "uncovered access Vault.setPaused $v:$(line_of "$VAULT" 'function setPaused(')" || return 1
  has "$out" "uncovered access Vault.sweep $v:$(line_of "$VAULT" 'function sweep(')" || return 1
  has "$out" "uncovered fuzz Vault.withdraw $v:$(line_of "$VAULT" 'function withdraw(')" || return 1
  has "$out" "uncovered invariant Vault $v:$(line_of "$VAULT" 'contract Vault {')" || return 1
  # deposit, its event, setPaused, and withdraw are called or named by a test.
  ! grep -qE '^uncovered (function Vault\.(deposit|setPaused|withdraw)|event Vault\.Deposited) ' "$out" || return 1
  grep -q '^uncovered: 10 of 14 points have no test$' "$out" || return 1
  ! grep -qE 'SECRET_TEST_MARKER|vault\.deposit|assertTrue' "$out"
}
check "uncovered names each point no test touches without printing the tests" uncovered_named

uncovered_foundry_full() {
  local p="$T/full-foundry" out="$T/uncovered-foundry.out"
  foundry_project "$p"
  foundry_full_tests "$p"
  run uncovered "$p" > "$out" 2>&1 || return 1
  grep -q '^uncovered: every point has a test (14 points)$' "$out"
}
check "uncovered passes when Foundry tests touch every point" uncovered_foundry_full

uncovered_hardhat_full() {
  local p="$T/full-hardhat" out="$T/uncovered-hardhat.out"
  hardhat_project "$p"
  hardhat_full_tests "$p"
  run uncovered "$p" > "$out" 2>&1 || return 1
  grep -q '^uncovered: every point has a test (8 points)$' "$out" || return 1
  ! grep -q 'SECRET_TEST_MARKER' "$out"
}
check "uncovered passes when Hardhat TypeScript tests touch every point" uncovered_hardhat_full

comments_not_counted() {
  local p="$T/comments" out="$T/uncovered-comments.out" status v="src/Vault.sol"
  foundry_project "$p"
  foundry_comment_tests "$p"
  run uncovered "$p" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] || return 1
  has "$out" "uncovered function Vault.withdraw $v:$(line_of "$VAULT" 'function withdraw(')" || return 1
  has "$out" "uncovered function Vault.preview $v:$(line_of "$VAULT" 'function preview(')" || return 1
  has "$out" "uncovered function Vault.setPaused $v:$(line_of "$VAULT" 'function setPaused(')" || return 1
  has "$out" "uncovered error Vault.ZeroAmount $v:$(line_of "$VAULT" 'error ZeroAmount')" || return 1
  has "$out" "uncovered event Vault.Withdrawn $v:$(line_of "$VAULT" 'event Withdrawn')" || return 1
  has "$out" "uncovered access Vault.sweep $v:$(line_of "$VAULT" 'function sweep(')" || return 1
  has "$out" "uncovered invariant Vault $v:$(line_of "$VAULT" 'contract Vault {')" || return 1
  ! grep -qE '^uncovered (function Vault\.deposit|event Vault\.Deposited) ' "$out"
}
check "uncovered does not count a name that only appears in a comment" comments_not_counted

# Foundry tests that reach withdraw only through helpers that take parameters: an internal one called
# from a test without parameters, and a public one whose name does not start with test.
foundry_helper_tests() {
  cat > "$1/test/VaultHelpers.t.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

contract VaultHelperTest is Test {
    Vault vault;

    function setUp() public {
        vault = new Vault();
    }

    function _depositAndWithdraw(uint256 amount) internal {
        vault.deposit{value: amount}();
        vault.withdraw(amount);
    }

    function withdrawTwice(uint256 amount) public {
        vault.withdraw(amount);
        vault.withdraw(amount);
    }

    function test_withdraw_one() public {
        _depositAndWithdraw(1);
    }

    receive() external payable {}
}
SOL
}

fuzz_needs_a_test_function() {
  local p="$T/helpers" out="$T/uncovered-helpers.out" status v="src/Vault.sol"
  foundry_project "$p"
  foundry_helper_tests "$p"
  run uncovered "$p" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] || return 1
  has "$out" "uncovered fuzz Vault.withdraw $v:$(line_of "$VAULT" 'function withdraw(')" || return 1
  # The test still calls withdraw, so the function point itself is covered.
  ! grep -q '^uncovered function Vault\.withdraw ' "$out"
}
check "uncovered counts a fuzz point only when a test function with parameters calls it" fuzz_needs_a_test_function

# access_test_file <file> <contract import> <contract> <test lines...>: a Foundry test file whose
# functions each hold one line of the form `<function>|<expectation>|<call>`.
access_test_file() {
  local file="$1" import="$2" name="$3" line fn expectation call
  shift 3
  {
    printf '// SPDX-License-Identifier: MIT\npragma solidity ^0.8.28;\n\n'
    printf 'import {Test} from "forge-std/Test.sol";\nimport {%s} from "%s";\n\n' "$name" "$import"
    printf 'contract AccessTest is Test {\n    %s target = new %s();\n' "$name" "$name"
    for line in "$@"; do
      IFS='|' read -r fn expectation call <<< "$line"
      printf '\n    function %s() public {\n        vm.prank(address(1));\n        %s\n        %s\n    }\n' \
        "$fn" "$expectation" "$call"
    done
    printf '}\n'
  } > "$file"
}

# The Foundry sample guards setPaused with its own onlyOwner modifier, which reverts with NotOwner,
# and sweep with require(msg.sender == owner, "owner only").
access_needs_the_guard_error() {
  local p="$T/access-error" out="$T/uncovered-access-error.out" v="src/Vault.sol"
  foundry_project "$p"
  # A bare expectRevert, and the error of another check, leave both access points untested.
  access_test_file "$p/test/Access.t.sol" "../src/Vault.sol" Vault \
    'test_setPaused_refuses|vm.expectRevert();|target.setPaused(true);' \
    'test_sweep_refuses|vm.expectRevert(Vault.ZeroAmount.selector);|target.sweep(address(1));'
  run uncovered "$p" > "$out" 2>&1
  has "$out" "uncovered access Vault.setPaused $v:$(line_of "$VAULT" 'function setPaused(')" || { echo "      a bare expectRevert counted for setPaused"; return 1; }
  has "$out" "uncovered access Vault.sweep $v:$(line_of "$VAULT" 'function sweep(')" || { echo "      another error counted for sweep"; return 1; }
  # The guard's custom error and the guard's revert string count.
  access_test_file "$p/test/Access.t.sol" "../src/Vault.sol" Vault \
    'test_setPaused_refuses|vm.expectRevert(abi.encodeWithSelector(Vault.NotOwner.selector, address(1)));|target.setPaused(true);' \
    'test_sweep_refuses|vm.expectRevert(bytes("owner only"));|target.sweep(address(1));'
  run uncovered "$p" > "$out" 2>&1
  ! grep -qE '^uncovered access Vault\.(setPaused|sweep) ' "$out" || { echo "      the guard's error did not count"; return 1; }
}
check "uncovered counts an access point only when a test expects the error its guard raises" access_needs_the_guard_error

# A contract guarded by OpenZeppelin's onlyOwner, onlyRole, and restricted, none of them declared in
# the project, so their errors come from the names of the modifiers.
oz_guarded_project() {
  local p="$1"
  mkdir -p "$p/src" "$p/test" "$p/lib/forge-std/src"
  printf '[profile.default]\nsrc = "src"\nout = "out"\nlibs = ["lib"]\n' > "$p/foundry.toml"
  printf 'contract Test {}\n' > "$p/lib/forge-std/src/Test.sol"
  cat > "$p/src/Guarded.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

contract Guarded is Ownable, AccessControl, AccessManaged {
    bytes32 public constant MINTER = keccak256("MINTER");

    constructor(address manager) Ownable(msg.sender) AccessManaged(manager) {}

    function setFee(uint256 fee) external onlyOwner {}

    function mint(address to) external onlyRole(MINTER) {}

    function pause() external restricted {}
}
SOL
}

oz_guard_errors() {
  local p="$T/oz-guards" out="$T/uncovered-oz.out" g="src/Guarded.sol"
  oz_guarded_project "$p"
  # Each test expects the error of another guard, so no access point counts.
  access_test_file "$p/test/Guarded.t.sol" "../src/Guarded.sol" Guarded \
    'test_setFee|vm.expectRevert(abi.encodeWithSelector(AccessControl.AccessControlUnauthorizedAccount.selector, address(1), bytes32(0)));|target.setFee(1);' \
    'test_mint|vm.expectRevert(abi.encodeWithSelector(AccessManaged.AccessManagedUnauthorized.selector, address(1)));|target.mint(address(1));' \
    'test_pause|vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1)));|target.pause();'
  run uncovered "$p" > "$out" 2>&1
  has "$out" "uncovered access Guarded.setFee $g:$(line_of "$p/$g" 'function setFee(')" || { echo "      setFee counted another guard's error"; return 1; }
  has "$out" "uncovered access Guarded.mint $g:$(line_of "$p/$g" 'function mint(')" || { echo "      mint counted another guard's error"; return 1; }
  has "$out" "uncovered access Guarded.pause $g:$(line_of "$p/$g" 'function pause(')" || { echo "      pause counted another guard's error"; return 1; }
  # Each test expects its own guard's error.
  access_test_file "$p/test/Guarded.t.sol" "../src/Guarded.sol" Guarded \
    'test_setFee|vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1)));|target.setFee(1);' \
    'test_mint|vm.expectRevert(abi.encodeWithSelector(AccessControl.AccessControlUnauthorizedAccount.selector, address(1), target.MINTER()));|target.mint(address(1));' \
    'test_pause|vm.expectRevert(abi.encodeWithSelector(AccessManaged.AccessManagedUnauthorized.selector, address(1)));|target.pause();'
  run uncovered "$p" > "$out" 2>&1
  ! grep -qE '^uncovered access Guarded\.' "$out" || { echo "      $(grep -E '^uncovered access' "$out" | head -1)"; return 1; }
}
check "uncovered takes the error of OpenZeppelin's guards from their modifiers" oz_guard_errors

# Hardhat tests of Counter.reset, which reverts with NotOwner: bare revert checks do not count, and
# the viem and ethers checks that name NotOwner do.
hardhat_access_errors() {
  local p="$T/hardhat-access" out="$T/uncovered-hardhat-access.out" c="contracts/Counter.sol"
  hardhat_project "$p"
  cat > "$p/test/Access.ts" <<'TS'
import { describe, it } from "node:test";
import { network } from "hardhat";

describe("Counter access", async function () {
  const { viem } = await network.connect();

  it("reset refuses other accounts", async function () {
    const counter = await viem.deployContract("Counter");
    const [, other] = await viem.getWalletClients();
    await viem.assertions.revert(counter.write.reset({ account: other.account }));
  });

  it("reset refuses other accounts with ethers", async function () {
    await expect(counter.connect(other).reset()).to.be.reverted;
  });
});
TS
  run uncovered "$p" > "$out" 2>&1
  has "$out" "uncovered access Counter.reset $c:$(line_of "$p/$c" 'function reset(')" || { echo "      a bare revert check counted"; return 1; }
  cat > "$p/test/Access.ts" <<'TS'
import { describe, it } from "node:test";
import { network } from "hardhat";

describe("Counter access", async function () {
  it("reset refuses other accounts with ethers", async function () {
    await expect(counter.connect(other).reset()).to.be.revertedWithCustomError(counter, "NotOwner");
  });
});
TS
  run uncovered "$p" > "$out" 2>&1
  ! grep -q '^uncovered access Counter\.reset ' "$out" || { echo "      revertedWithCustomError did not count"; return 1; }
}
check "uncovered reads the expected error of Hardhat tests for access points" hardhat_access_errors

# Guards whose error cannot be read: a require on msg.sender without a message, and onlyGovernance
# from a dependency that the project does not declare.
unread_guard_project() {
  local p="$1"
  mkdir -p "$p/src" "$p/test" "$p/lib/forge-std/src"
  printf '[profile.default]\nsrc = "src"\nout = "out"\nlibs = ["lib"]\n' > "$p/foundry.toml"
  printf 'contract Test {}\n' > "$p/lib/forge-std/src/Test.sol"
  cat > "$p/src/Fees.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Governed} from "governance/Governed.sol";

contract Fees is Governed {
    address public owner = msg.sender;

    function kill() external {
        require(msg.sender == owner);
    }

    function setFee(uint256 fee) external onlyGovernance {}
}
SOL
}

unread_guard_needs_a_named_error() {
  local p="$T/unread-guard" out="$T/uncovered-unread.out" f="src/Fees.sol"
  unread_guard_project "$p"
  access_test_file "$p/test/Fees.t.sol" "../src/Fees.sol" Fees \
    'test_kill|vm.expectRevert();|target.kill();' \
    'test_setFee|vm.expectRevert();|target.setFee(1);'
  run uncovered "$p" > "$out" 2>&1
  has "$out" "uncovered access Fees.kill $f:$(line_of "$p/$f" 'function kill(')" || { echo "      a bare expectRevert counted for kill"; return 1; }
  has "$out" "uncovered access Fees.setFee $f:$(line_of "$p/$f" 'function setFee(')" || { echo "      a bare expectRevert counted for setFee"; return 1; }
  access_test_file "$p/test/Fees.t.sol" "../src/Fees.sol" Fees \
    'test_kill|vm.expectRevert(bytes(""));|target.kill();' \
    'test_setFee|vm.expectRevert(Governed.NotGovernance.selector);|target.setFee(1);'
  run uncovered "$p" > "$out" 2>&1
  ! grep -qE '^uncovered access Fees\.' "$out" || { echo "      $(grep -E '^uncovered access' "$out" | head -1)"; return 1; }
}
check "uncovered asks for a named error when it cannot read the guard's error" unread_guard_needs_a_named_error

access_documented() {
  python3 -c 'import ast, sys
doc = ast.get_docstring(ast.parse(open(sys.argv[1], encoding="utf-8").read()))
sys.exit(0 if "OwnableUnauthorizedAccount" in doc and "the error its guard raises" in doc else 1)' "$SCRIPT" || return 1
  grep -E '^\| `access` \|' "$PLUGIN/docs/how-it-works.md" | grep -q 'the error its guard raises' || return 1
  grep -E '^\| `access` \|' "$PLUGIN/docs/how-it-works.ja.md" | grep -q 'OwnableUnauthorizedAccount'
}
check "the docs say an access point needs the error its guard raises" access_documented

changelog_access() {
  awk '/^## \[/ { on = 1 } on' "$PLUGIN/CHANGELOG.md" | grep '^- ' | grep -q 'the error its guard raises'
}
check "the changelog names the error an access test must expect" changelog_access

# A contract behind OpenZeppelin's AccessManaged: restricted guards setCap and pause, whenNotPaused
# alone guards nothing, and a name that only starts with restricted is not the modifier.
managed_project() {
  local p="$1"
  mkdir -p "$p/src" "$p/test"
  printf '[profile.default]\nsrc = "src"\nout = "out"\nlibs = ["lib"]\n' > "$p/foundry.toml"
  cat > "$p/src/Managed.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

contract Managed is AccessManaged {
    uint256 public cap;
    bool public paused;

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier restrictedTo(address account) {
        _;
    }

    constructor(address manager) AccessManaged(manager) {}

    function setCap(uint256 newCap) external restricted {
        cap = newCap;
    }

    function pause()
        external
        restricted
        whenNotPaused
    {
        paused = true;
    }

    function poke() external whenNotPaused {
        cap += 0;
    }

    function nudge(address account) external restrictedTo(account) {
        cap += 0;
    }
}
SOL
}

restricted_is_access() {
  local p="$T/managed" out="$T/points-managed.out" m
  managed_project "$p"
  m="$p/src/Managed.sol"
  run points "$p" > "$out" 2>&1 || return 1
  has "$out" "access Managed.setCap src/Managed.sol:$(line_of "$m" 'function setCap(')" || return 1
  has "$out" "access Managed.pause src/Managed.sol:$(line_of "$m" 'function pause(')" || return 1
  ! grep -qE '^access Managed\.(poke|nudge) ' "$out"
}
check "points lists functions guarded by restricted as access points" restricted_is_access

# Membership keeps a mapping whose key and value are named; Points keeps its mapping inside an
# ERC-7201 namespaced struct; Allowlist names its mapping's parts but maps to a bool, so it holds no
# amount to check.
mappings_project() {
  local p="$1"
  mkdir -p "$p/src" "$p/test"
  printf '[profile.default]\nsrc = "src"\n' > "$p/foundry.toml"
  cat > "$p/src/Membership.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Membership {
    mapping(address account => uint256 tokenId) public memberToken;

    function issue(address account, uint256 tokenId) external {
        memberToken[account] = tokenId;
    }
}
SOL
  cat > "$p/src/Points.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Points {
    /// @custom:storage-location erc7201:example.points
    struct PointsStorage {
        uint256 totalMinted;
        mapping(uint256 day => uint256 amount) mintedOnDay;
    }

    function mint(uint256 day, uint256 amount) external {
        PointsStorage storage $ = _points();
        $.mintedOnDay[day] += amount;
        $.totalMinted += amount;
    }

    function _points() private pure returns (PointsStorage storage $) {
        assembly {
            $.slot := 0x1234
        }
    }
}
SOL
  cat > "$p/src/Allowlist.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Allowlist {
    mapping(address account => bool allowed) public isAllowed;

    function allow(address account) external {
        isAllowed[account] = true;
    }
}
SOL
}

named_and_struct_mappings() {
  local p="$T/mappings" out="$T/points-mappings.out"
  mappings_project "$p"
  run points "$p" > "$out" 2>&1 || return 1
  has "$out" "invariant Membership src/Membership.sol:$(line_of "$p/src/Membership.sol" 'contract Membership {')" || return 1
  has "$out" "invariant Points src/Points.sol:$(line_of "$p/src/Points.sol" 'contract Points {')" || return 1
  ! grep -q '^invariant Allowlist ' "$out"
}
check "points lists a contract with a named mapping or a mapping in a struct as an invariant point" named_and_struct_mappings

no_urls() {
  [ -d "$ITEMS" ] || return 1
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 2 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no item holds a URL" no_urls

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Run `points`' \
    'kiwa-design' \
    'kiwa-forge' \
    'kiwa-hardhat' \
    'do not write the test files yourself' \
    'unit, fuzz, and invariant tests' \
    'Run `uncovered`' \
    'the command and its first error line' \
    'Never change a contract to make a test pass' \
    'solidity-code skill' \
    '`project`' \
    '`scan`' \
    'Run `list`' \
    're-check it against the official document' \
    'use the evm-standards skill' \
    'Never read a private key or a mnemonic' \
    'never sign' \
    'refuse a command that passes a key' \
    'throwaway' \
    'Never read `.env` files' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the SKILL.md keeps its rules" skill_rules

# The body is counted in words and the description in characters, as the size the agent reads.
SKILL_WORDS_MAX=600
SKILL_DESCRIPTION_MAX=300
skill_size() {
  [ -f "$SKILL" ] || return 1
  python3 - "$SKILL" "$SKILL_WORDS_MAX" "$SKILL_DESCRIPTION_MAX" <<'PYEOF'
import re, sys
front, body = open(sys.argv[1], encoding="utf-8").read().split("---", 2)[1:]
words = len(body.split())
chars = len(re.search(r"^description: (.*)$", front, re.M).group(1))
print("      SKILL.md body %d words (max %s), description %d characters (max %s)" % (words, sys.argv[2], chars, sys.argv[3]))
sys.exit(0 if words <= int(sys.argv[2]) and chars <= int(sys.argv[3]) else 1)
PYEOF
}
check "the SKILL.md stays within its size limits" skill_size

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). The two test cases start from a project without tests and
# without kiwa; the unrelated case grades that the skill did not start.
CASES=(foundry-vault-tests hardhat3-counter-tests tests-unrelated-request)
eval_suite() {
  local c home cwd
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    cwd="$home/cwd"
    mkdir -p "$cwd"
    (cd "$cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    [ -z "$(find "$home" -iname '*kiwa*' 2>/dev/null)" ] || return 1
    if [ "$c" = tests-unrelated-request ]; then
      grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" && grep -q "input_match: 'contract-tests'" "$EVALS/$c/case.yaml" || return 1
      continue
    fi
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" && grep -q "input_match: 'contract-tests'" "$EVALS/$c/case.yaml" || return 1
    [ -z "$(find "$cwd" -path "$cwd/lib" -prune -o -path "$cwd/node_modules" -prune -o \( -name '*.t.sol' -o -name '*.test.*' \) -print 2>/dev/null)" ] || return 1
    if [ "$c" = foundry-vault-tests ]; then
      [ -f "$cwd/foundry.toml" ] && [ -f "$cwd/src/Vault.sol" ] || return 1
    else
      [ -f "$cwd/hardhat.config.ts" ] && [ -f "$cwd/contracts/Counter.sol" ] || return 1
      grep -qE '"version": "3\.' "$cwd/node_modules/hardhat/package.json" || return 1
    fi
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its contract-tests cases and each fixture builds its state" eval_suite

readmes_list() {
  grep -qF '/evm-dev:contract-tests' "$REPO/README.md" && grep -qF '/evm-dev:contract-tests' "$REPO/README.ja.md"
}
check "the root READMEs list /evm-dev:contract-tests" readmes_list

others_kept() {
  # A test that another skill's test runs skips this check: the outer test runs every other skill's
  # tests once itself, so the same tests are not run again inside each other.
  [ -n "${EVM_DEV_NESTED:-}" ] && return 0
  local EVM_DEV_NESTED=1
  export EVM_DEV_NESTED
  bash "$PLUGIN/skills/evm-standards/scripts/evm-standards.sh" check > "$T/evm-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/solidity-code/tests/test-solidity-code.sh" > "$T/solidity-code.out" 2>&1 \
    && bash "$PLUGIN/skills/financial-standards/tests/test-financial-standards.sh" > "$T/financial-standards.out" 2>&1
}
check "the other evm-dev skills still pass their tests" others_kept

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
