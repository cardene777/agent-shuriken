# Changelog

Releases of the japanese-speaking plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- A sixth format, the round-table, for three or more speakers: one host opens, names each speaker before handing over a question, lets every speaker talk in each beat, and closes. The rule on differing views and the fresh reader's checklist say speakers instead of two people, and the reader looks for a speaker who never talks during a beat
- `speaking.py check` prints `note speaker-utterances <speaker> <count>` for each named speaker, in the order they first speak, without changing the exit code
- The first step asks for the number of speakers along with their names and roles

## [0.2.0] - 2026-11-23

- The references read in English: each Markdown file under `references/` has an English version beside it named `<name>.en.md`, with the same headings, and the skill keeps reading the Japanese files
- Each word in `references/common-katakana.txt` carries its English meaning after a tab, and `speaking.py check --source` refuses a word line without one with exit 2

## [0.1.0] - 2026-11-18

First public release.

- Writes Japanese meant to be heard, in five formats: a news item one host reads and both then discuss, small talk, an interview, a narration, and a talk script
- `speaking.py check` reports lines that sound read from paper: a sentence that stops on a particle, a polite question that drops ka, one speaker quizzing another on a term, casual contractions, written-style endings, a source stated as fact, and a vaguely named source. With `--source`, it also reports numbers and names absent from the material
- `speaking.py check` prints script-level notes that never fail the check: the median and spread of utterance length, the share of short replies, backchannels, sentences ending in the particles ne and yo, the same ending three times in a row, and long sentences
- After the check, a reader that has not seen the conversation listens for lines that still sound read, and the agent fixes them

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/japanese-speaking--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/japanese-speaking--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/japanese-speaking--v0.1.0
