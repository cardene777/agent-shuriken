# 仕組み

[English](how-it-works.md) · 日本語

この頁は、Diagram Stylesが読む物、動かす物、書く物、渡す物と、2つのスキルの全てのfileと、scriptが確かめる画風の一覧を説明します。
図を設計して描くのはagentです。`skills/article-diagram-styles/scripts/`のscriptは記録と一覧を確かめるだけです。

## スキルのfile

| file | 持つ物 |
|---|---|
| `article-diagram-styles/SKILL.md` | 読者の疑問から記事の図を設計し、構図を選び、画風を当て、描き、確かめる手順 |
| `article-diagram-styles/agents/openai.yaml` | Codexでの見せ方と始め方 |
| `article-diagram-styles/musubi.json` | 渡す中身の`style4`、`figure-request`、`style-catalog`。`style4`は版1.0.0、`figure-request`と`style-catalog`は版1.2.0 |
| `article-diagram-styles/references/content-first.md` | 内容の要約と、完成図を確かめた記録の形 |
| `article-diagram-styles/references/deterministic-technical-diagrams.md` | 図の文字と接続の記録と確かめ方 |
| `article-diagram-styles/references/style-families.md` | 8つの組に分けた32の既定の画風と、画風の選び方 |
| `article-diagram-styles/references/structures.md` | 4つの組に分けた16の既定の構図と、構図の選び方と比べ方 |
| `article-diagram-styles/references/pen-technical.md`、`handdraft.md`、`newsprint.md` | 3つの既定の画風の詳しい仕様 |
| `article-diagram-styles/references/style4.md` | style4の決まり。`style4`として渡す |
| `article-diagram-styles/references/figure-request.md` | 図を頼む形。`figure-request`として渡す |
| `article-diagram-styles/references/style-catalog.md` | 一覧の形。`style-catalog`として渡す |
| `article-diagram-styles/scripts/diagram_sample_catalog.py` | 既定の画風と既定の構図と一覧を確かめ、使える画風と構図を並べ、1つの画風を自分の見本と一緒に出すか、1つの構図を出す |
| `article-diagram-styles/scripts/validate_content_brief.py` | 内容の要約を記事と照らす |
| `article-diagram-styles/scripts/validate_figure_spec.py` | 図の仕様と、それが名指す構図を確かめる |
| `article-diagram-styles/scripts/validate_anchor_candidate.py` | 完成図を確かめた記録を確かめる |
| `article-diagram-styles/scripts/validate_visual_contract.py` | 見た目の約束と、それに対する図の仕様を確かめる |
| `article-diagram-styles/scripts/validate_composition_ledger.py` | 記事の図の構図の台帳と、各図の構図と、構図の比べを確かめる |
| `article-diagram-styles/scripts/newsprint_finish.py` | HTMLかSVGで描く図のための、同梱の書体の置き場とインクの処理 |
| `article-diagram-styles/data/built-in-styles.json` | 32の既定の画風。どれも文で定義し、画像を持たない |
| `article-diagram-styles/data/built-in-structures.json` | 16の既定の構図。どれも文で定義し、画像を持たない |
| `article-diagram-styles/data/fonts/KaiseiDecol-Bold.ttf`、`OFL.txt` | 書体Kaisei Decol Boldとその利用許諾 |
| `article-diagram-styles/tests/` | script、頁、pluginの検査。仕込みの画像は一時のフォルダーに描く |
| `tech-book-figure/SKILL.md` | 本の図を設計し、style4で描く手順 |
| `tech-book-figure/agents/openai.yaml` | Codexでの見せ方と始め方 |
| `tech-book-figure/musubi.json` | `article-diagram-styles/style4`への従いと、その範囲と指紋 |
| `tech-book-figure/tests/` | 本のスキルの手順とmusubiの従いの検査 |

`skills/`の下には画像のfileを置きません。

## 画風の一覧

このpluginは32の既定の画風をそれぞれ文で定義して持つので、`~/.styles/`が無くても`article-diagram-styles`は描きます。
自分の一覧は、既定の画風の横に画風を足し、同じ名前の既定の画風を置き換え、`status`を`retired`にした既定の画風を使わない物にします。
`tech-book-figure`は今もstyle4の見本が要ります。一覧も`~/.styles/`に置きます。
スキルとscriptは、一覧`style-catalog.json`と見本の画像を`~/.styles/`から読みます。
`diagram_sample_catalog.py`と、確かめた記録と見た目の約束と図の仕様と台帳を確かめるscriptは、`--styles <dir>`を渡した時だけ別のフォルダーを読みます。
一覧は任意で`structures`も持てます。画風と同じ決まりで、構図を足し、置き換え、止めます。

```text
~/.styles/
  style-catalog.json                 The catalog, version 2
  diagram-style-samples/<style>/     Sample images as first collected, such as style4/
  style-catalog/<family>/<profile>/  The same images sorted by family and finish profile
```

一覧の画像のpathは、どれも見本のフォルダーから見た相対の形です。
`diagram_sample_catalog.py --validate`は、一覧が通ると読んだフォルダーを出して終了0で終わり、通らないと問題を1つずつ名指して終了1で終わります。
`~/.styles/style-catalog.json`が無い時は、既定の画風だけを確かめて終了0で終わり、一覧が無いことを伝えます。

