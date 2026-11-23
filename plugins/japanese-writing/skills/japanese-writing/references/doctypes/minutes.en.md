# Minutes: write decisions and action items separately from the body

## The question this document answers

The question minutes answer is what was decided, and who will do what by when; recording what people said is not the goal in itself. Most readers either did not attend the meeting or attended but remember it only vaguely, and they just need to check the decisions and action items in a few tens of seconds. In a record that only traces the remarks in time order, the decisions are buried in the body, and readers have to read the whole thing again.

## Required elements

Meeting name, date and time, and attendees; the gist of the discussion for each agenda item; decisions; action items (with an owner and a due date); and carried-over items. Of these, the three items decisions, action items, and carried-over items are separated from the discussion in the body and gathered at the top. If they stay buried in the body, readers have to collect 「結局何が決まったのか」 ("what was decided in the end") themselves.

Write an owner and a due date for each action item. With 「チーム全員で対応」 ("the whole team handles it") or 「なるべく早く」 ("as soon as possible"), who acts and when is not decided. If no owner has been decided, write 「未定」 ("undecided").

When fixing existing minutes, do not fill in owners or due dates by guessing when they are not in the original record. If adding columns or sections that are not in the original (a due-date column, a section of carried-over items, and so on) would leave their content mostly 「未定」, do not add those columns or sections.

## Structure

The structure in this section is for writing new minutes. When fixing existing minutes, do not change the order or arrangement of the sections (SKILL.md §3). If you think readers would find decisions and action items more easily if they were moved forward, suggest doing so to the user.

At the top, put the meeting name, date and time, attendees, and pre-reading materials as a bullet list, one item per line. In Markdown, lines separated only by a line break are joined into one paragraph when displayed, and the mixed information becomes one lump that makes people not want to read it, so do not line up lines of running text. Then write the premises of the record in one paragraph. Stating at the start how accurate the transcription is, whether there is a recording, and how certain the identification of speakers is lets readers judge for themselves how far to trust the body. Also write here where to send corrections (comments, Slack, and so on).

Next, gather the decisions, action items, and carried-over items. This is what readers want to check first, so put it before the body. Use bullet lists for decisions and carried-over items, and a table or bullet list of owner, task, and due date for action items.

Split the body into one section per agenda item, and in each heading write a summary of what was decided on that item, what was not decided, or what was discussed. Write the course of the discussion in the body in running text. Do not treat an agenda item that takes 2 lines with the same weight as one that takes 10 lines. If needed, add 「次回に向けたメモ」 ("notes for next time") at the end. In this note, write only what to change next time, not a repeat of the body.

For style, noun-ending sentences (体言止め) and the 「である」 style are fine; there is no need to make everything consistently polite (丁寧体). Keep key remarks in the speaker's own tone. Smoothing 「それ先に言ってよ」 ("you should've said that first") into 「それを先に言ってほしい」 ("I would like you to have said that first") erases the force of the remark and the information about who said it and how.

## Quality criteria

- Reading only the list of decisions shows what changed and how. 「引き続き検討する」 ("continue to consider") is not a decision, so move it to the carried-over items
- Each action item has all three: owner, due date, and task. A good example is 「田中: 在庫アラートのしきい値案を7/18までに作成」 ("Tanaka: draft the inventory alert threshold proposal by 7/18"); a bad example is 「アラートのしきい値については検討していく」 ("we will look into the alert threshold")
- The certainty of who said what is marked. Where the speaker was inferred from a transcription, add something like 「(佐藤さんと推定)」 ("(presumed to be Sato)")
- The course of the discussion is written in running text, and only decisions and action items are bullet lists. This is because a discussion has causes and a time order. But items that stand on their own and are looked for later, like a list of advice, stay as a bullet list
- Advice and comments have the other person's response added in a word. If a review or a 1-on-1 records only the advice, it becomes the record of a one-way lecture, and what was agreed becomes unclear. A word like 「了承した」 ("agreed") or 「持ち帰って検討する」 ("will take it back and consider it") is enough. If the original record does not include the response, do not guess one

## Failures AI tends to make

