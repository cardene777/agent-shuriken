# 仕組み

[English](how-it-works.md) · 日本語

このページは、Design Formatsが何を読み、何を動かし、何を保存するかと、`verify`が確かめる全ての決まりを説明します。
頁とドキュメントは従うスキルのagentが書き、`skills/page-design/scripts/`のscriptは確かめるだけです。

## スキルのfile

| file | 持つもの |
|---|---|
| `SKILL.md` | スキルが出す中身と、それで頁とドキュメントを書く手順と、`verify`の回し方 |
| `agents/openai.yaml` | Codexがスキルを見せて起動する形 |
| `musubi.json` | musubiで出す中身です。`structure`と`theme`と4つの規則のfileをバージョン1.0.0で、`look`、`report`、`sheet`、`document`、`choice`、`verify`をバージョン2.1.0で出します |
| `formats/structure.md` | 説明の構造 |
| `formats/look.md` | 見た目の決まり。最後に`verify`が確かめる決まりの表を持ちます |
| `formats/theme.md` | 利用者の意匠のfileの置き場と、鍵と型と、雛形ごとの既定の値 |
| `formats/patterns/details.md` | 選んだ物の詳細を出す場所の規則と出所 |
| `formats/patterns/lists-and-tables.md` | 一覧と表の行の見せ方の規則と出所 |
| `formats/patterns/input-and-confirmation.md` | 選択と入力の受け取り方と確かめ方の規則と出所 |
| `formats/patterns/states-and-notices.md` | 状態と知らせの出し方の規則と出所 |
| `formats/patterns/sources.md` | 規則のfileが引く出所ごとの頁、種類、読んだ日、短い引用 |
| `templates/report.html` | レポートの頁の型 |
| `templates/sheet.html` | 承認の頁の型 |
| `templates/document.html` | 説明の頁の型 |
| `templates/choice.html` | 案を選ぶ頁の型 |
| `scripts/page-design.py` | 頁とドキュメントを確かめる`verify`と、利用者の意匠のfileを頁に書く`theme` |
| `tests/test-page-design.sh` | `verify`、書式、雛形、宣言、pluginのテスト |
| `tests/test-followers.sh` | このリポジトリのレポートを書くスキルが`page-design`に従うかのテスト。リポジトリを取り出した写しから回します |

## スキルがpage-designに従う形

従うスキルは、`page-design/look`や`page-design/report`のように従う中身を自分の`musubi.json`に書き、バージョンの範囲と、最後に確かめた中身の指紋を持ちます。
その`SKILL.md`は、`page-design`を名前で開き、中身ごとに名指したfileを読むことと、`page-design`が入っていない時にどうするかを書きます。
agentは頁の型の雛形を写し、`DATA`と`TEXT`の言葉を書き換え、頁に`verify`を回します。

| file | どのplugin | 持つもの |
|---|---|---|
| `formats/structure.md`、`formats/look.md`、`formats/patterns/<topic>.md` | design-formats | 説明の構造、見た目の決まり、画面の型の規則 |
| `templates/<type>.html` | design-formats | 頁の型ごとの枠と見本のデータ |
| `musubi.json` | 従うスキル | 従う中身ごとのバージョンの範囲と指紋 |

書式か雛形かscriptが変わると指紋が変わり、従うスキルを確かめ直して指紋を書き直すまで、`musubi check`がそのスキルを拒みます。

このリポジトリの10のスキルが`page-design`に従います。どれも確かめた時のメジャーバージョンの範囲 (`structure`は`^1.0.0`、ほかの中身は`^2.0.0`) と`"optional": true`を持つ任意の準拠なので、各pluginは単独でも入れて動かせます。

