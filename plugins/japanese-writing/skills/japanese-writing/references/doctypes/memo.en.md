# Research memos and discussion papers: write first what you want decided

The question a research memo answers is how much is known about this issue now, what is not yet decided, and what the people who read it are asked to judge. It differs from minutes, which record what happened, and from a report, which conveys research results as reliable information. It is written before the conclusion is settled, as a draft to draw out readers' judgments and discussion. So it needs to contain both the tentative conclusion and the unresolved issues.

## Required elements

- Put the central claim in the title or the first sentence (in the form 「〜すべきである」 ("~ should be done") or 「〜が課題である」 ("~ is the problem"), not 「〜について」 ("about ~"))
- Write the title and the first sentence in words that make sense even before the body is read. Do not use names first explained in the body (「A案」 ("plan A"), 「第2案」 ("the second plan"), and so on); say the content instead (「紙の申請書をやめて Web フォームにしたい」 ("we want to stop using paper application forms and move to a web form") rather than 「A案を採用したい」 ("we want to adopt plan A"))
- Scope and what is out of scope (what is discussed and what is deliberately not discussed). Write as out of scope only what appears in the material or in the user's words
- Write in this order: background → problem setting → proposals or issues → unresolved issues → conclusion
- What this memo wants decided (write it at the top)

## Structure

Show the central claim and what you want decided at the top, then move on to the background and the problem setting. Even when the conclusion is not yet settled, show it first, after stating that it is the 「現時点での見立て」 ("current view"). With a structure where readers cannot reach the claim without reading in order from the background, people who stop reading partway do not learn what the memo wanted to say.

Write definitions of concepts in running text, not split out as a glossary. If definition sentences of the form 「Xとは〜である」 ("X is ~") open paragraphs three times in a row, that alone looks mechanical (SKILL.md §2 principle 8). Mixing in the form where you write the explanation first and give it a name after using it (「この動線を、本メモでは平時導線と呼ぶ」 ("this memo calls this flow the everyday path")) keeps the same pattern from repeating. Do not use the form that puts a long definition in parentheses in the middle of a sentence, because readers lose the thread of the sentence. If you give something a name, give it one whose content is clear from the name alone (SKILL.md §2 principle 4).

When comparing options, a comparison table with set axes helps readers judge more than a list of pros and cons. Lining up the options on the same axes, such as 「コストが低い/高い」 ("low/high cost") and 「導入が速い/遅い」 ("fast/slow to adopt"), lets readers read the table according to their own priorities. Put 「—」 in the cell of an option the axis does not apply to. Do not write the circumstances of the table or of the material as they are, such as 「該当しない」 ("not applicable") or 「記載なし」 ("not stated").

If scope and out-of-scope are not written, readers wonder why this issue is not touched on. Adding a word on why it is deliberately not discussed (it has been settled elsewhere, there is not enough information this time, and so on) shows that it was left out on purpose, not by oversight. But do not make up plausible out-of-scope items that are not in the material (such as 「顧客からの問い合わせは含めない」 ("customer inquiries are not included")).

## About the writer's view

The value of a memo lies in the writer's current view being attached to the unresolved issues (such as 「現時点では A 案に傾いている」 ("for now, leaning toward plan A")). Just listing questions does not give the discussion a starting point.

But the view belongs to the writer. When you write a memo for the user, write as the view only what is in the material or in the user's words. If there is none, ask the user which way they lean. When fixing an existing memo, do not add a view that is not in the original (the rule at the top of SKILL.md).

The view is not the only thing you must not add. Do not write conditional judgments such as 「〜と分かったら始めないほうがよい」 ("if ~ turns out to be the case, it is better not to start"), or plans such as evaluation metrics, schedules, criteria for continuing or stopping, and new contact points or procedures, unless they are in the material. If you write something the writer has not promised as the writer's plan, readers take it as part of the proposal. If you think a plan is missing, tell the user instead of adding it to the body.

A view is a way of seeing the issue itself; it is not attaching a ranking or stages such as 「最優先・次点・後回し」 ("top priority, next, later") to the issues. Especially when the center of the claim is that something applies equally to every target, do not rank the targets; keep them side by side. For the unresolved issues too, first consider whether they can be grouped by kind rather than by priority.

## Quality criteria

- The title or the first sentence alone shows what the memo claims. It does not end by only naming the subject, as in 「〜についての検討」 ("a study of ~")
- The unresolved issues have the writer's view attached. They are not just listed and closed with 「今後の検討課題」 ("issues for future study")
- The comparison of options has axes readers can use
- Cases and numbers the writer has checked, not generalities, support the central claim. If the claim still stands with the proper nouns and numbers removed, the material is not enough
- Readers know what they should judge next
- Judgments and plans not in the material (evaluation metrics, schedules, conditional judgments, and so on) have not been added

## Failures AI tends to make

The most likely failure is only organizing concepts, with no first-hand information or cases checked by the writer at all. When paragraphs are filled only with sentences like 「一般に〜と考えられる」 ("it is generally thought that ~") and 「〜というアプローチが有効である」 ("the approach of ~ is effective"), the content is the same whoever writes it. Of the issues covered, narrow down to the 2 or 3 that have material and write them in depth, and write the rest briefly (SKILL.md §2 principle 7).

