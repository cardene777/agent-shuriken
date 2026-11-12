# Rereading the text

Read the text once more before handing the document out.
The scripts count some things and a person judges the rest, as the table shows.

| Area | The scripts count | A person reads for |
|---|---|---|
| Terms | bundled word lists, katakana long-vowel variants, words in the term table | whether one thing has one name throughout |
| Content | caption numbers, table column counts, contents list vs headings | whether the text is true and matches the figures |
| Headings | commas in Japanese headings | whether the heading alone tells what follows |
| Wordiness | wordy phrases, paragraph and sentence lengths, repeated sentences | whether the length is needed |
| Worker's notes | words about the state of the work, worker headings, links left in the default blue | whether decided and undecided things are mixed |
| Figures and text | captions, legends, the paragraph before a figure | whether a figure and the text call things by the same name |

Run from the skill folder:

```bash
python3 scripts/prose.py doc.html
python3 scripts/figure.py doc.html
```

`check.py` runs the same text checks as part of its run.

## Two rule sets

`prose.py` reads the `lang` attribute of `<html>`.
When it starts with `ja`, every check runs.
Otherwise, including when `lang` is missing, only the checks that do not depend on the language run.
The first line of the output names the rule set: `-- rules: ja` or `-- rules: en (Japanese wording rules not applied)`.

| Check | Japanese documents | Other documents |
|---|---|---|
| Bundled word lists in [`references/prose-words.txt`](./prose-words.txt) | yes | no |
| Term table given with `--words` | yes | yes |
| Katakana long-vowel variants, full-width letters and digits | yes | no |
| Words that differ only in letter case (counted only) | yes | no |
| Caption number gaps and repeats | Japanese prefixes for "figure" and "example" | `Figure`, `Fig.`, `Example` |
| Table column counts | yes | yes |
| Contents list vs section headings | yes | yes |
| Worker headings | the Japanese words in the list, and `TODO` | `TODO` |
| Commas in headings | yes | no |
| Metaphor verbs after an identifier subject | yes | no |
| Links left in the default blue | yes | yes |
| Lengths and repeated sentences (counted only) | sentences end at the ideographic full stop | sentences end at `.`, `!`, `?` |

A document that is not Japanese gets no wording rules other than its term table.
To hold such a document to a vocabulary, write the words in a term table.

Caption numbers are counted per page (the part of the section id before `-`) and per prefix.
`Fig.` counts as `Figure`, so `Figure 1` and `Fig. 2` form one sequence.
A caption without a number is counted on the `-- unnumbered captions` line and never fails.

## What is not counted as text

The checks leave out `<script>`, `<style>`, `<code>`, `<pre>`, and every element with `data-prose-skip`.
Put `data-prose-skip` on quoted text whose wording is fixed elsewhere, such as a license notice, a message template, or a quotation in another language.
The number of blocks left out appears on the `-- left out of the text` line, so check there that not too much was left out.
Do not nest an element of the same name inside an element with `data-prose-skip`: the block ends at the first closing tag of that name.

## Term tables

A term table lists words this document must not use, one entry per line.

```
utilize -> use
patron -> member
allow: member (patron)
```

Write each entry as `word -> replacement`.
A tab, `→`, `=>`, and `,` also separate the two; the first one found in the order tab, `→`, `->`, `=>`, `,` is used.
A line with only a word flags it without suggesting a replacement, and a line starting with `#` is a comment.

Words are matched as written: as a substring, with case.
`utilize` also matches `utilized` and `utilizes`, and a sentence starting with `Utilize` needs its own entry.

A line starting with `allow:` names a phrase that is not counted even though it contains a listed word.
Use it for a glossary entry that keeps the original word in parentheses, or for the name of a standard.
Only that phrase is removed: with `allow: member (patron)`, the glossary entry passes while `patron` written elsewhere is still found.
To pass a word everywhere, write the word alone on an `allow:` line.
Whitespace inside the phrase may differ from the text.
The older Japanese keyword for `allow:` (U+8A31 U+3059, followed by a colon) is still read, so existing tables keep working.

`--words` can be repeated, and a later table overrides an earlier one for the same word.
Passing the same tables to `figure.py --words` checks the names inside figures as well, and `check.py --words` passes them to both.
Once the text and the figures agree on a name, write the name in the table: a later edit that brings the old name back is hard to notice by eye.

### The bundled lists

For a Japanese document, `prose.py` also uses [`references/prose-words.txt`](./prose-words.txt).
Its first column is the kind of word, and the comments at the top of the file describe each kind.

| Kind | What it lists | Turned off by `--no-default-words` |
|---|---|---|
| `wordy` | phrases that can be dropped or shortened without changing the facts | no |
| `jargon` | words no reader understands; merged with the term table | yes |
| `logbook` | words about the state of the work | no |
| `bare-english` | English words written outside backticks, matched as whole words in any case | no |
| `coined` | made-up words used where the field has an established term | no |
| `worker-heading` | words that mark a heading written for the person making the document | no |
| `allow` | English words never flagged as `bare-english` | no |

