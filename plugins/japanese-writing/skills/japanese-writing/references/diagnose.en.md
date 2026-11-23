# Diagnosis mode (score): return the AI smell as a score and reasons, without rewriting

Diagnosis mode does not rewrite the document at all, and returns only three things: the score, its grounds, and what to fix first if you fix it. This mode answers requests such as 「この文章、AIっぽい?」 ("Does this text read like AI?") and 「どれくらいAI臭いか採点して」 ("Score how much it smells of AI"); when a rewrite is asked for, switch to the normal process (SKILL.md §1–7).

## Three levels of depth

The diagnosis levels quick / full / exp set how deeply to look. Because there is no rewriting step, their content differs from the run modes in SKILL.md. When they conflict, follow this section.

- quick (default): run `lint.py --json` once (with `--genre` if the genre is known), and skim the headings and the first sentence of each paragraph. Do not use subagents. About 30 seconds
- full: in addition to quick, run `outline.py` and `terms.py`, and take into the judgment the results of the structure check, the readability check, and the document type match (SKILL.md §5). You may use subagents only when splitting a long document among them makes reading faster. Diagnosis does not check for convergence and ends after one evaluation. A few minutes
- exp: in addition to full, run the experimental detector `semantic.py --json`. It downloads a model of about 1 GB on the first run, so on the first run tell the user before starting. It looks as far as flatness of topic, which remains even after the wording has been cleaned up

## Computing the score: two layers, machine base and judgment adjustment

The score is a naturalness score from 0 to 100, and higher means more natural (less AI smell). When returning it to the user, also add a word on which way is better. It is built in two layers, and the breakdown is always disclosed.

Machine base (deterministic): start from 100 points and deduct for lint findings, normalized by document length. In the text output of lint, critical, warn, and info are shown as 「重大」, 「警告」, and 「情報」.

```
deduction = (critical×8 + warn×4 + info×0.5) × (1000 / max(document character count, 1000))
machine base = max(100 − deduction, 20)
```

The document character count is the number of characters in the whole body. A len that includes line breaks and Markdown syntax is fine (it is a rough normalization, so precision is not needed). The shorter the document, the more one finding weighs, and a long document is deducted by density rather than by count. The coefficients are rough values set so that one critical finding equals 2 warn findings or 16 info findings. The floor of 20 is there so that machine findings alone do not bring the score down near 0. When semantic_topic_flatness (warn) appears in exp, include it in the same formula. If the body is empty or effectively empty (under 100 characters), do not give a score, and return 「診断対象として短すぎる」 ("too short to diagnose").

Judgment adjustment (within ±15 points): in full / exp, adjust for problems found in the structure check and the readability check. Deduct for structural habits like the following, which lint cannot detect.

- Every section has the same build
- Bullets are lined up without grounds or connections
- Degrees of certainty are not written differently
- A report does not say what to do next
- Items that are parallel by nature are given a ranking

When lint seems to misfire and you judge a finding natural in context, give back its deduction. In quick, do not adjust, and use the machine base as is (in exchange, state clearly in the result that 「quick の精度は粗い」 ("quick is coarse in precision")). Clamp the final score after adjustment to 0–100 (min(max(score, 0), 100). Even if the machine base is 100 and the adjustment adds points, the score does not go over 100).

The score is a rough guide that includes judgment, and it can move by a few points even for the same document. It is not a number to use as a CI gate. Add this caution to the result in a word or two.

## Bands and how to say them

| Score | Band | Example of how to say it |
|---|---|---|
| 90–100 | Natural | Almost no AI smell found. Any findings are a matter of taste |
| 70–89 | Minor | A few habits remain, but readers are unlikely to feel it is 「AIっぽい」 ("AI-like") |
| 50–69 | Needs fixing | Clear AI smell in either the surface or the structure. Worth fixing |
| 0–49 | Heavy | Strongly detected in several categories. A rewrite is recommended |

## Output format

1. The score and the band (with the breakdown into machine base and judgment adjustment)
2. 3 to 5 main reasons: write them by content, not by category name. Like 「『〜ではなく』の対比が全文の文のうち4%で機械的なリズムになっている(L12ほか)」 ("the 'not ~ but' contrast is in 4% of all sentences and makes a mechanical rhythm (L12 and others)"), give the line number of a representative spot and say in a word why it is AI smell
3. What to fix first: 2 or 3 items, in order of effect. But diagnosis mode does not fix anything. End by adding 「リライトしますか(quick/full)」 ("Shall I rewrite it (quick/full)?")

Do not copy the lint detail into the reasons; restate them in line with the context of the document. Even when there are many findings, do not list them all; narrow down to the ones that moved the score the most.
