# Research reports: write how the numbers bear on decisions

## The question this document answers

The question a research report answers is what is happening and what to do next. Collecting and describing data does not finish the research. What readers want to know is less the numbers themselves than how those numbers bear on decisions; if the writer does not write that far, readers have to look at the graphs and interpret them again themselves. A good report lets readers judge what to do next just by reading the first few lines.

## Required elements

Put the following six in this order.

1. Purpose of the research (who it is for and what they will decide with it)
2. Opening summary (main message and points)
3. Findings
4. Proposal of what to do next
5. Limits of the data
6. Method (in enough detail that a third party could follow the same steps)

Of these, do not leave out the method and the limits of the data, even if they are short. Without the method, readers cannot check how reliable the numbers are; without the limits, the numbers take on a life of their own.

## Structure

Build it in the shape of a pyramid. This is so that readers can judge from the top alone, and only those who want to check the evidence go on to the body. Make the top and the proposals bullet lists or tables so they are clear even when skimmed, and build the body sections for careful reading, from a conclusion sentence, a table, and short running text that gives the reasons.

- On the first line at the top, write the purpose of the research in one sentence (「7月の部会で解約対策を決めるため、4〜6月の解約を調べた」 ("we examined cancellations from April to June to decide on measures against cancellations at the July division meeting")). Do not make it a section
- Next, write a one-sentence main message. If the request includes 「決めたいこと」 ("what we want to decide"), the main message says how to decide (「〜を確かめてから、〜を決めるのがよい」 ("it is best to decide ~ after checking ~")). Do not end with findings only. Then list 2 to 4 points that support the main message as a numbered list. Make each item a conclusion sentence and its main figures. Separate the points so they do not overlap
- Do not put a definitions section or a method section at the top. Write a definition in one line near the table where that number first appears, and move the method section to the end
- Match each body section to one point at the top, and write that point as a conclusion sentence in the section heading. Reading only the headings in order should let readers trace the points at the top. Each section starts with the conclusion, then shows the evidence (tables and numbers)
- Things to line up and compare, such as segments, hypotheses, and options, may be put in tables. In reports, this takes priority over SKILL.md principle 3, 「箇条書きは本当に独立して並ぶときだけ」 ("use bullet lists only when the items truly stand side by side on their own"). What readers want to know is the result of the comparison, and running text makes comparison harder
- Write facts (what happened), interpretation (what that tells us), and actions or checks (what to do next) separately. Make it clear to readers which of these each sentence is
- Split the proposals into 「決める前にできる検証」 ("checks you can do before deciding") and 「決める場で選ぶ選択肢」 ("options to choose from at the meeting where the decision is made").
- Put the options in a table or bullet list, and add to each the numbers that support it, what to check, and the condition for choosing it (「検証で〜なら A、〜なら B」 ("A if the check shows ~, B if it shows ~")). Build the options from stakeholders' proposals in the material, options decided by the result of a check, and the option of doing nothing (waiting); do not add measures or numbers that are not in the material (periods, costs, expected effects, and so on). If the writer recommends an option, write 「〜と考える」 ("I think ~") and keep it to one. In fixed-point monitoring reports where the request has nothing to decide, do not create options
- Put the limits of the data and the method after the proposals. But place notes on easily misread numbers right next to those numbers (Quality criteria)
- Move technical details, such as aggregation queries or the breakdown of exclusion conditions, to the end or to an appendix

For a follow-up study, write one paragraph on its relation to the previous study right after the opening summary. Showing first what changed to prompt the new study, and which parts of the previous conclusion carry over and which are overturned, makes the place of the body clear. If a past issue contained an error, correct it near the top, not at the end. This is because readers need to know about the correction before they read the conclusion.

## Quality criteria

- People who read the opening summary know what to do next. If it only lists numbers and their meaning is written only deep in the body, it is not a summary
- Facts and analysis are written distinctly. Write so that a fact such as 「〜だった(出典: アクセス解析、7月集計)」 ("~ was the case (source: access analytics, July totals)") and the writer's analysis such as 「〜と考えられる」 ("it is thought that ~") can be told apart even within running text. Also do not mix up whether something is your own company's data or an inference from another company's case
- The writer has annotated easily misread numbers in advance. Points such as a total or average being pulled by one outlier, a small base making ratios unstable, or seasonal effects preventing a simple comparison are written before readers notice them. Do not gather the notes at the end; place each right next to its number
- The meaning of numbers is restated. Do not stop at 「継続率は4%だった」 ("the retention rate was 4%"); writing up to 「96%は継続しなかった」 ("96% did not continue") lets readers see the meaning without calculating
- The definition of the population is near the table where that number first appears. Write whether 「訪問数」 ("visits") means all access including bots or visits after excluding them, and from when to when the aggregation period runs. If definitions change from study to study, comparison with the previous one does not hold
- Segments get light and heavy treatment. Do not line up every segment with the same sentence pattern and the same length; write segments that changed in depth, and settle segments that did not change with the single phrase 「特に変化なし」 ("no notable change")

## Failures AI tends to make

The most conspicuous failure is stopping after describing the data, without writing what to do next. The text ends with 「訪問数は前月比で減少した」 ("visits decreased from the previous month"), and what should be done about it is written nowhere.

Conversely, AI also writes proposals that go beyond what the evidence supports. Deciding even the priority of measures from only some of the numbers makes the conclusion contradict the biases written in the notes.

The following failures also happen often.

