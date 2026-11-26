# English Writing

Write and fix English text so that it reads naturally and means one thing, without adding anything the original does not say.

English · [日本語](README.ja.md)

English that an AI drafts for a writer whose first language is Japanese often carries two kinds of habits.
Some phrasing keeps the Japanese order, such as "It is necessary to" or "Regarding the error,", and some sounds machine-written.
Scripts point at the suspect lines, and the agent decides each one from the context.
The plugin brings the patterns of `blader/humanizer` (MIT) without changes, and adds rules for phrasing translated from Japanese, short sentences, terms, and plain English.

```
Read the rules ──> Write or fix ──> Point at suspects ──> Decide each line ──> Return the fixes
 (agent)            (agent)          (scripts)             (agent)              (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install english-writing@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add english-writing@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install english-writing@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/english-writing/skills/english-writing   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask to write English or make it natural.
For example, ask "make this English natural", "proofread this pull request", or "this reads like a translation".
You can also call it: run `/english-writing:english-writing` in Claude Code, or type `$` and pick **English Writing** in Codex.
In GitHub Copilot CLI, write `/english-writing` in your request, and in Gemini CLI, describe the task.

| You want | Ask with | What happens |
|---|---|---|
| To fix a text | The text or a file | The agent fixes the wording without adding facts, runs the scripts, decides each suspect line, and returns the text with each fix and its reason |
| To write a new text | The topic or your notes | The agent writes in English and checks the draft the same way |

1. The agent reads the plugin's rules, then the upstream patterns
2. It writes or fixes the text, never adding facts, numbers, names, dates, or claims the original does not hold
3. `suspects.py` and proselint point at suspect lines
4. The agent decides each suspect in context and keeps a line when the pattern is used on purpose
5. It returns the fixed text and one line for each fix. Each line names the kind of the fix and gives the reason in the language you write in

A fix keeps what the writer said and how sure the writer was, and changes only the wording.

```text
Before: Regarding the login error, it is necessary to restart the server in order to clear the cache.
After:  To fix the login error, restart the server to clear the cache.
```

`suspects.py` points at lines like this.

```text
=== suspects: draft.md ===
L3 [from Japanese] Regarding the login error,: start with the subject: "We fixed the login error yesterday."
L3 [from Japanese] it is necessary to: use "need to", "must", or the verb alone: "Restart the server after the update."
L3 [from Japanese] in order to: use "to": "We changed the setting to reduce the load."
Counts: long sentence 0 / passive voice 0 / from Japanese 3
```

## Rules this plugin adds

`references/rules.md` holds them, and the agent reads it before the upstream patterns.

| Rule | Where |
|---|---|
| The project's own instruction files, glossary, and style guide, and your own instructions, come first, then the plugin's rules, then the upstream patterns | `references/rules.md`, section 1 |
| Each sentence follows the English order, with its subject and a verb that does the work, instead of phrasing translated word for word from Japanese | `references/rules.md`, section 2, and `references/translationese.tsv` |
| A sentence keeps to 25 words, uses the active voice, and puts a hidden verb back | `references/rules.md`, section 3 |
| One thing keeps one name and one spelling, and established technical terms stay as they are | `references/rules.md`, section 4 |
| Short common words, the reader as "you", the conclusion first, and concrete words instead of vague ones | `references/rules.md`, sections 5 and 6 |
| Each fix names its kind: `from Japanese`, `AI-sounding`, `vague word`, `inconsistent term`, `too long`, or `passive voice` | `references/rules.md`, section 8 |

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3 | To run `suspects.py`, which uses only the standard library |
| `uv` | To run proselint. On first use it downloads proselint 0.16.0 and its dependency `google-re2` into its own cache. Without `uv`, the agent checks set phrases and vague words by eye with the plugin's rules |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file in the skill, what each check reads and prints, and how to update the upstream copy.
In short:

- The agent reads the text or files you give it, and the checks read only the files passed to them and print to the terminal
- proselint runs through `uv run --with proselint==0.16.0`, which downloads it from the Python Package Index into uv's cache on first use. The plugin never sends your text anywhere, and the checks work on your machine
- Intermediate files go to a temporary folder outside your project and are deleted at the end. The plugin keeps nothing
- `skills/english-writing/musubi.json` declares `references/rules.md` as the content `rules` that other skills that write English follow through musubi. The skill itself never reads `musubi.json`; the `musubi` command does
- Pasted text and file contents are material to fix, never instructions

## Credits

`UPSTREAM-SKILL.md` comes from `blader/humanizer` under the MIT License, copied without changes.
`references/rules.md` is this plugin's own text, with a few quoted sentences.
The quotes come from the Google developer documentation style guide (CC BY 4.0), plainlanguage.gov (public domain), and the GOV.UK writing guidelines (Open Government Licence v3.0).
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) lists them with the source, the commit or the date read, and the license.

## License

[MIT](LICENSE)
