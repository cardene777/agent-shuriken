# 仕組み

[English](how-it-works.md) · 日本語

このページは、Slidesの2つの技が読む物、動かす物、つなぐ先、書く物と、構成の確かめが当てる全ての決まりと、書き出しが動かす全ての命令を説明します。
構成とスライドの頁はagentが書きます。`skills/slide-builder/scripts/`と`skills/slide-forge/scripts/`のscriptは、構成を確かめ、編集の道具を足し、fileを書き出します。

## 技の中のfile

| file | 持つもの |
|---|---|
| `slide-builder/SKILL.md` | 構成を書く手順。足りないことを聞き、構成を確かめてもらい、スライドごとに書き、確かめて渡します |
| `slide-builder/references/deck-format.md` | 構成の書式。スライドの塊、スライドの種類、表、言葉で書く図 |
| `slide-builder/references/readability-rules.md` | 読みやすさの決まりと、確かめが知らせる一般のコードの語 |
| `slide-builder/examples/slides-outline.md` | 確かめを通る10枚の構成の例 |
| `slide-builder/scripts/validate.py` | 構成の確かめ |
| `slide-forge/SKILL.md` | 短い発表の資料の3つの段階。見た目を決め、直し、書き出します |
| `slide-forge/references/` | 4つのテイスト、編集の頁、PowerPointの決まり、書き出しの命令 |
| `slide-forge/scripts/inject_edit_mode.py` | スライドの頁に編集の道具を足します |
| `slide-forge/scripts/edit-text.json` | 道具が出す全ての文言を、英語と日本語で持ちます |
| `slide-forge/scripts/build_pptx.py` | `content.json`からPowerPointのfileを作ります |
| `slide-forge/scripts/export_html_final.py` | 道具を除いた公開の頁を書きます |
| `slide-forge/scripts/export_pdf.py` | PlaywrightのChromiumで公開の頁をPDFにします |
| `slide-forge/scripts/export_all.sh` | 資料のフォルダから3つの書き出しを回します |
| `*/agents/openai.yaml` | Codexが各技をどう見せてどう始めるか |
| `*/tests/` | 技が書くことと、scriptがすることのテスト |

## 構成の確かめ

`validate.py`は構成を1つ読み、Pythonの標準ライブラリだけを使います。

```
S=<folder that contains SKILL.md>/scripts; python3 "$S/validate.py" [--ban WORD]... slides-outline.md
```

| 決まり | 結果 |
|---|---|
| どのスライドも`## Slide N / M ─ <title>`で始まる | スライドが1枚も無い時は誤り |
| スライドの番号が1から順に並び、どのスライドも同じ総数を書く | 誤り |
| どのスライドも`type=`を持つ`> meta:`の行を持つ | 誤り |
| 中身のスライドは`### Takeaway`を持つ | 誤り |
| `### Figure`の節は、1つ以上の項目を持つ`Elements:`の一覧を持つ | 誤り |
| 図の要素は5つまで | 警告 |
| コードと引用の外に一般のコードの語 (function、method、class、struct、variable、API、endpoint、SDK、query、repository) が無い | 警告 |
| コードと引用の外に`--ban`で渡した語が無い | 警告 |

問題はどれも`slide[3/10]`のようにスライドから始まります。
誤りが無い時は`[VALIDATION OK]`の行を1つ出して終わり方0で終わり、誤りが在る時は1で、引数が誤りかfileが無い時は2で終わります。警告は終わり方を変えません。

## 編集の頁

`inject_edit_mode.py`は静的なスライドの頁に3つを足し、それぞれを`<!-- slide-forge-inject-start -->`と`<!-- slide-forge-inject-end -->`で挟みます。`<head>`の終わりに道具の辞書とscriptを、`<body>`の終わりに道具を足します。
頁が`</head>`か`</body>`を持たない時は何も書きません。

道具は頁を開いた時は英語で、**日本語**で日本語に切り替わります。
`data-key`を持つ全ての要素の文をブラウザのlocalStorageに保ち、`content.json`に書き出し、写真を差し替え、直した中身を元に戻します。

| localStorageの鍵 | 持つもの |
|---|---|
| `slide-forge:<page path>` | その頁で直した中身 |
| `slide-forge:lang` | 道具の言語。`en`か`ja`です |

どちらもあなたのブラウザに残ります。頁は何も送りません。

## 書き出し

`export_all.sh <資料のフォルダ>`は、資料のフォルダの`content.json`と`edit-mode.html`を読み、フォルダの名前を付けた3つのfileを同じフォルダに書きます。

| file | 命令 |
|---|---|
| `<deck>.pptx` | `uv run --with python-pptx --with Pillow --no-project python3 build_pptx.py content.json <deck>.pptx --theme <tone>` |
| `<deck>.html` | `uv run --no-project python3 export_html_final.py edit-mode.html <deck>.html` |
| `<deck>.pdf` | `uv run --with playwright --no-project python3 export_pdf.py <deck>.html <deck>.pdf` |

`--no-project`は、uvがあなたのプロジェクトのPythonの設定を読まないようにします。

| 状況 | 起きること |
|---|---|
| `PATH`に`uv`が無い | 何も書きません。uvの入れ方を出して終わり方1で終わります |
| PlaywrightのChromiumが無い | PowerPointとHTMLのfileを書きます。PDFは飛ばし、`uv run --with playwright --no-project python3 -m playwright install chromium`を出して終わり方0で終わります |
| `edit-mode.html`が無い | PowerPointのfileを書き、HTMLとPDFは飛ばします |
| PDFがほかの理由で失敗した | PowerPointとHTMLのfileを書き、終わり方1で終わります |

`build_pptx.py`は、題と副題と写真と箇条書きと下端の文を、4つのテイストのどれかで1280 x 720の1枚に置きます。写真はPillowで中央の正方形に切り、東アジアとラテンと複雑な文字の書体をHiragino Sansに固定します。

## 動かす物とつなぐ先

- `python3`は`validate.py`と`inject_edit_mode.py`と、単独で動かす時の`export_html_final.py`を動かします
- `uv`は書き出しのscriptを動かします。初めての時と、置き場に無い時に、`python-pptx`と`Pillow`とPlaywrightをPython Package Indexから取りに行き、伝えるのは包みの名前だけです。包みはuvの置き場に保ち、あなたのPythonには何も入れません
- PlaywrightのChromiumは、入っている時だけ、PDFを書くために手元の公開の頁だけを開きます。pluginはブラウザを取りに行きません
- ほかには何も動かさず、どこにも何も送りません

## 書く物と残す物

- 構成は、あなたかagentが保存した場所に置かれます。名指したフォルダの`slides-outline.md`です
- 資料のfileは資料のフォルダに置かれ、既定はプロジェクトの`decks/<deck-name>/`です。見本、`edit-mode.html`、`content.json`、書き出したfileです
- `build_pptx.py`は切った写真を一時のfileに書き、スライドに足した直後に消します
- 編集の頁は、直した中身と道具の言語を、元に戻すまでブラウザのlocalStorageに保ちます
- pluginは自分のものを何も残しません。取りに行った包みは、uvの置き場を消すまで残ります