When asked to write minutes, AI most often summarizes every remark with the same weight, and the decisions get buried with the same weight as the other opinions. If a check that ended in 5 minutes and an issue discussed for 30 minutes are listed in the same number of lines, readers cannot judge what was important. AI also fails to mark how certain each speaker is, so it tends to have everyone either state things outright or say 「〜と思われる」 ("it seems ~").

Writing 「合意した」 ("agreed") for things that were not decided is also a common failure. When pulling decisions out of a transcript, it is easy to mistake proposals and agreement for decisions.

Another is removing fillers such as 「えーと」 ("um") and 「まあ」 ("well") while keeping the wordy phrasing of spoken language. 「その件についてはですね、まあ一旦持ち帰らせていただいて、社内で検討した上でまた改めてご相談させていただければと思うんですけれども」 ("as for that matter, well, we'd like to take it back for now, discuss it internally, and then consult with you again, if that's all right") is fully covered by 「持ち帰って検討する」 ("will take it back and consider it").

## Principles that matter most here (SKILL.md §2)

- Principle 10 (mark degrees of certainty): marking the limits of the record and how certain each speaker is becomes the central role of minutes
- Principle 3 (cause and history in running text): do not list the course of the discussion as bullets; follow it in running text
- Principle 2 (write the conclusion in headings): an agenda heading states what was decided on that item, not 「議題1」 ("agenda item 1")
- Principle 7 (light and heavy): settle light agenda items in a word, and write only heavy ones in depth
- Principle 6 (bold): even when keeping a key remark, bold only the core of that remark

## Template

The example is the regular development meeting for 「在庫すいすい」 ("Zaiko Suisui"), an inventory management service developed by the fictional SaaS company ソラベース社 (Sorabase).

```
# 在庫すいすい開発定例(2026-07-10)

- 日時: 2026-07-10 10:00〜10:30
- 出席: 田中(PM)、佐藤(バックエンド)、鈴木(デザイン)
- 事前資料: 在庫アラートの誤検知の一覧(6月分)

記録の前提: 会議の録音はなく、田中のメモをもとに構成した。発言者の帰属はおおむね確実だが、推定が入る箇所には「(推定)」と添える。訂正はこのドキュメントへのコメントで受け付ける。

## 決定事項
- しきい値の算出方法を、在庫数から在庫回転率に変更する

## 宿題
- 田中: 回転率ベースのしきい値案を7/18までに作成
- 佐藤: 現行ロジックの改修範囲を7/15までに見積もる

## 継続議題
- 通知先をSlackに一本化するかは未定。次回、鈴木がUI観点の意見を持ち寄る

## 在庫アラートのしきい値は在庫数でなく在庫回転率で決める
現行のしきい値(在庫数10個未満で通知)は季節商品で誤検知が多いと、佐藤が指摘した。鈴木は、店舗担当者からも同様の苦情が来ていると補足した(推定: どの店舗からかは未確認)。佐藤が在庫回転率を基準にする案を出し、出席者3人が合意した。
```

## Example of reshaping a transcript into minutes

Original text:

> 田中さんから在庫アラートについて説明があり、現行のしきい値だと誤検知が多いという話になった。佐藤さんはそれに対して在庫回転率を使う案を出し、鈴木さんも賛成した。最終的にどう決まったかは次回また相談することになった。 ("Tanaka explained the inventory alerts, and it came up that the current threshold causes many false alarms. In response, Sato proposed using the inventory turnover rate, and Suzuki agreed too. How it would finally be decided is to be discussed again next time.")

Revised text:

> 在庫アラートの件は結論が出ず、次回また相談することになった。田中さんから在庫アラートの説明があり、現行のしきい値では誤検知が多いという話になった。佐藤さんが在庫回転率を使う案を出し、鈴木さんも賛成した。 ("The inventory alert issue reached no conclusion and will be discussed again next time. Tanaka explained the inventory alerts, and it came up that the current threshold causes many false alarms. Sato proposed using the inventory turnover rate, and Suzuki agreed too.")
>
> 継続議題 ("Carried-over items")
> - 在庫アラートの件(次回また相談) ("The inventory alert issue (to be discussed again next time)")

The original text traces the course of events in time order, so you cannot tell that nothing was decided until you read to the end. The revised text puts the conclusion (carried over) first and moves the course of events after it. No decisions, owners, or due dates that are not in the original have been added, and who said what is as in the original.
