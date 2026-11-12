# Testing a hypothesis

Five ways to test a hypothesis, and when to use each.

## 1. Logging

The fastest way to see the actual values, and the first thing to try.

```typescript
function calculate(x: number) {
  console.log('[calc] input:', x)
  const step1 = x * 2
  console.log('[calc] step1:', step1)
  const step2 = step1 + 10
  console.log('[calc] step2:', step2)
  return step2
}
```

- Compare the actual values with what you assumed
- Start each line with a prefix such as `[calc]` so the output is easy to filter
- Remove every line before finishing, or put it behind a debug flag

In Python use `print()`, in Bash use `echo "DEBUG: $var" >&2`, and in Solidity use `console.log()` from `forge-std` in `forge test`.
Never log a password, token, or key.

## 2. A debugger

Step through the code and watch the state change.

- Node.js: `node --inspect-brk script.js`, then attach a browser's developer tools or your editor
- Python: `breakpoint()`, available since Python 3.7
- Bash: `set -x` prints every command as it runs
- Solidity: `forge test -vvvv` prints a full trace

A debugger helps where logging is hard to follow: nested async code, event loops, and recursion.

## 3. Binary search with `git bisect`

Find when the bug started and which commit introduced it.
Run it only when `git status` shows no uncommitted changes, because it checks out other commits.

```bash
git bisect start
git bisect bad HEAD           # the current commit fails
git bisect good v1.0.0        # an older version that worked
# git checks out a commit in between; test it and report the result
git bisect good               # or: git bisect bad
# repeat until git names the first bad commit
git bisect reset              # always return to where you started
```

It suits bugs whose start the logs cannot show, and it needs only about log₂ N tests for N commits.
When a command can tell good from bad by its exit code, `git bisect run <command>` does the testing for you.

## 4. A minimal reproduction

Cut the problem down to the smallest script that still shows it.
This removes outside factors such as the environment, dependencies, and data, and leaves only the bug.

```typescript
// not the 500 lines of the app, only the 20 lines needed to show the bug
import { targetFn } from './target'

const input = { /* the smallest case that fails */ }
const result = targetFn(input)
console.log(result)  // expected X, got Y
```

- It is required when reporting a bug in a third-party library, so the maintainers can reproduce it
- It tests an assumption with nothing else in the way

## 5. A property test

Test a general property instead of one case, which finds edge cases you did not think of.

```typescript
import { test, fc } from '@fast-check/vitest'
import { expect } from 'vitest'

test.prop([fc.integer()])('abs is never negative', (x) => {
  expect(Math.abs(x)).toBeGreaterThanOrEqual(0)
})
```

Tools such as fast-check for TypeScript, Hypothesis for Python, and Echidna or Foundry's fuzzing for Solidity generate the inputs.

## Which to use

| Situation | Method |
|---|---|
| A simple flow you want to iterate on quickly | Logging |
| A complex flow whose state changes you need to watch | A debugger |
| You need to know when the bug started | `git bisect` |
| You need to separate the bug from everything around it | A minimal reproduction |
| You want to find edge cases or pin down the expected behavior | A property test |

They combine well: check the state with logging, find the suspect commit with `git bisect`, cut it down to a minimal reproduction, then fix it and add a property test to cover the general case.

## Recording the results

Write each hypothesis and its result in the report, and in the commit message or pull request when the user asks for one.

```
Hypothesis 1: A is null, and B dereferences it
Test: logged A, and it is not null (input parsing had turned it into an empty string)
Result: refuted

Hypothesis 2: the parser turns an empty string into null
Test: a unit test that parses "" returns null, as the hypothesis predicts
Result: confirmed
Root cause: the parser's handling of empty strings
```

The next person who meets the same pattern can find it.
