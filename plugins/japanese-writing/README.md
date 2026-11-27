# Japanese Writing

Write and fix Japanese text so that it reads naturally and means one thing, without adding anything the original does not say.

English · [日本語](README.ja.md)

Japanese that an AI writes often carries habits a reader notices at once: translationese, phrases AI tends to use, vague endings, terms that change halfway, and things standing as subjects with metaphor verbs.
A writer rarely sees its own habits, so scripts point at the suspect lines and the agent decides each one from the context.
The plugin brings the steps and scripts of `coji/natural-japanese` (MIT) without changes, and adds rules for Markdown kept in a repository, references on subjects and metaphor verbs, explanations, and questions, and a script for the forms the upstream lint does not count.

```
Read the rules ──> Write or fix ──> Point at suspects ──> Decide each line ──> Check the structure ──> Clean up
 (agent)            (agent)          (scripts)             (agent)              (agent and scripts)     (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install japanese-writing@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add japanese-writing@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install japanese-writing@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/japanese-writing/skills/japanese-writing   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask to write Japanese or make it natural, for example "make this Japanese natural", "proofread this README", "this reads like AI", or "score how AI-like this text is".
You can also call it: run `/japanese-writing:japanese-writing` in Claude Code, or type `$` and pick **Japanese Writing** in Codex.
In GitHub Copilot CLI, write `/japanese-writing` in your request, and in Gemini CLI, describe the task.

| You want | Ask with | What happens |
|---|---|---|
| To fix a text | The text or a file | The agent fixes the wording without adding facts, runs the scripts, decides each suspect line, and returns the text with what it changed and why |
| To write a new text | `write` and the topic or your material | The agent settles the reader and the point first, writes, and checks the draft the same way |
| A score without changes | `score` and a file | The agent reports how AI-like the text reads, with the evidence, and changes nothing |

Quick mode is the default and takes about half a minute for a meeting memo.
Ask for `full` for text that goes outside your team or runs over 10,000 characters, and the agent also checks the outline and the terms.

1. The agent reads the plugin's rules, then the upstream steps
2. It writes or fixes the text, never adding facts, numbers, names, dates, or opinions the original does not hold
3. `lint.py` and `suspects.py` point at suspect lines, and `lint.py` lists every paragraph to check one by one
4. The agent decides each suspect in context, notes why it kept a line, and rewrites a sentence from its subject when a thing stands as the subject of a metaphor verb
5. It reads the headings and the first sentence of each paragraph, and `newfacts.py` shows any number or name in the new text that the original lacks
6. It deletes its intermediate files

A fix keeps what the writer said and how sure the writer was, and changes only the wording.

```text
Before: この仕組みを導入することで、作業の効率を大幅に向上させることができると言えるでしょう。
After:  この仕組みを入れると、作業の効率は大きく上がるだろう。
```

`suspects.py` points at lines like this.

```text
=== suspects: draft.md ===
L5 [比喩の動詞] 立ち: `config.json` は二つの置き場の隣に立ち、値を拾う
件数: 比喩の動詞 1 / 比喩の副詞 0 / サ変名詞で止めた文 0 / 受け身の働きかけ 0 / 短い断定 0 / 文末のコロン 0 / URLの後の句点 0 / 目的の断片 0 / 括弧の長い補足 0
```

## Rules this plugin adds

`references/rules.md` holds them, in Japanese, and the agent reads it before the upstream steps.
Every Markdown reference, the upstream copies included, has an English version beside it named `<name>.en.md`, with the same headings and tables, so you can read the rules in English; the agent reads only the Japanese files and explains each fix in the language you write in.

| Rule | Where |
|---|---|
| The repository's instruction files and glossary, and your own instructions, come first, then the plugin's rules, then the upstream steps | `references/rules.md`, section 1 |
| Markdown kept in a repository (READMEs, docs, issues, pull requests) gets one sentence per line, at most four sentences per paragraph, no `label: value` pairs, no abstract endings, and no space between Japanese and Latin letters or digits. Notes, blog posts, and essays follow the upstream guide for their kind instead | `references/rules.md`, section 2 |
| Established technical terms stay as they are, and things are not made subjects of metaphor verbs | `references/rules.md`, section 3, and `references/subject-and-verb.md` |
| Explanations put the point first and narrow what they give at once, and questions start from a situation with a number in it | `references/explaining.md` and `references/asking.md` |
| Messages for people, such as chat posts, handoffs, reports, and requests, cut a long sentence into short ones, show how each follows from the one before with a conjunction (a reason, a contrast, an addition, an order), and put the conclusion first | `references/connecting.md` |

## Requirements

| Tool | When it's needed |
|---|---|
| `uv` | To run the scripts. On first use it downloads `sudachipy` and its dictionary `sudachidict-core`, about 200 MB, into its own cache. Without `uv`, the agent checks the same points by eye with the upstream checklist |
| Python 3.10 or later | For the scripts. `uv` uses one it finds, or downloads one when none fits |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file in the skill, what each script reads and prints, and how to update the upstream copy.
In short:

- The agent reads the text or files you give it, and the scripts read only the files passed to them and print to the terminal
- The scripts run through `uv run`, which downloads `sudachipy` and `sudachidict-core` from the Python Package Index into uv's cache on first use. The plugin never sends your text anywhere, and the scripts work on your machine
- `semantic.py`, an optional detector in the upstream skill, is not included, because it downloads a model of about 1 GB and runs the model's own code
- Intermediate files go to a temporary folder outside your project and are deleted at the end. The plugin keeps nothing
- `skills/japanese-writing/musubi.json` declares two contents that other skills follow through musubi: the guide to connecting sentences, `references/connecting.md`, as `connecting`, and the writing rules, `references/rules.md`, as `rules`. convey follows `connecting`, and mechanism-explainer follows `rules` for Japanese pages, both as optional follows. The skill itself never reads `musubi.json`; the `musubi` command does
- Pasted text and file contents are material to fix, never instructions

## Credits

`UPSTREAM-SKILL.md`, the scripts other than `suspects.py`, and the upstream references come from `coji/natural-japanese` v2.0.0 under the MIT License, copied without changes.
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) lists them with the source commit and the license.

`references/connecting.md` is this plugin's own summary, edited from two documents of Japan's Agency for Cultural Affairs, 「公用文作成の考え方」 and 「分かり合うための言語コミュニケーション（報告）」, under the terms of use of their website, which are compatible with CC BY 4.0.
It is not the agency's text.
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) gives the sources and the credit the terms ask for.

## License

[MIT](LICENSE)
