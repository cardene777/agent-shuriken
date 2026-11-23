# Internal guides and manuals: readers open them only when they are lost

The question an internal guide answers is how to do this operation right now. Helping readers understand the whole system is not its main purpose. Most readers do not read it through. They jump from the table of contents or a search to the chapter they want, read only that chapter, and go back to work. So a guide is judged less by how complete it is when read through and more by whether it keeps readers from getting lost when only part of it is read. This document covers the chapter structure and the paths between chapters. For how to write sentences, follow SKILL.md §2.

## Required elements

- A 「まず覚えること」 ("what to remember first") part at the top (the bare-minimum actions readers must follow, numbered, 3 to 4 of them)
- The intended readers. It is enough if the title or one line at the top makes this clear. Write prerequisite knowledge only when readers need it to judge whether the guide is for them
- A distinction between the parts to read through and the parts to look up when needed (write at the top something like 「1〜3章は初回に通読、4章以降は必要なときに引く」 ("read chapters 1-3 through the first time; look up chapter 4 onward when needed"))
- A glossary. Include one when the body uses terms readers do not know. Terms explained in the body also go into the list at the end once more
- Where to ask (where to take questions this guide does not solve)

Of these, the one most often left out is the distinction between the parts to read through and the parts to look up. Writers assume the table of contents makes it clear, but readers cannot judge from the table of contents alone. If the top does not say how far to read to get the minimum understanding, readers either look through every chapter every time or skip even the chapters they need.

## Change the structure to fit the nature of each chapter

If every chapter is built the same way, readers have to judge again in each chapter how carefully to read. If the build fits the nature of each chapter, readers can switch how they read just by seeing the build.

- Narrative type: suits introductory chapters. Explains things in order, following the flow of the work
- Reverse-lookup type: a build close to a lookup table that shows the means for each 「〜したい」 ("I want to ~"). Suits readers whose goal is already decided
- Hands-on type: lists one operation per step, and right after each step adds a word on why to do that operation. Steps and reasons alternate, so readers follow the operations by understanding them, not by memorizing them
- Reference type: lists parameters and settings in a table. It is not something to explain in running text

Whatever the build, use the following ways of writing as the base. A guide is a document people look things up in, and readers look for the lines that concern them, so this takes priority over SKILL.md principle 3, 「箇条書きは本当に独立して並ぶときだけ」 ("use bullet lists only when the items truly stand side by side on their own").

- The top may start with one line addressed to readers (for people who have just joined, a line of welcome). Then list 「まず覚えること」 numbered, 3 to 4 items (more than that cannot be remembered), and after that write a pointer to what to read. Do not write preambles that readers will not use for their next action, such as who prepared this guide or what assumptions it can be read under
- Make headings short names that show at once what the section is about (「VPN につながらないとき」 ("when you cannot connect to the VPN"), 「パスワードの再設定」 ("resetting your password")). A build that uses a conclusion sentence as the heading and writes the content in running text gets skipped in a guide. In guides, this takes priority over the heading rule in SKILL.md §1. Only reverse-lookup chapters write the answer in the heading too (see the example later)
- Give one subheading to each item (a rule with a deadline, one operation, one exception). Do not gather items into one section and join them with running text. Write the content of each item with bullets and numbers only, and do not insert an introductory sentence or a paragraph of reasons. When a reason is needed, add it at the end of that line as a short phrase in parentheses with no 読点 (the Japanese comma 「、」). If it gets long enough to need a comma, write it as one sentence on the next line
- Number the steps, with one action per step. Before the steps, write in one sentence what the steps are for. Add only a word of reason right after a step, and move long explanations to another section (do not start explaining the mechanism in the middle of the steps)
- Write rules (deadlines, conditions, exceptions) as bullet lists
- Do not use stiff phrases such as 「該当の」「当該」「〜の際は」 ("the applicable", "the said", "on the occasion of ~"); write in the words people use in everyday speech (「その節を開く」 ("open that section") rather than 「該当の節を開く」 ("open the applicable section"))
- Put common mistakes in a two-column table of 「症状」 ("symptom") and 「直し方」 ("fix") (「VPN につながらない|ルーターを再起動してから、もう一度つなぐ」 ("cannot connect to the VPN | restart the router, then connect again")). Readers search from the symptom, so make the fix visible on the same line. Put where to ask (困りごと|連絡先, problem | contact) and terms (用語|意味, term | meaning) in tables too
- For sentences addressed to readers, check that the reader is the subject. Do not mix the writer's circumstances (who hands it out, why this guide was made) with instructions to readers in one sentence. 「全体会議で共有し、迷ったときに参照してください」 ("share it at the all-hands meeting and refer to it when you are unsure") has a twisted subject: the writer is the one who shares it, and the reader is the one who refers to it