For a document that is not Japanese, the bundled lists are not used and `--no-default-words` changes nothing.

Pass [`references/words-plain.txt`](./words-plain.txt) with `--words` when a Japanese document is written for general readers.
It lists technical katakana words that are ordinary in the field but unknown outside it, with plainer replacements.
A technical document does not pass it, so those words stay allowed there.

## Terms

The scripts find the words in the lists and one word written two ways.
They cannot tell that **one thing has two names**, so a person reads for that.

- Each figure and the text use the same name for a thing (an overview figure saying "Loan service" while a section figure says "Checkout API" reads as two different things)
- An abbreviation is spelled out once, where it first appears
- Among the letter-case variants `prose.py` lists for a Japanese document, the ones that name the same thing use one spelling

Letter case is counted, never failed, because one spelling can name two things (a company and a payment method can share a name).

## Content

The scripts check only mismatches of form, never whether the text is true.
The evidence (a specification, the code, measured values) lives outside the document, so a person checks these four things.

- Numbers and units (amounts, days, counts) match the source or a measurement
- A pointer such as "see Figure 5" leads to that figure
- The yes and no cells of a table agree with the text
- Decided and undecided things are not mixed

## Headings

**A Japanese heading has no ideographic comma** (`、`).
A heading is read at a glance; with a comma inside, the reader cannot tell one heading from two headings side by side.

| Finding | What happened | Fix |
|---|---|---|
| `heading comma` on a heading that joins two topics | two subjects are joined with a comma | remove the comma and join them with the particle for "and" |
| `heading comma` on a heading that lists items | items are listed | separate them with the middle dot (U+30FB) |

The check covers `h1` to `h6` and `<summary>`.
A collapsed block's `<summary>` is also read at a glance, so it follows the same rule.
Body text and table cells are not checked, because a comma inside a sentence is correct.

## Worker's notes

**Leave no record of the making in the document.**
"We compared this and dropped it", "for now", and "later we will" mean nothing to the reader.
State the design that was chosen and its reasons, in the present tense.

The scripts fail on three things.

| Finding | What happened | Fix |
|---|---|---|
| `logbook` word (Japanese documents) | the state of the work stayed in the text | state the reason for the design in the present tense, or drop the sentence |
| `worker heading` | the plan for the work stayed in a section heading | use words a reader looks for, or drop the section |
| `blue link` or `link color not set` | links inside the document look like links that leave it | give `a` the color of the body text |

The `logbook` words and the Japanese worker-heading words are in [`references/prose-words.txt`](./prose-words.txt).
`TODO` as a worker heading is checked in every language by [`scripts/prose.py`](../scripts/prose.py).

The link check reads the `color` of every rule that selects `a` and fails when blue is clearly higher than both red and green.
A color written as `var(--x)` is followed to its definition.
A value that cannot be read is counted on its own line instead of passing as "not blue".

## Identifier subjects

In a Japanese document, a sentence fails when both of these hold.

- Its subject is an identifier in `<code>` followed by the topic or subject particle
- It contains a verb from [`references/metaphor-words.tsv`](./metaphor-words.tsv) (the `personify` and `operation` rows)

A folder or script name written as if it had a will leaves the reader to work out who actually does the thing.
Rewrite the sentence with the real actor, or use the plain verb from the `usual meaning` column.
The verbs alone match many correct sentences, so a verb without an identifier subject never fails.
An identifier written without `<code>` is not seen.

## Figures and the text

`figure.py` checks how the figures and the text fit together: that every figure has a caption, where legends sit, and whether a paragraph leads into each figure.
Run it next to `prose.py` and read its `OK`, `NG`, and `--` lines the same way.

## Wordiness

`prose.py` never fails on length.
A long paragraph is right in some places, such as the lead-in to a table or a list of steps, and splitting it would break the reading order.
It shows the counts and the longest items instead.

Go through the longest items from the top and fix only the ones with one of these three shapes.

| Shape | Fix |
|---|---|
| Two points in one paragraph | drop the second point, or move it to the section about it |
| Examples or lists longer than the answer | move the examples into a collapsed block |
| Another section says the same | keep it in one place and delete the other |

**Move information instead of deleting it.**
What leaves a paragraph goes to another section or into a collapsed block.

## Thresholds

| Option | Default | Meaning |
|---|---|---|
| `--para` | 160 for Japanese, 700 otherwise | characters that make a paragraph long |
| `--sent` | 100 for Japanese, 220 otherwise | characters that make a sentence long |
| `--dup` | 22 | shortest sentence counted as a repeat; shorter set phrases would fill the count |
| `--top` | 5 | how many of the longest items are listed |

Japanese text is counted in characters without whitespace, other text in characters with whitespace collapsed to one space.
The defaults differ by language because one Japanese character carries about as much as a whole English word.
`check.py` passes `--para` and `--sent` on to `prose.py`.
Lengths are only counted, so change them only when the listed items are not useful, for example a document for specialists whose paragraphs are long on purpose.
