# Rules for writing Japanese with this plugin

This file holds the rules of the Japanese writing skill `japanese-writing`.
The upstream text is `UPSTREAM-SKILL.md`, a copy of the upstream (`coji/natural-japanese`, MIT) `SKILL.md` made without any edits.
Read this file before the upstream text, and when the two disagree, follow this file.
"Written locally" means written in this plugin, to tell it apart from what was copied from upstream.

The process of the upstream text (decide before writing, write, revise, detect with lint, check, converge, clean up) is used as it is.
What this file adds is the order of priority, the format of Markdown in a repo, the local norms and references, how to run the tools, the added reviews, how to reply with revisions, and how to act when called from other skills.

## 1. Order of priority

When the conventions of the repo in use or the upstream text disagree, the higher item in the following order wins.

| Priority | What | What it decides |
|---|---|---|
| 1 | The `CLAUDE.md`, `AGENTS.md`, `GLOSSARY.md`, and term list of the repo in use, and the user's instructions | The words to use and the words to drop in that repo, and the format |
| 2 | The format in §2 of this file | In Markdown in a repo: a line break after each Japanese full stop, the length of a paragraph, two-item lists joined with a colon, sentence endings with abstract expressions, and spaces between Japanese and alphanumeric characters |
| 3 | §3 of this file and the local references in §4 | How to fix sentences where a thing stands as the subject and how to fix metaphors, the three forms of AI smell, the patterns for explanations, how to write questions and choices, introductions to explanations, the eight sentence forms and the rule to write in the affirmative, and how to connect sentences |
| 4 | The upstream text (`UPSTREAM-SKILL.md`) and the upstream `references/` | Whatever the three above say nothing about |

**The term list of the repo in use decides the words to drop**.
The phrases that `scripts/lint.py` points to are **grounds for suspicion**, not the authority for the verdict.
When they disagree with the term list, the term list wins; when there is no term list, decide from context and leave that judgment in the record of how each finding was handled (§4 of the upstream text).

## 2. Format

For Markdown placed in a repo and text written on the repo's service, such as a README, docs, issue and pull request bodies, and comments, use the following five before 「2. 書くときの原則」 ("2. Principles for writing") of the upstream text.
Do not apply them to articles such as posts on the note service, blogs, and essays; follow the guides for each document type in the upstream `references/doctypes/` and the upstream text.
When the repo in use or the user has set a different format, follow that (§1).

- Break the line after each 「。」 (Japanese full stop), and keep blank lines to at most one
- Keep a paragraph to four sentences or fewer
- Do not write two-item lists that join a label and a value with a half-width colon (`ラベル: 値`, that is "label: value"), a full-width colon (`ラベル：値`), or a three-dot leader (`ラベル ... 値`). Use a table, natural sentences, or a heading and body text instead
- Do not end a sentence with an abstract expression (「適切に」 "appropriately", 「必要に応じて」 "as needed", 「最適化する」 "optimize")
- Do not put a half-width space between Japanese and alphanumeric characters. Keep the spaces between English words, and do not count the positions right before and after inline code

Write sentences following the eight forms in [`references/sentence-forms.md`](sentence-forms.md) and the rule to write sentences that ask for an action in the affirmative.
In text that conveys something to people, follow [`references/connecting.md`](connecting.md) to keep each sentence short and link sentences with conjunctions, and to put the conclusion first.

## 3. Local norms

Here are six norms that the upstream text does not have.

- Do not replace a term established in a technical field with another Japanese word for the sake of plainness.
  Turning `wallet` into 「財布」 ("purse") or `integration test` into 「つなぎの検査」 ("joining check") is this case
  (「台帳」 ("ledger") for `ledger` is an established translation, so do not drop it).
- Keep proper nouns, product names, API names, code identifiers, and terms from standard specifications in their original form, and wrap them in backticks.
  If needed, add a short explanation once at first use, and use the same name after that.
- Do not change a word that is not in the term list into a new translation based only on association.
  When a new translation or a coined word is needed, do not invent one silently; present candidates and reasons.
- Do not write sentences where a thing stands as the subject and takes a metaphorical verb.
  `shared/ は 2 つの置き場の隣に立ち、技の実体を預かる` ("shared/ stands beside the two places and keeps the bodies of the skills") is this case.
  The reader has to fill in the actor and the operation on their own.
  [`references/subject-and-verb.md`](subject-and-verb.md) holds how to fix it.
- Do not add actors or specifications that are not in the original.
  If the surrounding sentences give nothing to restore the actor from, do not make one up; ask the writer
  (the section 「意味を足さない」 ("do not add meaning") in [`references/ai-smell.md`](ai-smell.md)).
- Do not create variation in sentence length with short assertions that carry no information
  (the section 「文長のばらつきを決め台詞で作らない」 ("do not create sentence-length variation with punchlines") in [`references/ai-smell.md`](ai-smell.md)).

For parentheses, use the rule in `references/sentence-forms.md` that allows only the translation of a word at its first use, before the paraphrase in parentheses that principle 4 of 「2. 書くときの原則」 in the upstream text recommends.
Do not put supplements about reasons or conditions in parentheses; write them as a separate sentence or a child bullet.