| スキル | plugin | 従う中身 |
|---|---|---|
| `techdebt` | techdebt | `structure`、`look`、`report`、`verify` |
| `compare-report` | compare-report | `structure`、`look`、`report`、`verify` |
| `machine-cleanup` | machine-cleanup | `structure`、`look`、`sheet`、`verify` |
| `account-cleanup` | account-cleanup | `structure`、`look`、`sheet`、`verify` |
| `diagram-explainer` | diagram-explainer | `structure`、`look`、`document`、`verify` |
| `repo-progress` | repo-progress | `structure` |
| `secure-dotfile` | secure-dotfile | `structure` |
| `init-project` | init-project | `structure` |
| `release-check` | evm-dev | `structure` |
| `portman` | portman | `structure` |

HTMLの頁を持つ5つのスキルは、自分の雛形を持ち続け、仕上げた頁に`verify`を回します。pluginのscriptは自分のスキルのフォルダーの外を読まないためです。
チャットで報告する5つのスキルは、`structure`の順で報告を書きます。結果を先に書き、したことと飛ばしたことを理由とともに書き、測れなかった値は測れなかったと書き、使う人の手順を最後に書きます。
design-formatsが入っていない時、`musubi check`は警告を出してこれらの準拠を飛ばし、各スキルは`page-design`無しで動きます。
`tests/test-followers.sh`は、宣言、各`SKILL.md`の行、雛形、design-formatsが有る時と無い時の`musubi check`を、このリポジトリを取り出した写しから確かめます。

## 雛形の作り

雛形はそれぞれ1つのHTMLのfileで、styleとscriptを中に持ちます。
人に見せる文字列は全て`en`と`ja`を持つ1つの辞書`TEXT`にあり、レポートの中身は1つのobject`DATA`にあります。
ヘッダーは英語と日本語のボタン(`data-lang`)と、明るい色と暗い色のボタン(`data-theme-choice`)を持ちます。
頁は英語とOSの明暗で始まり、選んだ言語と明暗をブラウザのlocal storageの`page-design-lang`と`page-design-theme`に残します。
承認の頁と案を選ぶ頁は、チャットに貼り返す文を`copyText()`で、決まった英語の語と項目のkeyだけから作ります。どちらの言語でも、scriptが同じ形で読めます。
ブラウザがコピーを断った時は、頁が文を選び、キーボードでコピーするよう案内します。
色と書体と文字の大きさと行の高さと頁の幅と3つの角の丸みは`:root`の型で持ち、暗い色は2つの暗い色の塊の型で持ちます。
`page-design.py theme <page>`は、repoの根の`.design-theme.json`か、無ければ`~/.design-theme.json`の値で、これらの型を書き換えます。鍵の一覧は`formats/theme.md`が持ちます。

レポートと説明の頁は、図を止めて置くdragonの塊`<pre class="dragon" data-still>`で持ち、言語ごとに1つの塊を`<div data-figure-lang="en">`か`<div data-figure-lang="ja">`の中に置きます。
styleの規則が頁の言語でない方の塊を隠すので、言語を切り替えても描き直しません。
雛形はjsDelivrからdragonを読む行を持つので、雛形をそのまま開いても塊が図になります。
`npx -y @cardenelabs/dragon@<version> embed <page> --out <page>`は、止めて置く塊を全て最後の段のSVGに描き、動く塊が残らないので、dragonを読む行を消します。
説明の頁は`DATA`から本文を組むので、図は隠した`#figures`の要素で待ち、本文の中で塊が名指す所へ移ります。

## verifyが確かめる決まり

`verify <file>...`は、`.html`と`.htm`のfileを頁として、`.md`のfileをドキュメントとして読みます。
`verify --source <file>...`は、雛形のような`dragon embed`の前の頁を確かめます。止めて置くdragonの塊とdragonを読む行を通し、`data-still`の無い塊を断ります。

