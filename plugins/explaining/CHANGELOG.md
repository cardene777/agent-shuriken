# Changelog

Releases of the explaining plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- One skill, `explaining`, that builds an explanation of how a protocol, a system, a process, or a piece of research works around one running example
- The explanation opens with a numbered map of the stages, digs into one stage per section, tells similar things apart in a table, rules out likely misreadings where they arise, lays out every combination of conditions with its result, and closes with a table of roles and one sentence to take away
- Figures are chosen by what they do: a figure that steps, a figure that takes input, or a figure of the state before and after, each mapped to a dragon kind
- `musubi.json` provides the structure as the content `structure` at version 1.0.0, so other skills that write explanations can follow it
- An example explanation of how one transfer is confirmed by the Canton Confirmation Protocol
