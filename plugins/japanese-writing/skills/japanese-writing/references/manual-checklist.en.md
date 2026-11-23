# Manual checklist (for environments where lint cannot be used)

Steps to check by eye instead of lint, in environments where `uv` is not available and `scripts/lint.py` cannot run (such as Claude.ai). The approach to fixing is the same as in SKILL.md: for each spot you find, record as you go whether you fixed it or, if you keep it, why (SKILL.md §4).

You do not need to check everything strictly every time. First look at 1 to 3, and if the document concerns you, go on to 4 to 9. Step 10, when fixing an existing document, is not skipped for any document.

## 1. Phrases common in text written by AI

Look for the following phrases. Most of them can be deleted without changing the meaning. Only when deleting one breaks the connection with what comes before and after, reword it with the content of the original document. Keep it if it is part of a proper noun or a quotation.

- Ways of pushing a conclusion: と言えるでしょう、と言えるだろう、と言えます、ということになるでしょう、のではないでしょうか、結論から言うと、結論として、まとめると、総じて、いかがでしたか、いかがでしょうか
- Emphasis: 非常に重要、極めて重要、重要なのは、大切なのは、ポイントは、言うまでもなく、言うまでもありません、まさしく
- Preambles and bridges: さて、それでは、このように、このような中、ここで注目したいのは、見ていきましょう、紹介していきます、解説していきます、深掘りしていきます、について見ていく、を探求する
- Hedges: 一概には言えません、個人差がありますが、あくまで一例ですが
- Words that state an attitude instead of content: 正面から扱う (the same goes for 「正面から見る」, 「正面から書く」, and the like)、不可欠、核心的、鍵となる、根本的な、多角的、包括的、総合的、掘り下げる、深掘りする、言語化する

「重要なのは」, 「このように」, 「不可欠」, 「ポイントは」, and 「さて」 also appear often in human writing, so one or two of them are nothing to worry about.

## 2. Translationese phrasing

Turn phrasing that traces English syntax into the way it is normally said in Japanese. Do not change the degree of certainty.

- Change 「〜という点で」 ("in terms of ~") and 「〜という観点から」 ("from the viewpoint of ~") to 「〜では」 ("in ~") or 「〜で見ると」 ("looking at it as ~")
- Change 「〜にとって重要」 ("important for ~") and 「〜にとって不可欠」 ("essential for ~") to 「〜には〜が要る」 ("~ needs ~")
- Change 「〜を持つ」 ("has ~") with an abstract object to 「〜がある」 ("there is ~")
- Change 「〜することによって」 ("by doing ~") to 「〜して」 ("doing ~") or 「〜すると」 ("when you do ~")
- State 「〜であることは間違いない」 ("there is no doubt that ~") and 「〜に他ならない」 ("is nothing other than ~") as 「〜だ」 ("is ~"). If the original document gives grounds, put them first. Do not add grounds
- For a sentence that has a thing or a matter as the subject and takes it up with 「もたらす」 ("bring about"), 「示す」 ("show"), 「意味する」 ("mean"), or 「証明する」 ("prove"), make a person or a situation the subject, or use 「〜から分かる」 ("one can tell from ~") or 「〜を見ると」 ("looking at ~")
- For 「それは〜である。なぜなら〜だ」 ("It is ~. Because ~."), write the reason first, or combine it into one sentence with 「〜だからだ」 ("it is because ~")
- Change 「〜することができる」 ("is able to do ~") to 「〜できる」 ("can ~") or the potential form of the verb

## 3. Negation and contrast

If 「〜ではなく〜」 ("not ~ but ~") or 「〜だけでなく〜も」 ("not only ~ but also ~") appears 3 or more times in the whole document, or 4 or more sentences end with 「〜ではない。」, 「〜ではありません。」, or 「〜わけではない。」 ("is not ~", "it is not that ~"), suspect overuse (do not count questions such as 「〜ではないでしょうか」 ("isn't it ~?")). Handle them separately as follows (SKILL.md §3).

