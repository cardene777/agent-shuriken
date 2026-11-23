# Three forms of AI-sounding text

This file was written for this plugin. Upstream does not have it.

It puts into this plugin's own words only the points that do not overlap upstream, taken from a talk that analyzed AI-sounding text (September 2026) and from the README and explanatory article of the readability skill `yomiyasu` (MIT).
The example sentences were made for this plugin.

## The three forms, and where each is handled

AI-sounding text comes from how sentences are built more than from word choice.
The ways that building breaks down fall into three forms.

| # | Form | What happens to the reader | Where it is handled |
|---|---|---|---|
| 1 | Starting from a contrast, a negation, or a hedge, and not writing the main clause directly | The reader first pictures the negated side, then comes back to the main point | In the upstream body, principle 1 (preamble), principle 9 (negation), and principle 10 (vague sentence endings) of 「2. 書くときの原則」 ("2. Principles when writing"), and the section 「打ち消しは、中身のあるものだけを残す」 ("Keep only negations that carry content"). Repetition is `antithesis_repetition` in `lint.py` |
| 2 | Not saying what to do, through abstract words and metaphor verbs | The reader translates it into the actual operation on their own | This plugin's `subject-and-verb.md`. Line-by-line suspicion is `suspects.py` |
| 3 | Making the text look like more than its content, through short sentences, parallel phrasing, unnatural commas, and nominalization | Only an impression remains, and no steps or reasons remain | The upstream body's section 「演出の言葉は、削るだけで外す」 ("Remove staging words just by deleting them") and principle 6 (bold). Density is `high_bold_density` and others in `lint.py`. What upstream does not cover is in the sections below |

## When pointing something out, name the form and the word

Do not reply only with 「AI っぽい」 ("AI-like").
Write which of the three forms it is, which word it is, and what happens to the reader.
Put the form's name in the 〔理由〕 ("reason") part of the way fixes are returned (§7 of `references/rules.md`) too.

**Do not fix by guessing a sentence whose meaning you cannot grasp**.
Ask the writer, for example 「この文の『揃える』 は、値を同じにすることか、順番を合わせることか」 ("Does 『揃える』 (align) in this sentence mean making the values the same, or matching the order?").
Fixing by guessing adds a meaning the writer did not say (§ Do not add meaning).

## Replacing a word does not fix the structure

If you replace a pointed-out word with another word of the same meaning, the broken structure remains.
Changing 「解像度を上げる」 ("raise the resolution") to 「粒度を上げる」 ("raise the granularity") still leaves unwritten what is made finer, and how far.

What you fix is the structure of the sentence: rewrite who does what, and how.
Adding a word to the term list does not change the structure, so do not count a longer word list as a fix.

## Turn sentences that end in a verbal noun back into verbs

A sentence that joins nouns with 「の」 and ends on a サ変名詞 (a verbal noun, which becomes a verb when 「する」 is added) leaves the reader to rebuild who does what.

| Original | Fixed form |
|---|---|
| 設定値の検証処理の追加。 ("Addition of validation processing of setting values.") | 読み込んだ設定値を検証する処理を足す。 ("Add processing that validates the loaded setting values.") |
| 障害発生時の連絡経路の明確化。 ("Clarification of contact routes at failure occurrence.") | 障害が起きた時に、誰が誰へ連絡するかを決めておく。 ("Decide in advance who contacts whom when a failure happens.") |

The fix has three steps.

1. Bring out the verb hidden in each verbal noun (検証 → 検証する ("validation" → "validate"), 明確化 → 決める ("clarification" → "decide"))
2. Take that verb's actor and object from the sentences around it
3. Choose which words to keep as nouns (keep words that are established terms in the field)

**Headings, table cells, and the item names in bullet lists are out of scope**.
Their job is to name things briefly, and applying the rules for running text there makes them harder to read.

Upstream says in C2 that 「サ変名詞化そのものの検出は未実装で、目視で判断する」 ("detecting nominalization into verbal nouns itself is not implemented, so judge it by eye").
`suspects.py` points at sentences in running text where the word right before 「。」 is a verbal noun.
The chain of 「の」 itself is pointed at by `no_chain` in `lint.py --reading-load`, so `suspects.py` does not count it.

## Do not create variation in sentence length with punchlines

`low_sentence_variance` in `lint.py` appears when sentence lengths are too uniform.
Upstream's `lint.py` also attaches to this finding a way of fixing it that does not insert short sentences only for rhythm.
Applied mechanically, the finding leads to inserting short assertions that carry no information, such as 「ここが勝負所だ。」 ("This is where it counts.").
That in itself becomes a new AI-sounding trait.

Create the variation from the content of the sentences.

| What to do | Example |
|---|---|
| Join two sentences that share a cause | 「設定が古い。 そのため検査が落ちる。」 → 「設定が古いため、検査が落ちる。」 ("The settings are old. So the check fails." → "Because the settings are old, the check fails.") |
| Split a sentence that holds two claims | Split a sentence that packs a reason and a step into one into a sentence for the reason and a sentence for the step |

**Short sentences that carry facts may stay**.
「3 件とも失敗した。」 ("All three failed.") is short but carries information.
The 「短い断定」 ("short assertion") of `suspects.py` points at short sentences that contain no number and no identifier, so judge by whether the sentence it points at carries a fact.

## Do not add meaning

When restoring the actor, and when turning a metaphor into an operation, **take the material from the original and the sentences around it**.
Adding an actor or a specification that the original does not have makes the sentence easier to read but wrong.

When fixing `設定が静かに上書きされる` ("the settings are silently overwritten"), if the surrounding text does not say what overwrites them, do not write 「配布の処理が上書きする」 ("the distribution process overwrites them").
Ask the writer, or leave 「どの処理が上書きするかは書かれていない」 ("it is not written which process overwrites them") in 〔理由〕.

Do not add disclaimer sentences or generalities either (「どの文書でもしないこと」 ("Things not to do in any document") in the upstream body).
Do not drop the numbers and constraints in the original.

## Numeric guidelines and this plugin's rules

This section lists the guidelines that external skills give, and which rule takes precedence here.
The guidelines are material for estimating the reader's load, not targets to match (the rule in 「2. 書くときの原則」 of the upstream body that a sentence is not cut only because of its length).

| Guideline | Value | How it is handled here |
|---|---|---|
| Length of one sentence | 30-45 characters on average | Upstream B1 uses 40-60 characters as a guideline and does not make it an absolute threshold. Do not shorten back a sentence that became longer because its actor was made explicit |
| Commas (読点) in one sentence | 0-2 | Check by eye with upstream B4 (position of commas) |
| Bold | 2 or fewer per 1000 characters | `high_bold_density` in `lint.py` counts it |
| Bullet lists | 15% of lines or less | `high_bullet_ratio` in `lint.py` counts it. Tables do not count as bullet lists |
| Emoji | Do not use | `high_emoji_symbol_density` in `lint.py` counts it |
| Colon at the end of a sentence | Do not use | `suspects.py` points at it. A 「ラベルとコロンの 2 項の列挙」 ("two-item list made of a label and a colon") is also not written, per §2 of `references/rules.md` |
| Space between Japanese and alphanumeric characters | Do not insert | If the repo in use has a rule, follow that rule |

## Write the skill's own text by the same standard

Whoever writes from instructions drifts toward the style of the instructions.
If a skill's text is written with metaphor verbs, metaphor verbs remain in the fixed text too.

For this skill's hand-written files, a check confirms that their running text holds 0 of the metaphor verbs and metaphor adverbs that `suspects.py` looks for.
Put metaphors shown as examples in backticks or a code block (`suspects.py` does not count them).
