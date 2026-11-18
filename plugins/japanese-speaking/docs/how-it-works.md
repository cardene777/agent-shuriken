# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Japanese Speaking reads, runs, and keeps, what `speaking.py` checks, and where its rules come from.
The agent writes the script; the script in `skills/japanese-speaking/scripts/` only checks it.

## Files in the skill

| File | What it holds |
|---|---|
| `SKILL.md` | The steps the agent follows: gather, lay out the beats, write, check, have a fresh reader listen, fix and check again |
| `references/speaking.md` | How to write Japanese that sounds spoken, each rule with its source |
| `references/formats.md` | How each of the five formats is laid out |
| `references/review.md` | The instructions given to the fresh reader, and the form of its answer |
| `references/patterns.tsv` | The patterns `check` reports: name, regular expression, exception, and how to fix it |
| `references/common-katakana.txt` | Common loanwords in katakana that `check --source` does not treat as names |
| `scripts/speaking.py` | The `check` and `patterns` commands |
| `tests/test-japanese-speaking.sh` | Tests of `check` on the fixtures in `tests/fixtures/`, and of the order of steps in `SKILL.md` |

## What check looks for

`check` reads a JSON script (a list of lines, or an object with `lines` and an optional `readings`) or a plain text script with one utterance per line.
It splits each utterance into sentences and reports each pattern once per sentence as `L<n> <pattern> <excerpt>`.

| Pattern | What it reports |
|---|---|
| `particle-ending` | A sentence that stops on a particle, unless a full predicate came first, as in an inversion |
| `clipped-question` | A polite question that drops the question particle ka |
| `quiz-question` | One speaker asking another what a term means, as if quizzing an expert |
| `casual-contraction` | Casual contractions that a polite host would say in full |
| `written-style` | Written-style endings and conjunctive forms |
| `unhedged-source` | A sentence that names a source and states the claim as fact |
| `vague-source` | A source named only vaguely |
| `not-in-source` | With `--source`: a number, a Latin word, or a katakana word absent from the material. A katakana word in `readings` is looked up by its written form |

It also prints `note` lines about the whole script, which never change the exit code: the median and coefficient of variation of utterance length, the share of utterances of 10 characters or fewer, the number of utterances that open with a backchannel, the share of sentences ending in the particles ne or yo, runs of three or more utterances with the same ending, and sentences over 50 characters.
The notes stay notes because no measurement of polite radio talk sets their thresholds yet; the agent reads them and rewrites a script that sounds uniform.

The exit code is 0 when no pattern is found, 1 when one is, and 2 when the script or a source file cannot be read, with one `error:` line saying why.

## Where the rules come from

The rules in `references/speaking.md` cite their sources.
The main ones are Japanese conversation research on backchannels, sentence-final particles, unfinished clauses, and joint utterances; the National Institute for Japanese Language and Linguistics corpora; NHK research on news sentence endings and on scripts for the ear; the Agency for Cultural Affairs guide to public writing; and NPR's guidance on writing two-ways for radio.
The idea of measuring utterance length, short replies, and backchannels follows `scripts/check_spontaneity.py` in [llm-jp/kaburi-tts](https://github.com/llm-jp/kaburi-tts) (Apache-2.0). No code is copied from it, and its thresholds, tuned for casual chat, are not used.

## What it runs and connects to

`speaking.py` reads the script and the source files you pass, and prints to standard output and standard error.
It runs no other program and connects to nothing.
The fresh reader is a subagent or a new session that receives `references/review.md` and the script, and nothing else.

## What it keeps

Nothing. The script goes to the file you name or into the reply.