Another is ending with only a list of unresolved questions and no writer's view anywhere. Conversely, there is also the failure of AI adding plausible views or numbers that are not in the material. Get the view from the material or from the user.

## Principles that matter most here (SKILL.md §2)

- Principle 1 (conclusion first): show the central claim in the title and the first sentence. A preamble such as 「〜について検討する」 ("we study ~") is no substitute for a claim
- Principle 3 (cause and history in running text): write the background and history of the issues in running text, and use bullet lists only for truly parallel items, such as comparison axes or a list of options
- Principle 10 (degree of certainty): write 「未解決」 ("unresolved") for unresolved issues, then add the view
- Principle 11 (fact and opinion): do not mix first-hand information or research results with the writer's view. Write 「〜と考える」 ("I think ~") and 「〜と推定する」 ("I estimate ~") as distinct

## Example: a concept memo for a disaster-prevention app

Consider writing a memo from the following material.

Material (received from the user): 県内の自治体アプリの利用状況を調べた県の報告書では、ダウンロード数に比べて災害時の起動率が低い。原因は、平時に開く理由がないことだと自分は見ている。通知方式の候補は、プッシュ通知だけの案、サイレンと連動する案、両方を組み合わせる案の3つ。比べる軸は、届く速さ、電池の消費、誤報のときに取り消しやすいか。プッシュ通知だけの案は速いが、誤報のときに不信感を招きやすいので、いまは組み合わせる案に傾いている。高齢者向けの画面をどう検証するかは決まっておらず、社内にユーザーテストの経験がない。外部の使い勝手調査に予算をつけるかを決めたい。 ("A prefectural report on the use of municipal apps in the prefecture shows that the launch rate during disasters is low compared with the number of downloads. I see the cause as there being no reason to open the app in normal times. There are three candidate notification methods: push notifications only, linking with sirens, and combining both. The axes for comparison are speed of delivery, battery use, and how easy it is to cancel after a false alarm. Push notifications only is fast but tends to cause distrust after a false alarm, so for now I lean toward combining them. How to test the screens for older people is not decided, and the company has no experience with user testing. I want to decide whether to fund an outside usability study.")

An example that only names the subject and ends with a list of questions:

> # 地域防災アプリの検討について ("On studying a local disaster-prevention app")
>
> 近年、災害時の情報伝達手段としてスマートフォンアプリが注目されている。本メモでは地域防災アプリの可能性について検討する。 ("In recent years, smartphone apps have drawn attention as a way to pass on information during disasters. This memo studies the potential of a local disaster-prevention app.")
>
> 検討すべき論点は以下の通りである。 ("The issues to study are as follows.")
> - 通知の仕組みをどうするか ("how to design the notification mechanism")
> - 高齢者にも使いやすいUIをどう実現するか ("how to build a UI that is easy for older people too")
> - 平時の利用をどう促すか ("how to encourage use in normal times")
>
> これらについては今後さらなる検討が必要である。 ("These need further study going forward.")

An example that writes the claim and the view first:

> # 防災アプリが災害時に開かれない原因は、平時に開く理由がないことだと考える ("I think disaster-prevention apps are not opened during disasters because there is no reason to open them in normal times")
>
> 県の報告書によると、県内の自治体アプリは、ダウンロード数に比べて災害時の起動率が低い。筆者は、原因は平時に開く理由がないことにあると考えている。このメモでは、通知方式と高齢者向けの画面について、判断してほしい論点を示す。 ("According to the prefectural report, municipal apps in the prefecture have a low launch rate during disasters compared with their downloads. The writer thinks the cause is that there is no reason to open them in normal times. This memo sets out the issues we want judged on the notification method and the screens for older people.")
>
> 通知方式の候補は、プッシュ通知だけ、サイレン連動、その組み合わせの3案で、届く速さ・電池の消費・誤報のときの取り消しやすさで比べられる。プッシュ通知だけの案は速いが、誤報のときに不信感を招きやすい。筆者は現時点では組み合わせる案に傾いている。 ("The candidate notification methods are three plans: push only, siren-linked, and a combination of the two, which can be compared on speed of delivery, battery use, and ease of cancelling after a false alarm. Push only is fast but tends to cause distrust after a false alarm. For now the writer leans toward the combined plan.")
>
> 未解決なのは高齢者向けの画面の検証方法で、社内にユーザーテストの経験がない。外部の使い勝手調査に予算をつけるかどうかを、このメモで判断してほしい。 ("What is unresolved is how to test the screens for older people; the company has no experience with user testing. We want you to judge, through this memo, whether to fund an outside usability study.")

The example that writes the claim and the view first uses only the facts and the view in the material, shows the source (the prefectural report), and separates opinion from fact with 「考える」 ("think") and 「傾いている」 ("lean toward"). The view of the cause is written with 「考える」 in the title too, and is not stated outright as fact. No numbers, comparisons, or proposals outside the material have been added.

## How it differs from minutes and reports

A research memo is written at a stage before minutes, which are a record (→ `minutes.md`), and reports, which convey reliable facts (→ `report.md`). It is a document that presents the issues before discussion starts. So at the end, place the issues you want judged, not decisions. Without awareness of this difference, you end up writing issues that are not yet settled as if they were certain, and they need correcting later.

Write a memo on the assumption that readers will reply with agreement or disagreement. If you write in one sentence, for each issue, what you want readers to judge, readers find it easier to reply.