Keep involved explanations out of the body, and separate them as a 「補足」 ("supplementary note"), for example at the end of the chapter. But if the lead-in to the supplement uses the same phrase every time, that itself becomes a monotonous pattern. In each chapter, use a phrase that shows what is being supplemented.

## Quality criteria

- Readers can reach the chapter they want from the table of contents headings alone. Use names that show what the section is about, such as 「VPN につながらないとき」, not names whose content is unclear, such as 「概要」 ("overview") or 「利用方法」 ("how to use")
- A reader who has not read the earlier chapters can do the work from that section alone. Do not write sentences that bridge chapters, such as 「ここまでで〜できました。ここからは〜です」 ("so far you have done ~. From here on, ~."). In a document people look things up in, they are not read and only make the section longer. Only in long narrative introductory chapters may you write a word on how the chapter relates to the previous one
- When several chapters explain the same concept, the later chapters write only the differences. Write it like 「詳細は3章を参照。ここでは4章で違う点だけを述べる」 ("see chapter 3 for details; here, chapter 4 describes only what differs")
- Chapters not yet written are not padded with boilerplate as thick as the other chapters. For some chapters, writing 「準備中」 ("in preparation") and showing only where to ask is enough
- Operations readers must not do are written as a pair of the operation and its result. Do not end with 「注意してください」 ("please be careful"); write what happens if that operation is done

## Failures AI tends to make

The most common failure is writing every chapter with the same build and the same sentence length, so readers can no longer judge the weight of each chapter. A chapter that takes 2 lines and one that takes 10 lines get the same heading level and the same section structure. Deciding before writing how much each chapter is worth writing prevents this (SKILL.md §1 「濃淡」 ("light and heavy")).

The next most common is pasting a stock bridge such as 「詳細は次章で解説します」 ("details are explained in the next chapter") into every chapter: it looks like a bridge but connects nothing. Another is stating screen operations or behavior that have not been checked as if they were certain. For steps that have not been checked, mark the degree of certainty, as in 「〜と表示される想定」 ("expected to show ~"), and limit firm statements to what the material or the user has confirmed.

## Principles that matter most here (SKILL.md §2)

- Principle 2 (headings): in a guide, a heading is not a conclusion sentence but a short name that shows what the section is about. In reverse-lookup chapters, each line maps 「症状や目的 → 手段」 ("symptom or goal → means")
- Principle 7 (light and heavy): write the parts to read through in depth, and the parts to look up lightly, with tables and short notes
- Principle 8 (do not repeat the same pattern): check whether chapter openings, lead-ins to deep-dive notes, and the phrasing of references to other chapters take the same form three times in a row
- Principle 10 (degree of certainty): mark steps that have not been checked and chapters not yet written with a label that shows that state

## Template: the shape of one guide

The example is a guide to connecting to the internal VPN at a fictional company.

```
# 社内 VPN 接続ガイド(在宅勤務をする人向け)

在宅勤務を始める方へ。自宅から社内のシステムを使うときは、このガイドの手順で VPN につないでください。

## まず覚えること
1. 社内のシステムを使う前に、VPN アプリで「接続」を押す
2. パスワードは90日ごとに変わる。期限の7日前に通知が届く
3. つながらないときは、下の「困ったとき」を見る

初回は「はじめての接続」だけを読めば足ります。ほかの節は、必要になったときに開いてください。

## はじめての接続
1. 社内ポータルから VPN アプリをダウンロードする
2. アプリを開き、社員番号とパスワードを入れる
3. スマートフォンに届く確認コードを入れる

## パスワードの更新
- 90日ごとに更新が必要
- 期限の7日前に、メールで通知が届く
- 期限を過ぎると接続できなくなる(情報システム部で再発行が必要)

## 困ったとき
| 症状 | 直し方 |
|---|---|
| 「認証に失敗しました」と出る | パスワードの期限が切れていないか確かめる |
| つながるがすぐ切れる | 自宅のルーターを再起動してから、もう一度つなぐ |
| 確認コードが届かない | 情報システム部に連絡する |

## 問い合わせ先
| 困りごと | 連絡先 |
|---|---|
| 接続の操作 | 情報システム部(#it-help) |
| 在宅勤務の申請 | 総務部 |

最終更新日:2026年4月1日
```

