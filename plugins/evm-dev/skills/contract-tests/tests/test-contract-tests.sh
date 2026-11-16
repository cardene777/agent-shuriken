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
        vm.expectRevert();
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
  bash "$PLUGIN/skills/evm-standards/scripts/evm-standards.sh" check > "$T/evm-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/solidity-code/tests/test-solidity-code.sh" > "$T/solidity-code.out" 2>&1 \
    && bash "$PLUGIN/skills/financial-standards/tests/test-financial-standards.sh" > "$T/financial-standards.out" 2>&1
}
check "the other evm-dev skills still pass their tests" others_kept

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
