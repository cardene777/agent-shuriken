---
name: flow-format
description: Answers a question about how a flow, a procedure, a chain of steps, or a workflow goes, as numbered steps that each hold one action sentence and a short unindented paragraph of details. Use it every time someone asks how something proceeds from start to end, in any language, even when an earlier answer in the conversation already used it. Not for a question about one file or one idea, such as what a function returns or what a term means.
---

# Flow format

Explain a flow as numbered steps that the reader can follow in order.
Each step says one action, and a short paragraph under it says what the step does and what it depends on.

## When to use it

Use it when someone asks how a flow, a procedure, a chain of steps, a pipeline, or a workflow goes.
Questions such as "How does a change get from an issue to the main branch?", "What happens when the release script runs?", and "Walk me through the setup" all start it.
Use it every time such a question comes, even when an earlier answer in the conversation already used it.

Do not use it for a question about one file or one idea, such as "What does this function return?" or "What is a rebase?".
A flow of two or three steps may be answered in plain sentences instead.

Answer in the language the person writes in.

## Answer form

Write the flow as numbered steps, in the order they happen.

| Part | How to write it |
|---|---|
| The action sentence | One sentence after the number that starts with a verb, such as "Open an issue that says what to change and why." |
| The blank line after the action sentence | One empty line between the action sentence and its paragraph |
| The paragraph | One to three sentences under the action, not indented and not a list, with one sentence per line |
| The blank line between steps | One empty line after each paragraph, before the next number |

The paragraph says what the step does, what it makes or changes, and the conditions or limits that apply.
When a step branches, say which case goes which way.
When the step uses a command, a file, or a tool, put its name in code formatting and say in a few words what it is the first time it appears.

Keep each step to the flow that was asked about.
Do not explain an idea the person did not ask about; answer it when they ask.

## Diagrams and tables

After the steps, a plain-text diagram of boxes and arrows may be added when the flow has branches or loops, so the reader sees the whole shape at once.
Draw it in a code block with characters only, and show only the steps above, with nothing new in it.

Do not write Mermaid in a chat answer, because many chat windows and terminals show it as raw code.
Write Mermaid only in a file the person asked for, such as a pull request description or a document.

A table may follow the steps as a summary, never in place of them.

## Good example

The question is "How does a change go from an issue to the main branch?".

```text
1. Open an issue that says what to change and why.

The issue holds the problem, the expected result, and the conditions for calling the work done.
Everyone who works on the change reads it first.

2. Create a branch for the issue from the latest main branch.

The branch keeps the change apart from other work until it is reviewed.
Name it after the issue so that anyone can find it.

3. Write a test that fails until the change is made.

The test states the expected behavior from the issue in code.
Running it before the change shows that it fails for the right reason.

4. Open a pull request once the change makes the test pass.

The pull request shows the diff, links the issue, and says how the change was checked.

5. Ask a reviewer to review the pull request.

The reviewer reads the diff and either approves it or asks for changes.
Each requested change goes to the same branch as a new commit, and the reviewer looks again.

6. Merge the pull request into the main branch after it is approved.

The change becomes part of the main branch, and the issue closes with it.
Delete the branch, since its work now lives in the main branch.
```

The review in step 5 can go back to the branch, so a plain-text diagram may follow the steps.

```text
[issue] -> [branch] -> [test] -> [pull request] -> [review] -> [merge]
                                       ^               |
                                       +-- changes ----+
```

## Forms to avoid

Each form below loses what the numbered steps give: one action per step, and details the reader can read in order.

| Form | Write instead |
|---|---|
| Bold headings with indented bullets under each | A numbered action sentence and an unindented paragraph |
| Names joined by arrows, such as `issue -> branch -> test`, with nothing said about each | One step per name, with what it does |
| Several sentences on one long line of details | One sentence per line, at most three |
| A Mermaid block in the chat answer | The steps, and a plain-text diagram after them when the flow branches or loops |
| Terms the reader may not know, used without a word on what they are | The term in code formatting with a few words on what it is |
