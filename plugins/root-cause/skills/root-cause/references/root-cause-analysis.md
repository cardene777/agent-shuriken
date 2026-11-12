# Root cause analysis

Three methods for getting from a symptom to its cause, and when to use each.

## Five whys

Start from the observed symptom and ask "why" until you reach a cause that, once fixed, stops the symptom from coming back.
Five is a rule of thumb from the Toyota Production System, not a target.

### Example

Symptom: users cannot sign in.

1. Why does pressing the sign-in button do nothing? The page never sends the sign-in request
2. Why is the request not sent? A new form check requires a password, but the password field is hidden
3. Why is the password field hidden? An A/B test from the last sprint hid it, and nobody rolled it back
4. Why was the rollback missed? The A/B test was hard-coded instead of behind a feature flag
5. Why was it hard-coded? The project has no feature flag system

The root cause is the missing feature flag system, while the symptom is the sign-in button.
The fix can target the button (the symptom), the hidden field (an intermediate cause), or the missing flag system (the root cause).
Choose by the size of the project and the impact of the bug.

### Pitfalls

- Do not stop at a person. "The engineer made a mistake" is not a root cause. Ask why the process or the tools did not prevent the mistake
- The chain may branch. When several causes are possible, follow every branch, and use a fishbone diagram to list them
- Do not insist on five. Stop at three when you reach the root cause, and keep going past five when you have not

## Fishbone diagram

A fishbone diagram, also called an Ishikawa diagram, lists candidate causes by category.
Use it to list causes broadly before following one chain with five whys.

### Example

Symptom: API latency in production grew tenfold.
The categories are the common six: people, machines, methods, materials, measurement, and environment.

```
[People]           [Machines]          [Methods]
- new engineer     - CPU throttling    - algorithm change
- shift change     - full disk         - N+1 queries
                                       - cache disabled
                                                   \
                                                    → [Latency x10]
                                                   /
[Materials]        [Measurement]       [Environment]
- large payloads   - metric bug        - new deploy
- corrupt data     - verbose logging   - network change
                                       - traffic spike
```

List every candidate, then rule them out with evidence.
The candidates left over are the hypotheses worth testing.

## Fault tree

A fault tree starts from the failure and breaks it down from the top.
It suits systems where failures are expensive, such as payments.

### Example

```
[Payment fails] (OR)
  ├── [Card declined] (AND)
  │     ├── Insufficient balance
  │     └── Card verification passed
  ├── [Network failure] (AND)
  │     ├── Timeout
  │     └── Retries exhausted
  └── [Fraud block] (AND)
        ├── A rule matched
        └── The score passed the threshold
```

AND and OR nodes chain the conditions, so probabilities can be attached: how often a branch happens times its impact gives the expected loss.

## Which to use

| Method | Use it when |
|---|---|
| Five whys | The chain of causes is a single line and the symptom is clear |
| Fishbone diagram | You need to list candidate causes broadly and group them |
| Fault tree | Failures are expensive and you want to put numbers on them |

In practice, start with five whys, and switch to a fishbone diagram when you get stuck.

## When the analysis is done

The root cause is found when all of these hold.

- Applying the fix makes the symptom disappear
- Undoing the fix brings the symptom back, which shows cause and effect
- The history shows whether the same pattern caused a bug before
- The tests show that the fix did not break behavior elsewhere

If any of these fails, the analysis is not done, and the hypothesis needs more testing.
