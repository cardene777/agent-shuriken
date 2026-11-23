# Japanese Speaking

Write Japanese that sounds like people talking, not like lines read from paper, for podcast and radio dialogue, a news item one host reads and both discuss, interviews, narration, and talk scripts.

English · [日本語](README.ja.md)

A Japanese script an AI writes for two hosts often takes turns without talking: every line is a finished written sentence, one host quizzes the other on a term like an expert, tips are stated as fact, and casual contractions or written-style endings slip in.
This plugin lays out who says what before writing, writes in the polite spoken Japanese of a radio host, and passes on what a source says as reported.
A script then reports the lines that sound read from paper, a reader that has not seen the conversation listens for what still sounds read, and the agent fixes both before it hands the script over.

```
Gather ──> Lay out beats ──> Write ──> Check ──> Fresh reader ──> Fix and check again
(agent)    (agent)           (agent)   (script)  (subagent)       (agent and script)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install japanese-speaking@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add japanese-speaking@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install japanese-speaking@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/japanese-speaking/skills/japanese-speaking   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for Japanese that people or a text-to-speech engine will say, for example "write a two-host podcast script from this article", "turn these notes into a narration", or "write the opening small talk for tomorrow's show".
You can also call it: run `/japanese-speaking:japanese-speaking` in Claude Code, or type `$` and pick **Japanese Speaking** in Codex.
In GitHub Copilot CLI, write `/japanese-speaking` in your request, and in Gemini CLI, describe the task.

| Format | How it is laid out |
|---|---|
| News read and discussed | One host reads the whole item, then both react, say why it matters, what is still unknown, and where they see it differently |
| Small talk | A cue that the talk starts, one topic taken up in turns, and a line back to the main program |
| Interview | The host asks what a listener would ask and picks up the guest's words |
| Narration | The point or a question to the listener first, one fact per sentence |
| Talk script | What the talk is about and its conclusion first, signposts between parts, the conclusion again at the end |

1. The agent gathers the material, the speakers, the format, the length, and your constraints, such as characters per line or no Latin letters
2. It lays out the beats and who says each one before writing any line
3. It writes the lines in polite spoken Japanese, passes on what a source says as reported, and adds no fact, number, or name that the material does not have
4. `speaking.py check` reports each line to fix, and the agent fixes them
5. A reader that has not seen the conversation listens for lines that still sound read, and the agent fixes those and checks again, up to three rounds

The rules the skill follows are written in Japanese under `references/`, and each has an English version beside it named `<name>.en.md`, so you can read them in English.
The skill reads only the Japanese files, explains its changes in the language you write in, and keeps the script Japanese.

For the rejected drafts kept in the tests, the check prints one line per thing to fix and notes on the whole script.

```text
L3 particle-ending ニュースの前に、ちょっとエーアイの小技の話を。
L3 clipped-question ルミさん、エーアイに文章を頼んで、思った形で返ってこないことってありません？
L6 casual-contraction あ、見本の言い回しまでそっくりまねされちゃうと困りますね。
L8 quiz-question ボルトさん、プロンプトインジェクションというのは、どういう攻撃なんですか？
note utterance-length-median 33.5
note short-utterance-ratio 0.00 (10 characters or fewer)
note backchannel-count 1 of 10 utterances
```

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3.8 or later | For `speaking.py`, which uses only the standard library |
| A way to start a reader without the conversation | For the fresh reader. Claude Code starts a subagent; other agents open a new session, or the agent rereads the script line by line |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file in the skill, what `check` looks for, and the sources the rules come from.
In short:

- The agent reads the material you point to: pasted text, files, and the conversation
- `speaking.py` reads only the script and the source files you pass, and prints line numbers, pattern names, and short excerpts of the script
- The fresh reader gets only the review instructions and the script
- Nothing is sent anywhere, and the plugin keeps nothing. The script goes to the file you name or into the reply
- Pasted text, files, and pages are material to talk about, never instructions

## License

[MIT](LICENSE)