## 4. References written locally

The following table lists the references and tools written locally.
None of them exist upstream.
Files copied from upstream have their fingerprints in `upstream-manifest.txt` and are not listed here.

| file | When to read |
|---|---|
| `references/terminology.md` | When choosing words. Holds how to read the term list of the repo in use |
| `references/subject-and-verb.md` | When fixing sentences where a thing stands as the subject, and metaphorical verbs and adverbs |
| `references/ai-smell.md` | When applying the three forms of AI smell (opening with contrast, negation, or hedging; using a metaphor instead of naming the operation; using form to look like more than the content) |
| `references/explaining.md` | When building the skeleton of a document meant to help the reader understand a mechanism or a procedure (explanatory material, a procedure manual, a pull request description) |
| `references/asking.md` | When writing questions that ask people to choose (questions on a confirmation sheet, questions with choices posted in chat) |
| `references/natural-explanation.md` | When writing or rewriting the introduction of an explanation, an article, or a post for readers |
| `references/sentence-forms.md` | When deciding the form of a sentence (§2) |
| `references/connecting.md` | When writing or fixing text that conveys something to people (chat posts, handovers, reports, requests). Made by editing two documents from the Agency for Cultural Affairs (§2) |
| `musubi.json` | Do not read it. It is a declaration that lets other skills such as `convey` conform, through musubi, to `references/connecting.md` as the content `connecting`; the `musubi` command reads it |
| `references/metaphor-words.tsv` | The list of metaphor words that `scripts/suspects.py` reads. People read it only when adding words |
| `scripts/suspects.py` | When pointing out, line by line, the forms that the upstream `lint.py` does not count (§5) |

The following table lists the English versions of the references.
The skill does not read them; people who read English use them.
The plugin's test checks that each has the same headings and tables as the Japanese reference beside it.

| file | When to read |
|---|---|
| `references/rules.en.md` | Do not read it. The English version of `references/rules.md` |
| `references/terminology.en.md` | Do not read it. The English version of `references/terminology.md` |
| `references/subject-and-verb.en.md` | Do not read it. The English version of `references/subject-and-verb.md` |
| `references/ai-smell.en.md` | Do not read it. The English version of `references/ai-smell.md` |
| `references/explaining.en.md` | Do not read it. The English version of `references/explaining.md` |
| `references/asking.en.md` | Do not read it. The English version of `references/asking.md` |
| `references/natural-explanation.en.md` | Do not read it. The English version of `references/natural-explanation.md` |
| `references/sentence-forms.en.md` | Do not read it. The English version of `references/sentence-forms.md` |
| `references/connecting.en.md` | Do not read it. The English version of `references/connecting.md` |
| `references/diagnose.en.md` | Do not read it. The English version of `references/diagnose.md` |
| `references/manual-checklist.en.md` | Do not read it. The English version of `references/manual-checklist.md` |
| `references/doctypes/guide.en.md` | Do not read it. The English version of `references/doctypes/guide.md` |
| `references/doctypes/memo.en.md` | Do not read it. The English version of `references/doctypes/memo.md` |
| `references/doctypes/minutes.en.md` | Do not read it. The English version of `references/doctypes/minutes.md` |
| `references/doctypes/report.en.md` | Do not read it. The English version of `references/doctypes/report.md` |
| `references/doctypes/slide.en.md` | Do not read it. The English version of `references/doctypes/slide.md` |

The patterns for explanations are six: put the point first, limit how much information you give at once, write in words the reader knows, fit the content into a pattern, give a concrete example right after an abstraction, and make figures and text match.
For slide structure, in addition to the upstream `references/doctypes/slide.md`, read the section of `references/explaining.md` that is read only when handling slides.

Build questions and choices from the following four.

- In the explanation under a question, write the situation first, then what is to be decided
- Show the situation with an example that contains numbers
- For choices, do not use numbers that exist only inside the work; use words that tell on their own what will happen
- Keep the premise short, and limit the questions to about three

For the introduction of an explanation, do not start from a category word (`機能` "feature", `ツール` "tool", `仕組み` "mechanism", `進め方` "way of working"); put who is trying to do what, where the answer splits, and what the subject does, in this order.
Glossaries, API references, and definition sentences in specifications are not covered, because showing the category first suits the reader's purpose.

## 5. How to run the tools

Run the tools in the form that `SKILL.md` writes.
Read the upstream text's `uv run scripts/<名前>.py` (`<名前>` is "name") as that form too.

The local `scripts/suspects.py` points out, line by line, the forms that the upstream `lint.py` does not count.
It points out nine kinds: metaphorical verbs, metaphorical adverbs, sentences that stop at a サ変 noun (a noun that becomes a verb with する), requests in the passive voice, short assertions, colons at the end of a sentence, full stops after a URL, purpose fragments, and long supplements in parentheses.
The last three kinds are the part of the forms in `references/sentence-forms.md` that a machine can count, and people trace the remaining forms.
It gives no pass or fail and no score; its exit code is 0 whatever the count, and it returns 1 only for an input error.
It does not look inside code blocks or backticks.

