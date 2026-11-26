# Rules for writing English with this plugin

This file holds the rules of the English writing skill `english-writing`.
The upstream text is `UPSTREAM-SKILL.md`, a copy of the `SKILL.md` of `blader/humanizer` (MIT) made without any edits.
Read this file before the upstream text, and when the two disagree, follow this file.

The upstream text lists 26 patterns of AI-sounding prose and how to rewrite each one.
This file adds what the upstream text lacks: phrasing translated from Japanese, a sentence limit, terms, plain English, and how to return each fix.
The quotes come from three style guides, credited in the plugin's `THIRD_PARTY_NOTICES.md`.

## 1. Order of precedence

When the rules disagree, the higher row wins.

| Order | What | What it decides |
|---|---|---|
| 1 | The `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, glossary, and style guide of the project the text is for, and the user's instructions | The words to use and to avoid in that project, its spelling, and its format |
| 2 | This file | Phrasing translated from Japanese, sentence length, voice, terms, plain English, and how to return a fix |
| 3 | The upstream text (`UPSTREAM-SKILL.md`) | The patterns of AI-sounding prose, voice, and whatever the two rows above leave open |

A draft for an outside project follows that project's own guide first.
When the project spells a word in British English, keep British English.

## 2. Phrasing translated from Japanese

Japanese and English build sentences in different orders.
A sentence translated word for word keeps the Japanese order, and an English reader stops on it.
Write each sentence in the English order: who does what, then where, when, and why.

- Give every sentence its subject. When the actor is the reader, write "you"; when it is the team, write "we"; when it is a program, name it.
- Put the action in a verb. Write "confirm the settings" and "we fixed the error", with the verb carrying the work.
- Start with the subject, not with the topic and a comma. Write "We fixed the login error yesterday."
- Write "can", "need to", "must", "may", and "to" for ability, need, duty, possibility, and purpose.
- State a claim directly, or name who holds it. Write "The new design is faster" or "The review found the new design faster."
- Unstack a row of three or more nouns. Write "the server manages the sign-in details", with a verb between the nouns.
- Name the action instead of a general verb. Write "fix the issue", "answer the question", or "support Linux".
- Put a command or a list after a full sentence. Write "Run this command." and then the command.

`references/translationese.tsv` lists the phrasings `scripts/suspects.py` points at, each with an example and what to write instead.
A phrasing the list lacks still counts when it keeps the Japanese order; name it `[from Japanese]` all the same.

## 3. Sentences

Keep each sentence to 25 words or fewer.

> Try to split up sentences that are over 25 words long.

From "Use clear language" in the GOV.UK writing guidelines.
Contains public sector information licensed under the Open Government Licence v3.0.

Code, a command, a path, and a URL each count as one word.
Split a long sentence where it joins two ideas: at "and", "but", "which", or a semicolon.
Turn three or more parallel items into a list when the text is Markdown.

Use the active voice.

> In general, use active voice

From "Active voice" in the Google developer documentation style guide, licensed under CC BY 4.0.

> Active voice makes it clear who should do what.

From the plain language guidelines of plainlanguage.gov, now at digital.gov, in the public domain.

Keep the passive voice when the actor is unknown or does not matter, as in "The database was purged in January."
Put the verb back when a noun hides it.

> A hidden verb (or nominalization) is a verb converted into a noun. It often needs an extra verb to make sense.

From the plain language guidelines of plainlanguage.gov, now at digital.gov, in the public domain.

> Words ending in ‘–ion’ and ‘–ment’ tend to make sentences longer and more complicated than they need to be.

From "Use clear language" in the GOV.UK writing guidelines.
Contains public sector information licensed under the Open Government Licence v3.0.

## 4. Terms

Call one thing by one name throughout the text.

> If you use a particular term for a concept in one place, then use that exact same term elsewhere, including the same capitalization.

From "Write for a global audience" in the Google developer documentation style guide, licensed under CC BY 4.0.

- Keep the established term of the field. Write "merge", "pull request", "branch", and "wallet" as developers write them.
- Spell a product or a project as its owner spells it: GitHub, JavaScript, macOS.
- Put code, commands, file names, and other identifiers in backticks, and keep their spelling.
- Explain a term the reader may not know once, where it first appears, and use the same term after that.

## 5. Plain English

- Use the short common word: "use", "help", "start", "about", "so", "show".
- Address the reader as "you", and write instructions as commands: "Run the tests."
- Put the conclusion or the decision first, then the reason.
- Write what to do, rather than what not to do, when both say the same thing.
- Keep one idea in a sentence and one topic in a paragraph.

## 6. Vague words and set phrases

End a sentence on the concrete action, value, or condition.
These words leave the reader to guess, so replace each one with what it stands for.

| Vague word | Write instead |
|---|---|
| appropriately, properly, as needed, as appropriate | the condition or the value: "when the file is over 1 MB" |
| improve, optimize, enhance | what changes and by how much: "cut the start time from 4 to 2 seconds" |
| handle, deal with, support | the action: "retry the request", "read the file" |
| various, several, some, certain | the number or the names |
| etc., and so on | the full list, or "such as" and the main items |
| related, relevant | how the two things connect |

proselint points at set phrases, hedging, weasel words such as "very", and cliches.
Without `uv`, read the text for these by eye.

## 7. Running the checks

Run the checks in the form `SKILL.md` writes.
`scripts/suspects.py` and proselint point at suspects; they do not decide.

- Read the line each finding names, and decide from the context whether to fix it.
- Keep a passive sentence when the actor does not matter, and note why.
- Treat a finding inside a quotation, a title, or a name as text to keep.
- Do not count the findings as a score, and do not chase zero.

## 8. How to return a fix

Return the fixed text first, then one line for each fix.
Name the kind of each fix with one of these words.

| Kind | What it found | Where the rule is |
|---|---|---|
| `from Japanese` | Phrasing translated word for word from Japanese | Section 2 |
| `AI-sounding` | One of the patterns of AI-sounding prose | The upstream text, sections 1 to 26 |
| `vague word` | A word that leaves the reader to guess | Section 6 |
| `inconsistent term` | One thing called by two names, or a changed spelling | Section 4 |
| `too long` | A sentence of more than 25 words | Section 3 |
| `passive voice` | A passive sentence where the actor matters | Section 3 |

```text
Fixed text
<the whole fixed text>

