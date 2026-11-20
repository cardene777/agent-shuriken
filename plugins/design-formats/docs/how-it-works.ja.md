# 仕組み

[English](how-it-works.md) · 日本語

このページは、Design Formatsが何を読み、何を動かし、何を保存するかと、`verify`が確かめる全ての決まりを説明します。
頁とドキュメントは従うスキルのagentが書き、`skills/page-design/scripts/`のscriptは確かめるだけです。

## 技のfile

| file | 持つもの |
|---|---|
| `SKILL.md` | スキルが出す中身と、それで頁とドキュメントを書く手順と、`verify`の回し方 |
| `agents/openai.yaml` | Codexがスキルを見せて起動する形 |
| `musubi.json` | musubiで出す中身です。`structure`、`look`、`report`、`sheet`、`document`、`choice`、`verify`をそれぞれバージョン1.0.0で出します |
| `formats/structure.md` | 説明の構造 |
| `formats/look.md` | 見た目の決まり。最後に`verify`が確かめる決まりの表を持ちます |
| `templates/report.html` | レポートの頁の型 |
| `templates/sheet.html` | 承認の頁の型 |
| `templates/document.html` | 説明の頁の型 |
| `templates/choice.html` | 案を選ぶ頁の型 |
| `scripts/page-design.py` | 頁とドキュメントを確かめる`verify` |
| `tests/test-page-design.sh` | `verify`、書式、雛形、宣言、pluginのテスト |

## スキルがpage-designに従う形

従うスキルは、`page-design/look`や`page-design/report`のように従う中身を自分の`musubi.json`に書き、バージョンの範囲と、最後に確かめた中身の指紋を持ちます。
その`SKILL.md`は、`page-design`を名前で開き、中身ごとに名指したfileを読むことと、`page-design`が入っていない時にどうするかを書きます。
agentは頁の型の雛形を写し、`DATA`と`TEXT`の言葉を書き換え、頁に`verify`を回します。

| file | どのplugin | 持つもの |
|---|---|---|
| `formats/structure.md`、`formats/look.md` | design-formats | 説明の構造と見た目の決まり |
| `templates/<type>.html` | design-formats | 頁の型ごとの枠と見本のデータ |
| `musubi.json` | 従うスキル | 従う中身ごとのバージョンの範囲と指紋 |

書式か雛形かscriptが変わると指紋が変わり、従うスキルを確かめ直して指紋を書き直すまで、`musubi check`がそのスキルを拒みます。

## 雛形の作り

雛形はそれぞれ1つのHTMLのfileで、styleとscriptを中に持ちます。
人に見せる文字列は全て`en`と`ja`を持つ1つの辞書`TEXT`にあり、レポートの中身は1つのobject`DATA`にあります。
ヘッダーは英語と日本語のボタン(`data-lang`)と、明るい色と暗い色のボタン(`data-theme-choice`)を持ちます。
頁は英語とOSの明暗で始まり、選んだ言語と明暗をブラウザのlocal storageの`page-design-lang`と`page-design-theme`に残します。
承認の頁と案を選ぶ頁は、チャットに貼り返す文を`copyText()`で、決まった英語の語と項目のkeyだけから作ります。どちらの言語でも、scriptが同じ形で読めます。
ブラウザがコピーを断った時は、頁が文を選び、キーボードでコピーするよう案内します。

## verifyが確かめる決まり

`verify <file>...`は、`.html`と`.htm`のfileを頁として、`.md`のfileをドキュメントとして読みます。

| 決まり | 見つける物 | 頁 | ドキュメント |
|---|---|---|---|
| `heading-punctuation` | コロンか、日本語の読点か句点を持つ見出し、題、名前にtitleかheadingを含む辞書の値 | 見る | 見る |
| `facts-in-one-line` | 数を持つ3つ以上の事実を、読点かカンマで1行につないだ物 | 見る | 見る |
| `label-colon` | ラベルと値をコロンか`=`でつないだ物 | 見る | 見る |
| `small-text` | 12pxか0.75remより小さい文字 | 見る | 見ない |
| `missing-lang` | `lang`の無い`<html>` | 見る | 見ない |
| `missing-language-switch` | `data-lang="en"`と`data-lang="ja"`のボタンが無い | 見る | 見ない |
| `missing-theme-switch` | `data-theme-choice="light"`と`data-theme-choice="dark"`のボタンが無い | 見る | 見ない |
| `missing-dictionary` | `en`と`ja`を持つ辞書が無い | 見る | 見ない |
| `missing-dark-colors` | `prefers-color-scheme: dark`の色が無い | 見る | 見ない |
| `missing-reduced-motion` | `prefers-reduced-motion`の無い動き | 見る | 見ない |
| `external-file` | ほかのサイトから読むscript、style、画像、frame、font | 見る | 見ない |

頁では、`script`、`style`、`code`、`pre`、`textarea`、`svg`の中の文字を見せる文として読みません。scriptの中の文字列は、markupとcodeを持たない時だけ、題と事実について読みます。
ドキュメントでは、囲んだcode、表、引用、HTMLのcommentを飛ばし、行を確かめる前にinline codeを外します。

問題は1つにつき`<file>:<line>: <rule>: <how to fix>`の1行で、最後にまとめの1行を出し、1で終わります。
何も問題が無い時は`page-design: ok (<n> files)`を出し、0で終わります。
fileを渡さない時、fileを読めない時、HTMLでもMarkdownでもない時は、理由を標準エラーに出して2で終わります。

## 何を動かし、どこに繋ぐか

`verify`は渡したfileを読み、標準出力と標準エラーに出します。
出すのはfileの名前、行の番号、決まりの名前、直し方だけで、頁の文は出しません。
ほかのプログラムを動かさず、どこにも繋ぎません。
雛形はほかのサイトから何も読みません。

## 何を保存するか

`verify`は何も保存しません。
雛形で作った頁は、開いたPCのブラウザのlocal storageに、選んだ言語と明暗を残します。
