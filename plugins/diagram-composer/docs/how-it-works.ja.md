# 仕組み

[English](how-it-works.md) · 日本語

この頁は、Diagram Composerが何を読み、何を動かし、何を保存するかと、`validate_diagram_geometry.py`が当てる全ての決まりを説明します。
図を設計し、あなたのデックの道具でスライドを描くのはagentです。`skills/diagram-composer/scripts/`のscriptは配置を確かめるだけです。

## 技のfile

| file | 中身 |
|---|---|
| `SKILL.md` | agentが従う手順。見立てを決め、線ごとに意味を持たせ、配置の記述を書いて確かめ、スライド全体を描いて見ます |
| `agents/openai.yaml` | Codexが技をどう見せ、どう始めるか |
| `scripts/validate_diagram_geometry.py` | 配置の記述の確かめ |
| `tests/test-diagram-composer.sh` | `SKILL.md`が書くことと、確かめが当てる全ての決まりのテスト |

## 配置の記述

配置の記述 (geometry manifest) は、`theme`と`metaphor`と4つの一覧を持つJSONのobjectです。
図を何枚も持つデックは、スライドごとに1つのobjectを最上位の`diagrams`の一覧に入れ、それぞれを別の座標の面として確かめます。

| キー | 中身 |
|---|---|
| `theme` | スライドのテーマの名前 |
| `metaphor` | 図が使う見立て。例えば`handoff`や`vault` |
| `containers` | 各箱。`id`、`x`、`y`、`width`、`height`、`padding` |
| `elements` | 箱の中に見える各要素。`id`、属す`container`、`x`、`y`、`width`、`height` |
| `connectors` | (`x1`, `y1`) から (`x2`, `y2`) への各線と、その線がそこに在る理由を名指す`lane` |
| `labels` | 各文字の矩形。`id`、`x`、`y`、`width`、`height`と、名指す`connector` |

## 確かめが断るもの

| 決まり | 出す文 |
|---|---|
| テーマが在る | `diagram has no theme` |
| 見立てが在る | `diagram has no visual metaphor` |
| 全ての線に`lane`が在る | `connector <id> has no semantic lane` |
| 全ての要素が知っている囲いに属す | `element <id> has no known container` |
| 全ての要素が囲いの余白の内側に在る | `element <id> violates container <id> padding` |
| 全てのラベルが全ての線から12px以上離れる | `label <id> collides with connector <id>` |

線は無限に伸びる直線ではなく線分として扱うため、ラベルの手前で終わる線はラベルに当たりません。
12pxの間隔はラベルの矩形の周りで測るため、12px離れた線は断り、13px離れた線は通します。
各問題は`slide <n>:`で始まります。`n`は`diagrams`の中の図の位置で、図が1つだけの時は`slide 1`です。

何も問題が無い時は`OK:`の1行を出して終わり方0で終わり、在る時は`Diagram geometry rejected:`と問題ごとの1行を出して終わり方1で終わります。

## 動かす物と繋ぐ先

`validate_diagram_geometry.py`は渡した配置の記述を読み、標準出力と標準エラーに書きます。
ほかのプログラムは動かさず、どこにも繋ぎません。
スライドは、デックが既に使っている道具でagentが描きます。

## 何を保存するか

何も保存しません。配置の記述は、あなたかagentが保存した場所に置かれます。
