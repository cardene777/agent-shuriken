# How to write questions and choices

This file was written for this plugin. Upstream does not have it.

It was written on 2026-10-06, when the sample of the confirmation sheet that shows a person choices and has them answer was rebuilt, from the places the person sent back and the forms that passed after fixing.
Read it when writing questions that ask a person to choose.
It covers the questions on a confirmation sheet and the questions with choices put to a person in chat.

## A question is made of three parts

| Part | What the reader wants to know |
|---|---|
| The one-line question | What is being decided |
| The explanation under the question | What situation it is about, and what is being decided |
| The names and descriptions of the choices | What happens if they choose it |

Of the four rules below, 1 and 2 shape the explanation under the question, 3 shapes the choices, and 4 shapes the amount of the whole question.

## Four rules

### 1. In the explanation under the question, write the situation first, then what is being decided

If you write only 「何のための問いか」 ("what the question is for"), the reader has to imagine and fill in what situation it is about.
Every explanation that was sent back had this form.

| Before | After |
|---|---|
| 直すべき所が、直されないまま取り込まれるのを防ぐための問いです。 ("This question is to keep things that should be fixed from being taken in unfixed.") | 作った物を受入条件と見比べると、満たせていない条件が見つかることがあります。<br>例えば10個のうち1個が満たせていない時、その1個をどう扱わせるかの問いです。<br>("When you compare what was built with the acceptance criteria, you may find criteria it does not meet. For example, when 1 of 10 is not met, this question asks how to have that 1 handled.") |
| 回し先の番号を書き間違えると、後回しにした条件がどこにも残りません。 ("If the number of the destination is written wrong, the postponed criterion is left nowhere.") | 問1のAで「別の課題に回す」を選ぶと、回し先の課題の番号を書きます。<br>その番号の課題が本当にあるかまで、機械に確かめさせるかの問いです。<br>問1でA以外を選んだ時は、答えなくて大丈夫です。<br>("If you choose 「別の課題に回す」 (send it to another task) in A of question 1, you write the number of the task it goes to. This question asks whether to have the machine also check that a task with that number really exists. If you chose something other than A in question 1, you do not need to answer.") |

When the answer to another question is a premise, also write which answer makes this question relevant.
A person who chose an answer that does not make it relevant can skip the question.

### 2. Show the situation with an example that has numbers

A situation written abstractly, like 「満たせていない条件が出た時」 ("when an unmet criterion comes up"), is one the reader cannot picture.
Put one example with numbers, like 「10個のうち1個が満たせていない時」 ("when 1 of 10 is not met").
This is item 5 of [`explaining.md`](explaining.md) (put a concrete example right after an abstract explanation) applied to questions.

### 3. Make the names and descriptions of the choices say what happens when read on their own

Do not use numbers or abbreviations that only make sense inside the work (段 4 ("stage 4") / step 19 / 出口 A ("exit A")) in choices.
「このまま進む」 ("go on as is") does not tell what stays as is or where it goes.

| Before (name / description) | After (name / description) |
|---|---|
| このまま進む / 段6と段7は飛ばして次の段へ ("go on as is / skip stages 6 and 7 and go to the next stage") | 作り始める / 実装の計画へ進む ("start building / go on to the implementation plan") |
| 受入条件を直す / 段4へ戻る (段19と段5ももう一度通る) ("fix the acceptance criteria / go back to stage 4 (stages 19 and 5 are passed again too)") | 受入条件から直す / 受入条件を書き直してから、もう一度このシートを見る ("fix from the acceptance criteria / rewrite the acceptance criteria, then look at this sheet again") |
| 設計だけ直す / 段19へ戻る (受入条件はそのまま) ("fix only the design / go back to stage 19 (the acceptance criteria stay as they are)") | 設計だけ直す / 受入条件はそのままで、設計だけ書き直す ("fix only the design / keep the acceptance criteria as they are and rewrite only the design") |

Keep the numbers on the side that records the answer (the text that is pasted back, or the issue comment).
Do not show them on the side that people read.

### 4. Keep the premise short, and narrow the questions to about three

If you list a whole list in the premise, the reader runs out of reading energy before reaching the questions.
The version that listed the 19 lines of acceptance criteria in the premise was sent back with 「この19項目とか何？」 ("What are these 19 items?").
The fixed version narrowed the premise to two boxes, 「いま」 ("now") and 「おすすめを全部選ぶと」 ("if you choose all the recommendations").

Even if it looks like one question, split it if it decides more than one thing.
The version that was a single question, 「この仕様で実装へ進めてよいか」 ("May we go on to implementation with this spec?"), passed after it was split into two questions about the content and one question, 「作り始めてよいか」 ("May we start building?").
If there are more than five questions, narrow the points before putting them out.

## Five rules for the wording of questions

| Rule | Example |
|---|---|
| Write the names of things at a level of detail where the reader can tell what the thing is and where it is on the screen | 「本文」→「GitHubのIssueの説明文」 ("body" → "the description of the GitHub issue") |
| For a word made up during the work, write what it means at its first use, and replace it if an everyday word will do | 「課題の型」→「Issueごとに選ぶ進め方（通し・画面なし・軽微）」 ("task type" → "the way of proceeding chosen per issue (full, no screens, minor)") |
| Write the subject and the object: who does what, and where | 「型は課題ごとに1つで」→「Issueを起票した人かAIは、Issueごとに進め方を1つ残します」 ("one type per task" → "the person or AI who filed the issue records one way of proceeding per issue") |
| Do not insert unneeded commas | 「課題の型は、どこに書きますか」→「進め方はどこに書きますか」 ("The task type, where do you write it?" → "Where do you write the way of proceeding?") |
| Do not put spaces before and after English words and numbers | 「13 件」→「13件」 ("13 items") |

When writing questions, follow these five as well.

## What to check after writing

| What to check | If it applies |
|---|---|
| Whether the explanation under the question ends with only 「〜ための問いです」 ("this question is for ~") | Add one sentence that describes the situation at the start |
| Whether the situation has one example with numbers | Add one sentence that starts with 「例えば」 ("for example") |
| Whether the names and descriptions of the choices contain numbers or abbreviations used only inside the work | Replace them with words that say what happens when the choice is chosen |
| Whether the premise is longer than the questions | Remove the list and keep only the differences needed for the decision |
| Whether there are two or fewer questions and one of them holds more than one thing to decide | Split the questions, one for each thing to decide |