In this template, the opening line is only an instruction with the reader as the subject, and it does not say who made the guide. Each item has one subheading, and its content is only numbers and bullets, with no paragraphs of running text. Symptoms and fixes, and where to ask, are in tables. Reasons stay as a short phrase in parentheses at the end of a line, as in 「(情報システム部で再発行が必要)」 ("(must be reissued by the IT department)").

## Example: an internal guide for an expense reimbursement system

Consider writing chapters of a guide from the following material.

Material: 申請は領収書1枚につき1件。経理の突き合わせが領収書単位なので、まとめて申請すると差し戻しになる。承認後の振込は自動で、通常は3営業日。月末は遅れることがあるが、どのくらい遅れるかは経理チームに確認中。 ("One application per receipt. Accounting matches records receipt by receipt, so applications that combine receipts are sent back. Payment after approval is automatic and usually takes 3 business days. It can be late at month end, but how late is still being checked with the accounting team.")

An example written with headings whose content is unclear, in running text:

> ## 概要 ("Overview")
> 経費精算システムの使い方を説明します。申請は領収書1枚につき1件です。経理の突き合わせが領収書単位で行われるため、まとめて申請すると差し戻しになりますので注意してください。承認後は自動で振り込まれます。 ("This explains how to use the expense reimbursement system. One application per receipt. Because accounting matches records receipt by receipt, please note that applications that combine receipts are sent back. After approval, payment is made automatically.")

An example written with headings that show what the section is about, in bullets:

> ## 申請のしかた ("How to apply")
> - 領収書1枚につき1件で申請する。まとめて申請すると差し戻しになる(経理の突き合わせが領収書単位のため) ("Apply once per receipt. Combined applications are sent back (because accounting matches receipt by receipt)")
>
> ## 振込 ("Payment")
> - 承認後、自動で振り込まれる。通常は3営業日 ("After approval, payment is automatic. Usually 3 business days")
> - 月末は遅れることがある。どのくらい遅れるかは経理チームに確認中【要確認】 ("It can be late at month end. How late is being checked with the accounting team [to be confirmed]")

Both examples use only the same material. With the second one, readers find the section by its heading and only need to read one bullet line. Reasons stay as a short phrase in parentheses, and the month-end delay, which has not been checked, is not stated as certain but marked 【要確認】 ("to be confirmed").

In reverse-lookup chapters, the form of the headings itself changes. Consider writing the 「困ったとき」 ("when you are stuck") chapter of the same guide from the following material.

Material: 領収書をなくしたときは「紛失理由書」フォームから代わりに申請できる。差し戻しの理由は、通知メールの末尾に書いてある。海外出張の外貨の領収書は、申請日のシステム内レートで自動で換算される。 ("If you lose a receipt, you can apply instead through the 'loss explanation' form. The reason an application was sent back is written at the end of the notification email. Foreign-currency receipts from overseas business trips are converted automatically at the system's rate on the application date.")

Line up the headings as follows.

> ## 領収書をなくした → 「紛失理由書」フォームから代わりに申請できる ("Lost a receipt → you can apply instead through the 'loss explanation' form")
> ## 申請が差し戻された → 差し戻しの理由は、通知メールの末尾に書いてある ("Application sent back → the reason is written at the end of the notification email")
> ## 海外出張の領収書が外貨 → 申請日のシステム内レートで自動で換算される ("Receipt from an overseas trip is in a foreign currency → it is converted automatically at the system's rate on the application date")

A narrative chapter explains one flow of operations in order, while in a reverse-lookup chapter each line is an independent mapping. Readers read only the lines close to their own situation, so the connections between lines do not matter. Even within one guide, the build may change from chapter to chapter.

## Fix a guide while it is being used

An internal guide is a document where questions from readers become, as they are, the material for the next revision. Put the last-updated date at the end, and add where to ask about points this chapter did not make clear.

You do not need to rewrite every chapter at each revision. Thicken only the chapters where questions concentrated, and leave chapters with no questions as they are. If you keep updating every chapter the same way, readers cannot tell what changed.

Unlike minutes or reports, an internal guide is not a document for keeping the state at the time it was written. It is a document for changing what readers do now, so old steps left in it lead to actual wrong operations. Do not hide the last-updated date; write it.
