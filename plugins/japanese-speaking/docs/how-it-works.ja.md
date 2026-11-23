# 仕組み

[English](how-it-works.md) · 日本語

この頁は、Japanese Speakingが何を読み、何を動かし、何を残すかと、`speaking.py`が何を確かめ、決まりがどこから来たかを書きます。
台本を書くのはagentで、`skills/japanese-speaking/scripts/`のscriptは確かめるだけです。

## スキルのファイル

| file | 持つ物 |
|---|---|
| `SKILL.md` | agentが従う手順 (集める、段を並べる、書く、検査、別の読み手、直して検査し直す) |
| `references/speaking.md` | 話し言葉らしく書く決まりと、決まりごとの出典 |
| `references/formats.md` | 5つの形式の組み立て |
| `references/review.md` | 別の読み手へ渡す指示と、返す形 |
| `references/patterns.tsv` | `check`が出す型 (名前、正規表現、除く形、直し方) |
| `references/<名前>.en.md` | 同じ決まりの英語版。Markdownの参照ごとに同じ見出しで隣に置き、英語で読む人が使う。スキルは日本語のファイルだけを読む |
| `references/common-katakana.txt` | `check --source`が名前として扱わない、よく使うカタカナの外来語と、その英語の意味 |
| `scripts/speaking.py` | `check`と`patterns`の命令 |
| `tests/test-japanese-speaking.sh` | `tests/fixtures/`の写しで`check`を確かめ、`SKILL.md`の手順の順を確かめるテスト |

## checkが見る物

`check`は、JSONの台本 (行の配列か、`lines`と`readings`を持つ物) か、1行に1つの発話を書いた文の台本を読みます。
発話を文に分け、文ごとに型を1回ずつ`L<行番号> <型> <抜粋>`の形で出します。

| 型 | 出す物 |
|---|---|
| `particle-ending` | 助詞で終わる文。先に述語で言い切った倒置は除く |
| `clipped-question` | 「か」を落とした丁寧な問い |
| `quiz-question` | 1人がもう1人に、専門家へ出題するように用語の意味を尋ねる文 |
| `casual-contraction` | 丁寧な司会なら崩さずに言う縮約 |
| `written-style` | 書き言葉の文末と連用中止 |
| `unhedged-source` | 出典を挙げて、その主張を事実として言い切る文 |
| `vague-source` | 出典をあいまいにしか言わない文 |
| `not-in-source` | `--source`を渡した時、材料に無い数字、英字の語、カタカナの語。`readings`に在るカタカナの語は、書いた形で材料を探す |

台本全体の値を`note`の行でも出し、`note`は終わり方を変えません。
値は、発話の長さの中央値と変動係数、10字以下の発話の割合、相づちで始まる発話の数、「ね」「よ」で終わる文の割合、同じ文末が3回以上続く所、50字を超える文です。
丁寧なラジオの話し方での閾値を測った資料がまだ無いので、`note`は型にしていません。
agentは値を読み、一本調子に聞こえる台本を書き直します。

型が無ければ0、1つでも在れば1で終わります。
台本か出典のfileを読めない時は、理由を書いた`error:`の行を1行出して2で終わります。

## 決まりの出どころ

`references/speaking.md`の決まりには、それぞれ出典を付けています。
主な出典は、相づち、終助詞、言いさし、共同発話についての日本語の会話の研究、国立国語研究所のコーパス、ニュースの文末と耳で聞く原稿についてのNHKの研究、文化庁の『公用文作成の考え方』、ラジオの掛け合いの書き方についてのNPRの手引きです。
発話の長さ、短い受けの発話、相づちを測る考え方は、[llm-jp/kaburi-tts](https://github.com/llm-jp/kaburi-tts) (Apache-2.0) の`scripts/check_spontaneity.py`に倣いました。
codeは写しておらず、雑談に合わせた閾値も使っていません。

## 動かす物と繋ぐ先

`speaking.py`は、台本と渡した出典のfileを読み、標準出力と標準エラーに書きます。
ほかのプログラムを動かさず、どこにも繋ぎません。
別の読み手はsubagentか新しいsessionで、`references/review.md`と台本だけを受け取ります。

## 残す物

何も残しません。台本は指定のfileか返答に置きます。