- Lining up segment descriptions in the same sentence pattern, as in 「Aチャネルは〜だった。Bチャネルは〜だった。Cチャネルは〜だった。」 ("Channel A was ~. Channel B was ~. Channel C was ~."), which hides where the important differences are
- Gathering caveats at the end, so that the fact that one outlier pushed up the total reaches only those who read to the end
- Comparing with the previous period without writing the definition of the population. Writing increases and decreases without checking whether the definition is the same as last time can end up comparing nothing but differences in aggregation methods

## Principles that matter most here (SKILL.md §2)

- Principle 1 (conclusion first): the opening summary is itself the conclusion, with numbers
- Principle 12 (closing): do not end with a description of facts; write what to do next. But do not go beyond what the evidence covers
- Principle 11 (fact and opinion): make clear the sources, whether they are primary or secondary, and which parts are analysis
- Principle 10 (degree of certainty): do not hide the limits of the data or corrections of past errors
- Principle 7 (light and heavy): change how much you write for each segment

## Template

The example is the top and the proposal part of a monthly report on the traffic sources of the fictional e-commerce site 「そらマルシェ」 ("Sora Marche").

```
# そらマルシェ 流入経路調査(2026年6月分)

7月の販促会議で SNS 導線への予算配分を決めるため、6月の流入経路を調べた。

訂正: 前号(5月分)で「検索流入は横ばい」と書いたが、集計対象に
社内アクセスが混入しておりデータの誤りだった。除外後は前月比
5%減で、今号の「2カ月連続の減少」は訂正後の数値にもとづく。

SNS 導線への予算配分は、上位1商品を除いた7月の購入率を見てから決めるのがよい。

1. 検索流入が2カ月続けて減った(71,200件、前月比 -8%)。総訪問数の減少(-3%)の主因である
2. SNS経由の購入率は4.6%で、サイト平均(2.0%)の2.3倍に見える
3. ただし購入の41%が上位1商品(季節限定の虫よけスプレー)で、除くと2.1%と平均並みになる

(Body: one section per point. Each heading is the point's conclusion as a sentence; the conclusion first, then tables and reasons)

## 次にすべきこと

会議の前にできる検証
- 上位1商品を除いた SNS 経由の購入率を、7月前半の分で出す

会議で選ぶ選択肢
| 選択肢 | 支える数字 | 選ぶ条件 |
|---|---|---|
| SNS 導線の予算を増やす | 購入率 4.6%(平均の2.3倍) | 1商品を除いても平均を上回るとき |
| 今の配分のまま、検索流入の減少を先に調べる | 検索流入 2カ月連続の減少 | 1商品を除くと平均並みのとき |

## データの限界 / 方法
(placed at the end)
```

## Text that ends with description, and text that goes on to what to do next

Consider writing the body of a report from the following findings.

Material: 6月の数字。総訪問数 128,400(前月比 -3%)。検索流入 71,200(前月比 -8%、2カ月連続の減少)。SNS経由の購入率 4.6%(サイト平均 2.0%)。SNS経由の購入の41%が上位1商品で、この商品を除くと購入率は2.1%。チームの考え:SNS導線に力を入れるかは、この1商品を除いた数字を見てから決めたい。 ("June figures. Total visits 128,400 (-3% from the previous month). Search traffic 71,200 (-8% from the previous month, the second monthly decline in a row). Purchase rate via social media 4.6% (site average 2.0%). 41% of purchases via social media were the top single product; excluding that product, the purchase rate is 2.1%. The team's view: we want to decide whether to put effort into the social media path after seeing the numbers without this one product.")

Text that ends with description:

> 6月の総訪問数は128,400件で、前月から3%減少した。検索流入は71,200件で前月比8%減、SNS経由の購入率は4.6%だった。 ("Total visits in June were 128,400, down 3% from the previous month. Search traffic was 71,200, down 8% from the previous month, and the purchase rate via social media was 4.6%.")

Text that goes on to what to do next:

> 6月の総訪問数は128,400件で、前月比3%減だった。検索流入は2カ月続けて減り、前月比8%減の71,200件だった。前月比から逆算すると、検索流入の減少は約6,200件で、総訪問数の減少(約4,000件)より大きい。ほかの経路からの訪問は増えていることになる。SNS経由の購入率は4.6%でサイト平均の2.3倍だが、購入の41%を占める上位1商品を除くと2.1%で、平均(2.0%)とほぼ同じになる。チームとしては、SNS導線に力を入れるかどうかを、この1商品を除いた数字を見てから決めたい考えである。 ("Total visits in June were 128,400, down 3% from the previous month. Search traffic fell for the second month in a row, down 8% from the previous month to 71,200. Working back from the month-over-month change, the drop in search traffic is about 6,200, larger than the drop in total visits (about 4,000). This means visits from other sources have increased. The purchase rate via social media is 4.6%, 2.3 times the site average, but excluding the top single product, which accounts for 41% of purchases, it is 2.1%, almost the same as the average (2.0%). The team's intention is to decide whether to put effort into the social media path after seeing the numbers without this one product.")

The text that ends with description only lines up numbers, leaving readers to work out for themselves what to do. The other text uses only the numbers in the material, shows by calculation that the drop in search traffic is larger than the drop in total visits, writes first that the high purchase rate via social media rests on one product, and then writes the team's view as an intention, as it is (「決めたい考えである」 ("it is the intention to decide")). The calculated numbers (about 6,200 and about 4,000) are derived from the numbers in the material, and no numbers or reasons outside the material have been added.
