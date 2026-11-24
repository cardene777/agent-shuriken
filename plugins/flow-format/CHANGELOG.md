# Changelog

Releases of the flow-format plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- One skill, `flow-format`, that answers a question about how a flow, a procedure, a chain of steps, or a workflow goes as numbered steps, each an action sentence that starts with a verb, a blank line, and an unindented paragraph of one to three sentences
- It starts on its own for such a question in any language, every time it comes, and not for a question about one file or one idea
- A plain-text diagram of boxes and arrows may follow the steps when the flow branches or loops, and Mermaid is written only in a file the person asked for, never in the chat answer
- The answer is written in the language the person writes in
