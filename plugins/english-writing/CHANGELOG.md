# Changelog

Releases of the english-writing plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- Writes and fixes English text without adding facts, numbers, names, dates, or claims the original does not hold. It follows the patterns of AI-sounding prose in `blader/humanizer`, copied without changes and checked against their fingerprints
- Adds rules of its own on phrasing translated word for word from Japanese and on sentences of 25 words at most. Other rules cover active voice, one name for each thing, plain English, and vague words. Short quotes come from the Google developer documentation style guide, plainlanguage.gov, and the GOV.UK writing guidelines
- Names the kind of each fix (`from Japanese`, `AI-sounding`, `vague word`, `inconsistent term`, `too long`, or `passive voice`) and explains it in the language you write in
- With Python 3 alone, `suspects.py` points at long sentences, passive voice, and the phrasings from Japanese that `references/translationese.tsv` lists. Through `uv`, proselint 0.16.0 points at set phrases and weasel words
- `musubi.json` declares `references/rules.md` as the content `rules`, version 1.0.0, so that other skills that write English can follow it through musubi
- Starts when you ask to write English or make it natural, or when you call it. It runs in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`
