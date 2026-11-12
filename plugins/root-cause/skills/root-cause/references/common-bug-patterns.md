# Common bug patterns

Fifteen patterns to suspect first.
Match the symptom against this list to pick the first hypotheses.

## 1. Null or undefined dereference

**Symptom**: `Cannot read properties of undefined (reading 'x')`, or `'NoneType' object has no attribute 'x'`

**Likely causes**: a missing optional chain (`?.`), an API that started returning null, or async state that is not initialized yet

**How to check**: log the value along the way, and find the line in the stack trace

## 2. Off by one

**Symptom**: a loop skips the first or last element, or an index goes out of range

**Likely causes**: `<` versus `<=`, counting from 0 versus 1, or a forgotten `length - 1`

**How to check**: unit tests at the boundaries, such as 0, 1, and the length

## 3. Race condition

**Symptom**: the failure happens only sometimes, and the order of log lines changes between runs

**Likely causes**: async work with no guaranteed order, shared state updated without atomicity, or an event listener attached twice

**How to check**: add a deliberate delay at the suspect point. If the failure then happens every time or never, it depends on timing

## 4. Time zone or locale

**Symptom**: a date test passes on your machine and fails on a server that runs in UTC

**Likely causes**: `new Date()` depending on the local time zone, or `toString()` and `toLocaleString()` depending on the environment

**How to check**: run `date` to see the time zone, and set the time zone explicitly in the test, for example with `TZ=UTC`

## 5. Encoding, byte order marks, and line endings

**Symptom**: string comparisons fail, or text read from a file starts with an invisible character

**Likely causes**: a file that is not UTF-8, a byte order mark at the start, or Windows line endings (CRLF) where Unix line endings (LF) were expected

**How to check**: `file -I <file>` on macOS or `file -i <file>` on Linux shows the encoding, and `hexdump -C <file> | head` shows the bytes

## 6. Type coercion

**Symptom**: `"0" == false` is true while `"0" === false` is false, or `1 + "1"` gives `"11"` in JavaScript

**Likely causes**: loose equality instead of strict equality (`===`), or an implicit type conversion

**How to check**: print `typeof` for each operand, and switch to strict equality

## 7. A missing `await`

**Symptom**: promises resolve in an unexpected order, or a function returns a pending promise or `undefined`

**Likely causes**: a forgotten `await`, sequential awaits where `Promise.all` was meant, or a missing `await` inside `try`, so the error escapes the `catch`

**How to check**: follow each promise explicitly, and make sure every async call is awaited or returned

## 8. Regular expression greed and anchors

**Symptom**: a regular expression matches more or less than intended

**Likely causes**: a greedy `.*`, missing `^` and `$` anchors, or missing or extra flags such as `i`, `g`, and `m`

**How to check**: test the pattern against sample strings in a unit test or a regular expression tester

## 9. Cache invalidation

**Symptom**: old data comes back, or an update does not show

**Likely causes**: a time to live that is too long, colliding cache keys, or no invalidation when the data changes

**How to check**: clear the cache. If the symptom disappears, the cache is involved, so review the keys and the time to live

## 10. Memory leak

**Symptom**: a long-running process runs out of memory, and the heap keeps growing

**Likely causes**: event listeners that are never removed, closures that hold large objects, or a global cache with no limit

**How to check**: compare heap snapshots taken before and after, and measure the heap after garbage collection

## 11. Path and URL escaping

**Symptom**: file not found for a path with spaces or special characters, or a 404 for a URL whose path was encoded twice

**Likely causes**: `%20` encoded twice, path separators that differ between operating systems, or query strings built by joining strings instead of with `URLSearchParams`

**How to check**: log the actual path or URL, and look at it in hex to find invisible characters

## 12. Changing a collection while iterating over it

**Symptom**: elements are skipped, or a `ConcurrentModificationException` is thrown

**Likely causes**: removing items from a collection inside a loop over it, or changing it during async iteration

**How to check**: split the work into two phases: build a new collection with a filter, then replace or change the original

## 13. Leaked resources

**Symptom**: the process runs out of file handles, the database connection pool is exhausted, or sockets pile up in `TIME_WAIT`

**Likely causes**: a missing `close()`, `finally`, `using`, or `with`, or cleanup that is skipped on the error path

**How to check**: count open handles with `lsof -p <pid>`, and see which kind keeps growing

## 14. Integer overflow and signedness

**Symptom**: a large value turns negative, or a comparison goes the wrong way

**Likely causes**: unchecked arithmetic in Solidity before 0.8 or inside `unchecked` blocks, or 32-bit and 64-bit integers mixed in C or Rust

**How to check**: unit tests at the limits, such as the largest and smallest values, and logging the values before and after the arithmetic

## 15. Environment variables

**Symptom**: it works on your machine and fails elsewhere, and the behavior changes with whether a variable is set

**Likely causes**: `NODE_ENV` not set, a required variable missing, or a default value that differs from the one used in production

**How to check**: check whether each variable is set without printing its value, with `[ -n "${NAME+x}" ] && echo set || echo unset`, and set the variables explicitly in the test

## Using this list

At the start of a debugging session, match the symptom against this list and turn the matching patterns into the first hypotheses.
When you meet a pattern that is not listed here, mention it in the report.