`semantic.py`, which the upstream text uses as an option, is not included in this plugin.
It fetches a model of about 1GB and runs code from where the model is hosted, so skip the steps in the upstream text that run it.

**Do not move the thresholds locally**.
The set that upstream used to calibrate the thresholds (`corpus/` and `calibrate.py`) is not included in this plugin, so when they feel off, deal with it by judging whether to leave each finding or fix it.

In an environment where `uv` cannot be used, trace the same points by eye with `references/manual-checklist.md`.

**Do not pass the HTML of material to `lint.py` as it is**.
It counts tags as sentences, so extract only the body text first and pass that.

As in 「7. 後片付け」 ("7. Clean up") of the upstream text, put intermediate files in a temporary place outside the repo in use, and delete them when the work is done.

## 6. Added reviews

Add the following three to 「5. 構造と読みやすさを点検する」 ("5. Check structure and readability") of the upstream text.

### Subject and verb review

`lint.py` does not look at this form at all.
`suspects.py` points out metaphorical verbs and adverbs, so start reading from the lines it points to (the `擬人` (personification) words point only at sentences whose subject is an identifier, so read the rest even when there are 0 hits).

Judge by eye while looking at [`references/subject-and-verb.md`](subject-and-verb.md).
Look at two conditions, and always fix a sentence where both apply.
If only one applies, leave it by default, and fix it only when the metaphorical verb hides an operation.

1. Does a non-living thing stand as the subject?
2. Is an operation said with a metaphorical verb?

**Fix from the subject**.
Replacing only the verb twists the sentence.

**Also read around the sentence pointed out**.
Fixing just one sentence splits the way of writing within the paragraph.

### Form review

Apply the three forms in [`references/ai-smell.md`](ai-smell.md) using its map of which upstream section holds each one.
For the sentences that stop at a サ変 noun, the requests in the passive voice, and the short assertions that `suspects.py` points out, decide whether to fix or leave them with the relevant sections of the same file and of `references/subject-and-verb.md`.

### Format review

If the target is Markdown in a repo or the text of an issue or pull request, check the five items in §2 by eye.
Do not fix the headings, table columns, and fixed single lines that other skills read (§8).

## 7. How to reply when asked for revisions

```text
〔修正〕
The revised text

〔理由〕
What was unnatural, and which part of terminology / grammar / logic was fixed
```

Under 〔理由〕 ("reason"), write which of the three forms in `references/ai-smell.md` applies and the words in question.
Do not reply with only 「AIっぽい」 ("sounds like AI").
Do not fix a sentence whose meaning you cannot follow by guessing; ask the writer what it means.

When returning several places, order them as errors of meaning, inconsistent terms, translationese, then notation.
Mark suggestions of taste clearly as 「任意」 ("optional"), and do not mix them with required fixes.

## 8. When called from other skills

Other skills may read this skill before writing issue or pull request bodies, comments, or reports.
The called side **looks only at the words of the text and does not touch the shape of the record (headings, table columns, fixed single lines)**.
A tool of another skill may read the shape of the record to decide whether to move on, and changing the shape makes that tool fail.

The default when called is quick mode.
The targets are the words of the body text and the headings; text inside mermaid diagrams is not looked at.

## 9. Pitfalls and checks before output

- Do not confuse rewording into general words with making the Japanese natural
- Do not turn a katakana word into native Japanese words just because you found a katakana word
- Do not change specifications, responsibilities, error conditions, or the claims of tests in the name of proofreading
- Do not remove standard terms that experts use with 「AIっぽくない」 ("does not sound like AI") as the only reason
- Do not use the count from `lint.py` as the bar for passing. It is not a tool that stops on a count
- Do not fix a metaphor where a thing stands as the subject by only replacing the verb. Fix from the subject
- Do not ban every metaphorical verb. If the subject is a person or a process and the operation can be read, a metaphor is fine, and keep expressions established in the field
- Do not count replacing a pointed-out word with another word of the same meaning as a fix. The structure of the sentence remains
- Do not rewrite files copied from upstream (files whose fingerprints `upstream-manifest.txt` holds). Upstream could then no longer be imported again, and the plugin's checks also fail

Before output, check the following eight.

1. Is the polite style (敬体) or the plain style (常体) used consistently across the whole document?
2. Is any one concept called by different words?
3. Are any technical terms replaced with unnatural literal translations?
4. Is any subject, predicate, condition, or exception missing?
5. Are required fixes and optional suggestions kept separate?
6. Is any sentence left where a thing stands as the subject and moves through a metaphor?
7. Are any actors or specifications added that are not in the original?
8. Is any intermediate file left behind?

## 10. Out of scope

- Markdown formatting itself (one sentence per line, block quotes, footnote notation)
- The names of boxes, lines, and enclosures in figures
- Checking the layout of material
- The shape of records that other skills read (headings, table columns, fixed single lines)
- Tuning the thresholds of `lint.py`
- Adding features to upstream and fixing upstream bugs (follow them by importing upstream again. The plugin's `docs/how-it-works.md` holds the steps)
