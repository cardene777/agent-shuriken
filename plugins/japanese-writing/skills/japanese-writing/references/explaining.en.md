# Patterns for explaining

This file was written for this plugin. Upstream does not have it.

It rewrites, to fit the documents here, the points of a talk for junior high and high school students, 「わかりやすい説明のための 10 の鉄則」 ("10 iron rules for clear explanations") (2023).
Read the six about writing before writing (§4 of `references/rules.md`), and read the four about display only when handling slides.
The numbers are the speaker's guidelines, not values checked against a corpus.

## Hard-to-follow explanations come from two causes

| Cause | What happens to the reader | Typical case |
|---|---|---|
| The main point does not come across right away | The reader reads on while still holding the question of what this is about | The conclusion does not appear until the last paragraph |
| The reader cannot picture the content | The reader can read the words but cannot picture what happens | Explaining with words the reader does not know, or only with abstract definitions |

Of the six below, 1, 2, and 4 address the first cause, and 3, 5, and 6 address the second.

## The six for writing

### 1. Put the main point first

There are three kinds of main point. They are the conclusion, the overall picture, and what is about to be explained.
The purpose of the document decides which one goes first. For a report it is the conclusion, and for a procedure document it is the overall picture.

Principles 1 and 2 of 「2. 書くときの原則」 ("2. Principles when writing") in the upstream body point in the same direction.
The only thing this adds is that **in an explanation, 「何を説明するか」 ("what will be explained") also counts as a main point**.
「設定を変える方法は 2 つある」 ("There are two ways to change the setting") is not a preview but a main point that hands the reader, up front, the number they will hold (pattern 2 of item 4).

### 2. Narrow the information given at one time

In one paragraph, give only the information the reader needs for the current decision.
If you line up the route, the travel time, and the fare in one sentence, the reader has to pick out again which one is the current topic.

The rule in 「2. 書くときの原則」 of the upstream body that a sentence holds one claim is a rule at the level of the sentence, and this one narrows at the level of paragraphs and sections.
Move information the current decision does not need to a later section or a note, or do not write it.

### 3. Write with words the reader knows

How hard a word is depends not on the word itself but on the reader's background knowledge.
For readers in the same field, use the field's standard terms as they are, and for readers outside the field, explain the term by its function at its first use (upstream article 4).

**Do not make text plainer by replacing a term with a different Japanese word** (§3 of `references/rules.md`).
When giving `冪等` (idempotent) to readers outside the field, explain it once at its first use as 「同じ操作を何度繰り返しても結果が変わらない性質」 ("the property that repeating the same operation any number of times does not change the result"), and write `冪等` after that.

When background knowledge is missing, easier words do not get the point across.
You cannot explain trigonometric functions to a reader who does not know functions, so either write from the prerequisites or narrow the readers.

### 4. Put the explanation on a pattern

Two patterns can carry many explanations.

| Pattern | Order | When it fits |
|---|---|---|
| Return-to-the-conclusion pattern | Conclusion → reason → concrete example → conclusion | When you want one claim accepted |
| Number-first pattern | Number → first → second → … | When the reader reads while holding a count, as with choices or steps |

There are three cautions when using a pattern.

- Do not make the final conclusion a repeat of the first one. Restate it in light of the reasons and the examples (the re-integration of upstream article 12)
- Do not use the same pattern three times in a row (upstream article 8)
- Write the number in the number-first pattern only when each item is explained in running text. Do not write it if it becomes a run-up to a thin bullet list

### 5. Put a concrete example right after an abstract explanation

A definition alone does not let the reader picture the content.
Right after the definition, put one value or situation.

```
冪等とは、同じ操作を何度繰り返しても結果が変わらない性質を指す。
たとえば注文を確定する要求を 2 回送っても、作られる注文は 1 件だけになる。
```

("Idempotence is the property that repeating the same operation any number of times does not change the result. For example, even if a request to confirm an order is sent twice, only one order is created.")

「実名と実数で接地する」 ("ground it in real names and real numbers") in upstream article 5 is about backing up a claim, and this item is about letting the reader picture a definition.
Choose a concrete example that fits the claim of the text. An example only loosely related to the claim makes the reader picture a different topic.

### 6. Make figures match the text

When adding a figure, keep two things.

| What to keep | What happens if you do not |
|---|---|
| The figure draws the claim that the text states | If you place a temperature chart where sales trends are being explained, the reader does not know what to look at |
| Do not end the explanation with the figure alone | If the text does not show where to look in the figure, the reader reads the figure according to their own interests |

The speaker's guideline is 「400 字につき図 1 つ」 ("one figure per 400 characters"), and the speaker also notes that opinions differ on it.
If the repo that uses this skill has rules for figures in explanatory material, follow those rules when making the material.

## The section to read only when handling slides

Read this section when the document type is a slide outline (`references/doctypes/slide.md`).
What this skill writes is the claim of each slide and the order of the slides, and the work of actually adjusting colors and line spacing belongs to the side that makes the slides.
The four rules here are content to include in the instructions to that side.

| Rule | Content |
|---|---|
| One claim per slide | If three topics are on one slide, split it into three slides. This points in the same direction as the message line in upstream `slide.md` |
| Up to 3-4 colors per slide | Give similar groups similar colors. To show stages, do not add colors, and use shades of the same color instead. Do not use motion effects |
| Line spacing of 1.3-1.5 times, with space left open | When the speaker asked the audience, more than 80% answered that the version with wider line spacing was easier to read |
| Emphasis on 5-10% of the whole | Emphasize three things: the main point, the part of the figure to look at, and the current position in a procedure |

**Do not apply the emphasis ratio to documents**.
For bold in documents, upstream article 6 (one core spot per sentence) is stricter, and documents follow that rule.
5-10% is a guideline for when a slide has little text.