- Delete the whole sentence when it negates in advance a belief nobody has stated (「〜するだけで自動的に〜わけではない」 ("just doing ~ does not automatically ~"))
- For 「AはBではない。Cだ。」 ("A is not B. It is C."), delete the negation and join the subject to the affirmative sentence
- Keep negations that narrow the meaning, facts that are easily misunderstood, cautions, and contrasts that explain a difference

## 4. Sentence length

Check whether the sentences in each paragraph are almost all the same length. If they are too uniform in a document you are writing new, split or join sentences to match the units of content. When fixing an existing document, do not change sentences for this reason alone. Do not insert short sentences just for rhythm. Split a sentence that has two or more claims in it (SKILL.md §3).

## 5. Paragraphs

Check whether every paragraph has the same number of sentences (for example, 3 each). Match the length of a paragraph to the weight of its content. If many paragraphs begin with a conjunction such as 「しかし」 ("however"), 「また」 ("also"), or 「そして」 ("and"), remove the conjunction where the content already connects.

## 6. Repeated openings and sentence builds

Check whether the same opening (such as 「そして、」 ("and,") or 「これは、」 ("this is,")) or sentences with the same build continue 3 or more times. If they do, swap the order of the sentences or their subjects, or combine two sentences into one. Do not insert questions or noun-ending sentences (体言止め) as a means of breaking the pattern.

## 7. Noun-ending sentences (体言止め)

A document of more than about 2000 characters with not a single noun-ending sentence is a trait often seen in text written by AI. This is reference information, so you do not need to force them in.

## 8. Paragraphs of generalities only

Look for paragraphs with no proper nouns, numbers, or real examples. When writing new text, gather material again. When fixing an existing document, do not add concrete examples or numbers yourself; tell the user what material would make it concrete (SKILL.md §3).

## 9. Readability

Check by eye the items in SKILL.md §5 「読みやすさの点検」 ("readability check"). In particular, look at double negatives (when you rewrite one in the affirmative, check that true and false have not flipped), long sentences with two or more claims, runs of 7 or more kanji, 3 or more 「の」 in a row, and lists of 3 or more items buried in a sentence.

## 10. Paragraph-by-paragraph check

Instead of `scripts/paragraphs.py`, number from the top each heading, each bullet item, each table row, and each prose paragraph. For every paragraph, write out what matches the 6 kinds of 「読み手の手間を増やしている箇所」 ("spots that add work for the reader") in SKILL.md §3 and the 7 kinds of phrasing where the reader cannot tell what is meant, in the form 「番号: 言い回し → 指しているもの」 ("number: phrase → what it refers to"). For a paragraph with no match, write 「番号: なし」 ("number: none"). Write out through the last paragraph before you start fixing.

## Structure check

`scripts/outline.py` cannot be used either, so pull out the headings and the first sentence of each paragraph by hand, line them up, and check the items in SKILL.md §5 「構造の点検」 ("structure check").

## Convergence and finishing

End by state, not by count. End when every spot you found is sorted into 「直した」 ("fixed") or 「残す(理由)」 ("keep (reason)") and the fixes have not created new spots. If the problem at the same spot comes back twice in a row, rewrite the whole build of the sentence or paragraph, or keep it with a reason.

To finish, instead of `scripts/calques.py`, look for verbs that apply the movements of people or things to machine processing (拾う・引く・通る・効く・響く・足す) ("pick up", "pull", "pass through", "take effect", "resonate", "add") and nouns that liken a mechanism to a place (入口・受け口・口・〜先) ("entrance", "receiving opening", "mouth", "~ destination"), including the text in headings, tables, and figures. Handle the words found as SKILL.md §6 「読み手の分野の言葉と照らし合わせる」 ("check against the words of the reader's field") says.

Finally, put the fixed document beside the original and check that no facts, numbers, evaluations, or policies that the original does not have have entered (the rule at the top of SKILL.md). Instead of `scripts/newfacts.py`, take each number, proper noun, and word in Latin letters that appears only in the fixed document, and look for it in the original document one by one.
