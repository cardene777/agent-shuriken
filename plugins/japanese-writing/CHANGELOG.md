# Changelog

Releases of the japanese-writing plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- A new reference, `references/connecting.md`, shows how to cut a long sentence in a message for people and connect the short ones with conjunctions, and how to put the conclusion first. It is edited from two documents of Japan's Agency for Cultural Affairs, credited in `THIRD_PARTY_NOTICES.md`

## [0.1.0] - 2026-11-15

First public release.

- Writes and fixes Japanese text without adding facts, numbers, names, dates, or opinions the original does not hold, following the steps of `coji/natural-japanese` v2.0.0, copied without changes and checked against their fingerprints by the plugin's test
- Runs the upstream scripts that point at translationese, phrases AI tends to use, vague endings, and the paragraphs to check one by one, and adds `suspects.py`, which points at metaphor verbs and eight other forms the upstream lint does not count
- Puts the repository's own instruction files, glossary, and your instructions first, and gives Markdown kept in a repository one sentence per line, short paragraphs, no `label: value` pairs, and no space between Japanese and Latin letters, while notes, blog posts, and essays follow the upstream guide for their kind
- Adds references on rewriting things used as subjects of metaphor verbs, three shapes of AI-like text, building an explanation, writing questions and options, opening an article, and eight sentence forms
- Scores how AI-like a text reads without changing it, when you ask for a score
- Runs the scripts through `uv`, which downloads `sudachipy` and its dictionary on first use, and checks the same points by eye when `uv` is missing. The optional `semantic.py`, which downloads a 1 GB model, is left out
- Starts when you ask to write Japanese or make it natural, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`