| 断る物 | 理由 |
|---|---|
| `--styles <dir>`で渡した、`style-catalog.json`の無いフォルダー | 名指したフォルダーは一覧を持ちます。一覧が無くてよいのは`~/.styles/`だけです |
| `2`でない`schema_version` | 版1の一覧は変換しません |
| 一覧か仕上がりの`resources` | 版1はそこにスキルの中のfileを書いていて、見本のフォルダーからは見つけられません |
| `path`か`original_paths`が名指す画像のうち、無いかSHA-256が違う物 | 一覧が登録した見本ではありません |
| 合わない`counts`の数 | `source_registrations`は元のpathの数、`unique_images`は異なるSHA-256の数を数えます |
| フォルダーの下に在って一覧が名指さない画像のfile | 全ての見本を登録します |
| 既定にも一覧にも無い画風の画像 | どの見本も、使える画風のどれかに属します |
| `shows`のような文の欄を欠く`structures`の構図 | 使える構図はどれも文で定義します。確かめは構図と欄を名指します |

確かめで断った一覧は使いません。その代わりに既定の画風へ切り替えることもしません。

`tech-book-figure`はstyle4の見本を`~/.styles/diagram-style-samples/style4/`から読み、2点より少ない時は描く前に止まります。

## 構図

このpluginは16の既定の構図を持ちます。どの構図も、示す関係、部品、読む順、向く題材と向かない題材を文で定義しています。
構図は図が持つ部品と読む順を決めます。構図は画風と別に選び、どの構図もどの画風でも描けます。
`diagram_sample_catalog.py --structures`が使える構図を並べ、`--show-structure <structure>`が1つの構図を出します。

| 組 | 構図 |
|---|---|
| `flow-and-order` | `process-flow`、`message-sequence`、`timeline`、`cycle` |
| `structure-and-containment` | `layers`、`tree`、`nesting`、`network` |
| `comparison` | `side-by-side`、`before-after`、`two-axis-matrix`、`correspondence-table` |
| `state-and-change` | `state-machine`、`decision-branch`、`quantity-trend`、`journey-map` |

スキルは、利用者か図の頼みが構図を名指さない時、読者の疑問から図ごとに構図を選び、その名前を図の仕様と`composition-ledger.json`の図の行の`structure`に記録します。
`validate_composition_ledger.py`は、使える構図を持たない図と、構図が台帳の行と違う図の仕様を断ります。

| 台帳の`mode` | 持つ物 |
|---|---|
| `article` | 記事の図。図ごとに違う点を説明します |
| `style-comparison` | 頼まれた時に、同じ中身と配置をいくつかの画風で描いた図 |
| `structure-comparison` | `comparison_request`で頼まれた時に、同じ中身を2つ以上の違う構図で描いた図。数を言われない時は3つ描きます。確かめは数に上限を置かず、図が1つの時と同じ構図を2度描いた時を断ります |

## 図の描き方

スキルは先に内容を決め、内容の要約、図の仕様、描く指示を書いてから描きます。
描く時は、描く指示と見本の画像を、スキルを動かしている道具の画像生成へ渡します。図1枚ごとに1回渡します。選んだ画風の見本が無い時は、描く指示だけを渡します。
こうして描いた図の仕様は`rendering_mode: generated`を持ち、HTMLかSVGのソースから描いた図は`rendering_mode: deterministic`を持ちます。

| agent | スキルがすること |
|---|---|
| 画像生成を持つ | 図を描き、PNGと本文幅の版を保存し、確かめます |
| 画像生成を持たない | 内容の要約、図の仕様、描く指示を書いて止まり、画像生成を持つ道具で続けるよう伝えます |
| 保存した設計を続ける | 保存したfileを読み、描く段から始めます |
| 別の確かめ役を立てられない | 記事の抜粋と疑問と2つの画像だけを読む別の段で確かめ、確かめが独立でなかったと伝えます |

スキルは、画像生成の代わりにHTMLやSVGで完成図を描くことも、別のagentや道具に描かせることもしません。
`tech-book-figure`は、画像生成がstyle4の見本を参照の画像として受けられない時も止まります。

## スキルがarticle-diagram-stylesに従う形

従うスキルは、従う中身 (`article-diagram-styles/style4`など) を自分の`musubi.json`に、版の範囲と、最後に確かめた中身の指紋と一緒に書きます。
その`SKILL.md`は、`article-diagram-styles`を名前で開き、その中身に名指されたfileを読むと書きます。
指紋は`article-diagram-styles/SKILL.md`と中身のfileを含むので、どちらかが変わると`musubi check`は従うスキルを断ります。従うスキルを確かめ直して指紋を更新するまで断ります。

| 従うスキル | 中身 | 従い方 |
|---|---|---|
| `tech-book-figure` | `style4` | 必須。範囲`^1.0.0` |
| ほかのrepoの記事のスキル | `figure-request` | それぞれが決めます |

## 書く物

スキルは、図、内容の要約、図の仕様、描く指示、確かめた記録を、名指したフォルダだけに書きます。図の依頼が名指したフォルダーにも書きます。
scriptは何も書かず、標準出力と標準エラーに出すだけです。
`~/.styles/`の下には何も書きません。そこのfileは利用者が持ちます。

## 動かす物と繋ぐ先

scriptはPythonの標準ライブラリだけを使い、ほかの命令を動かさず、どこにも繋ぎません。
画像生成はagent自身の物です。指示と画像の扱いは、そのagentに渡すほかの画像と同じです。
記事と本と一覧の文はデータとして扱い、指示として読みません。

## 残す物

pluginは回と回の間に何も残しません。
図ごとの記録は名指したフォルダーに残ります。
