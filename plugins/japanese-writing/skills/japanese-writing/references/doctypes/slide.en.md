# Slide structure: the line of reasoning holds even when you read only the messages

The question slides answer is whether, when you read only the messages in order from top to bottom, the line of reasoning that leads to the conclusion comes across. Build them on the assumption that the audience looks at one slide for a few seconds and really reads only the title and the one sentence that stands out. So put the whole claim in the message, and keep the evidence bullets as material that supports it. This document covers the structure and the role of each element. For how to write sentences, follow SKILL.md §2.

## Required elements

Build each slide from the following three.

- Title: the theme the slide covers. A short noun phrase is fine
- Message: one sentence that states the slide's conclusion outright (also called the lead sentence, リード文). Put it right under the title, in the most visible position. Make it one sentence, up to about 50 Japanese characters. If it gets long because it lists what you want to say, narrow it to the one point you most want to say, and move the rest to the evidence bullets or split the slide
- Evidence: bullets that support the message. Prefer numbers and cases, and do not restate generalities. Match the number of bullets to the weight of the slide; if one point is enough, one point is fine

## Structure

The basic overall flow has three parts: introduction (sharing the problem and the goal), main body (groups of evidence, 3 or fewer), and conclusion (what you want the audience to do next). If the main body is split into 4 or more groups, the audience cannot judge which is the main line and which is an add-on. When there are 4 or more pieces of evidence, treat the main 2 or 3 in depth, and gather the rest on one slide and touch on them lightly (SKILL.md §2 principle 7).

For checking, the most useful thing is to read only the messages, straight through from the first to the last (SKILL.md §5 「構造の点検」 ("checking the structure")). Check the following.

- Does the argument hold?
- Does each message state a conclusion?
- Does the same sentence pattern keep repeating?
- Is there a difference between important slides and the others?
- Does the last slide lead to what you want the audience to do next?

If the line of reasoning does not hold here, no amount of polishing the evidence will get the talk across.

When writing the slides out as text too, show each slide kept within a few lines of title, message, and bullets. Not inserting explanations in paragraphs is the big difference from the other document types; since you cannot rely on running text, concentrate the information in the one-sentence message. Do not bold labels such as 「タイトル:」 ("Title:") and 「メッセージ:」 ("Message:"), or words in the bullets. If every line is bold, emphasis no longer works as emphasis, and the screen gets noisy.

## Quality criteria

- The message fits in one sentence of about 50 characters. It is not a long sentence that only lists items, such as 「A、B、Cの3点はまだ分かっていない」 ("the three points A, B, and C are not yet known")
- The message states the conclusion outright. It does not end as a label like 「新機能の概要」 ("overview of the new feature"), but goes as far as 「新機能で入力時間が半分になる」 ("the new feature halves input time")
- Reading only the messages in a row, you can follow the flow to the conclusion. The line of reasoning is clear even if you skip the evidence slides
- The evidence is written with concrete numbers and cases. It is not filled with generalities such as 「効果が見込まれる」 ("an effect is expected")
- The amount of information differs from slide to slide. If every slide has the same number of lines and the same number of bullets, the difference in importance has disappeared
- The last slide shows what you want the audience to judge or do. It does not end with 「ご清聴ありがとうございました」 ("thank you for listening")

## Failures AI tends to make

The most common failure is a message that ends as a label and does not state a conclusion. If a title like 「導入のメリット」 ("benefits of adoption") or 「今後の展望」 ("future outlook") is placed where the message goes, what the slide claims is unclear until all the evidence has been read.

The next most common is putting out the places where the material is lacking as placeholders such as 「[サービス名]」 ("[service name]") and 「[想定コスト]」 ("[estimated cost]"). Temporary entries meant to be filled in later get submitted as a finished structure. If the material is lacking, ask the user before filling it in.

One more failure that often happens: the bullets on every slide come in exactly 3 points every time, and important slides can no longer be told from light ones.

## Principles that matter most here (SKILL.md §2)

- Principle 1 (conclusion first): make the message the slide's conclusion itself. Do not make it a preamble or a summary of how things got here
- Principle 2 (write the conclusion in headings): on slides, the title may be a label, but the message must always be a conclusion sentence
- Principle 7 (light and heavy): narrow down the groups in the main body, give important evidence plenty of numbers and cases, and settle light evidence in one line
- Principle 12 (closing): close the last slide with what you want the audience to do, not a repeat of the facts