Fixes
1. [from Japanese] "It is necessary to restart" -> "Restart": <the reason, in the language the user writes in>
2. [too long] line 4 -> two sentences: <the reason>
```

Write the reasons in the language the user writes in.
Keep the kind words in English, so that the list reads the same in any language.
List errors of meaning first, then inconsistent terms, then the rest.
Mark a change of taste as optional, apart from the required fixes.
When you cannot tell what a sentence means, ask the writer instead of guessing.

## 9. When called from other skills

Other skills may run this skill before they write an issue, a pull request, a comment, or a reply.
Change only the words of the text.
Keep headings, table columns, fixed single lines, code, commands, paths, and link targets as they are.
A tool of another skill may read that shape, and a changed shape makes the tool fail.
Return only the fixed text, as the upstream text's embedded mode says.

## 10. Files written for this plugin

Files copied from upstream have their fingerprints in `upstream-manifest.txt` and are not listed here.

| File | When to read |
|---|---|
| `references/translationese.tsv` | When a line is pointed at as `[from Japanese]`, or when adding a phrasing. It holds the pattern, an example, and what to write instead |
| `scripts/suspects.py` | Do not read it. Run it as `SKILL.md` says |
| `musubi.json` | Do not read it. It declares this file as the content `rules` that other skills follow through musubi; the `musubi` command reads it |

## 11. Checks before output

1. Does the fixed text hold every fact, number, name, date, and claim of the original, and nothing more?
2. Does every sentence have its subject and its verb?
3. Is any sentence over 25 words?
4. Is each thing called by one name, with one spelling?
5. Are code, commands, paths, and link targets unchanged?
6. Does each fix name its kind and give its reason in the user's language?
7. Is any intermediate file left behind?

## 12. Out of scope

- Translating Japanese text into English. Write the English first, then fix it with this skill.
- Scoring how AI-like a text reads with a model or an outside service.
- Rewriting files copied from upstream. Update them by copying upstream again, as the plugin's `docs/how-it-works.md` says.