| 決まり | 見つける物 | 頁 | ドキュメント |
|---|---|---|---|
| `heading-punctuation` | コロンか、日本語の読点か句点を持つ見出し、題、名前にtitleかheadingを含む辞書の値。`title: { en, ja }`のように言語ごとに持つ値も1つずつ見ます | 見る | 見る |
| `facts-in-one-line` | 数を持つ3つ以上の事実を、読点かカンマで1行につないだ物。頁のスクリプトの文字列も、長さによらず、エスケープを読んだ文で見る | 見る | 見る |
| `label-colon` | ラベルと値をコロンか`=`でつないだ物 | 見る | 見る |
| `small-text` | 12pxか0.75remより小さい文字 | 見る | 見ない |
| `missing-lang` | `lang`の無い`<html>` | 見る | 見ない |
| `missing-language-switch` | `data-lang="en"`と`data-lang="ja"`のボタンが無い | 見る | 見ない |
| `missing-theme-switch` | `data-theme-choice="light"`と`data-theme-choice="dark"`のボタンが無い | 見る | 見ない |
| `missing-dictionary` | `en`と`ja`を持つ辞書が無い | 見る | 見ない |
| `missing-dark-colors` | `prefers-color-scheme: dark`の色が無い | 見る | 見ない |
| `missing-reduced-motion` | `prefers-reduced-motion`の無い動き | 見る | 見ない |
| `external-file` | ほかのサイトから読むscript、style、画像、frame、font。`--source`ではdragonを読む行を通します | 見る | 見ない |
| `figure-not-embedded` | `dragon embed`で描いていないdragonの塊が残る頁 | 見る | 見ない |
| `figure-not-still` | `--source`で、`data-still`の無いdragonの塊 | 見る | 見ない |
| `facts-not-table` | `facts`の名の付いた要素が`<table>`でないこと (scriptが文字で組む物を含む)、または付帯の情報の行の見出しが`<th scope="row">`でないこと | 見る | 見ない |
| `sentence-per-line` | 閉じ括弧の前でない日本語の「。」の後に、同じ行で文が続くこと | 見る | 見る |
| `list-detail-width` | `.split`の一覧の列が、`1fr`や`minmax(0, 1.1fr)`のように頁の幅につれて伸び、一定の幅に留まらないこと | 見る | 見ない |

頁では、`script`、`style`、`code`、`pre`、`textarea`、`svg`の中の文字を見せる文として読まず、描いた図の`svg`の中の文字の大きさも測りません。scriptの中の文字列は、markupとcodeを持たない時だけ、題と事実について読みます。
ドキュメントでは、囲んだcode、表、引用、HTMLのcommentを飛ばし、行を確かめる前にinline codeを外します。

問題は1つにつき`<file>:<line>: <rule>: <how to fix>`の1行で、最後にまとめの1行を出し、1で終わります。
何も問題が無い時は`page-design: ok (<n> files)`を出し、0で終わります。
fileを渡さない時、fileを読めない時、HTMLでもMarkdownでもない時は、理由を標準エラーに出して2で終わります。

## 動かす物と繋ぐ先

`verify`は渡したfileを読み、標準出力と標準エラーに出します。
出すのはfileの名前、行の番号、決まりの名前、直し方だけで、頁の文は出しません。
ほかのプログラムを動かさず、どこにも繋ぎません。
図を描く時は、エージェントが`npx -y @cardenelabs/dragon@<version> check`と`embed`を動かします。最初の1回に、npmの置き場から`@cardenelabs/dragon`をnpmのキャッシュへ取りに行きます。PC全体には何も入れず、頁の文はどこにも送りません。
`dragon embed`の前の雛形は、dragonを読む行でjsDelivrから読みます。`dragon embed`の後の頁は、ほかのサイトから何も読みません。
`theme`は頁と意匠のfileを読み、頁だけを書きます。ほかのプログラムを動かさず、どこにも繋ぎません。

## 何を保存するか

`verify`と`theme`は何も保存しません。`theme`は意匠のfileを書き換えません。
雛形で作った頁は、開いたPCのブラウザのlocal storageに、選んだ言語と明暗を残します。