## Example: a proposal slide for a sales support tool

Consider writing one slide of a proposal from the following material.

Material: いまは CRM と見積システムに同じ案件情報を別々に入力していて、1案件あたり平均12分の重複作業がある。新しいツールは CRM への入力を見積システムに自動で反映するので、この重複がなくなる。3チームで試験導入したところ、4週間後に営業1人あたり平均で週1.8時間の作業時間が減った。 ("Today the same deal information is entered separately into the CRM and the quoting system, which causes an average of 12 minutes of duplicate work per deal. The new tool automatically reflects what is entered in the CRM in the quoting system, so this duplication goes away. In a trial with 3 teams, after 4 weeks work time fell by an average of 1.8 hours per week per salesperson.")

An example that ends as a label:

> タイトル:新営業支援ツールについて ("Title: about the new sales support tool")
> メッセージ:新ツールの導入メリット ("Message: benefits of adopting the new tool")
> - 業務効率が向上する ("work efficiency improves")
> - 情報共有がスムーズになる ("information sharing becomes smoother")
> - 顧客満足度の向上が期待できる ("higher customer satisfaction can be expected")

An example that states the conclusion outright:

> タイトル:案件情報の二重入力 ("Title: double entry of deal information")
> メッセージ:二重入力をなくした試験導入で、営業1人あたり週1.8時間の作業が減った ("Message: a trial that removed double entry cut 1.8 hours of work per salesperson per week")
> - いまは CRM と見積システムに同じ情報を別々に入力しており、1案件あたり平均12分の重複作業がある ("today the same information is entered separately into the CRM and the quoting system, with an average of 12 minutes of duplicate work per deal")
> - 新しいツールは CRM への入力を見積システムに自動で反映し、この重複をなくす ("the new tool automatically reflects CRM entries in the quoting system and removes this duplication")
> - 3チームの試験導入で、4週間後に平均で週1.8時間の削減を確かめた ("a trial with 3 teams confirmed an average cut of 1.8 hours per week after 4 weeks")

In the example that ends as a label, reading all three pieces of evidence still does not tell you how much things improve, and the evidence is generalities that are not in the material. The example that states the conclusion outright uses only numbers in the material, and the number in the message is the same 1.8 hours per week as in the evidence. If the message rounds the number to make it sound bigger, it contradicts the evidence. Also, because this is the result of a trial with 3 teams, the example does not write it as a general effect, as if removing double entry would cut work anywhere; it writes 「試験導入で減った」 ("fell in the trial").

The same difference shows up on the introductory slide. Just listing 「現状の課題」 ("current problems"), 「新ツールの提案」 ("proposal of the new tool"), and 「導入スケジュール」 ("adoption schedule") under the label 「本日のアジェンダ」 ("today's agenda") leaves the audience unable to guess the content. If you write the agenda itself as a preview of the conclusion, as in 「二重入力をなくした試験導入で、営業1人あたり週1.8時間の作業が減ったので、全体への導入を提案する」 ("a trial that removed double entry cut 1.8 hours of work per salesperson per week, so we propose rolling it out to everyone"), the audience knows from the first slide what to listen for.

## When the material is lacking, ask instead of filling in

In slide requests, values such as company names, costs, and adoption dates are often not all there from the start. Putting out a tentative structure with placeholders like 「[サービス名]」 and 「約[金額]円」 ("about [amount] yen") looks finished but has nothing inside, and leads to a lot of rework later. When you notice places where numbers or proper nouns are missing, check with the user which numbers to use before filling them in. If there is a reason you cannot check, write 【要確認】 ("to be confirmed") in that place and tell the user that it is meant to be replaced later.

Even when the request is only one sentence, 「〇〇についてのプレゼン資料を作って」 ("make presentation slides about 〇〇"), there is less rework if you first show the conclusion (candidate messages) and the number of groups in the main body and get agreement before writing in the evidence. If the structure turns out to be wrong, fixing it at the structure stage is far lighter than fixing it after building out all the slides.

## Decide the number of slides from the number of conclusions

If you decide the number of slides first and then allocate the content, you get slides that only fill time, or slides with too many claims packed into one. First count how many groups the evidence of the main body forms, then add the introduction and the conclusion to that, and use the total as the number of slides. If there are only 2 groups but you build a structure for 3, one of them gets padded.
