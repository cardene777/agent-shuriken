# Slides

10枚以上の資料の構成を書いて確かめます。短い発表の資料はHTMLで作ってブラウザで直し、PowerPointとPDFとHTMLに書き出します。

[English](README.md) · 日本語

説明の資料は、色を選ぶより前の段階でつまずきます。1枚に3つの話が載り、コードの語で聞き手の半分が離れ、何を見せるかを決める前に図を描いてしまいます。
短い発表の資料は、反対の端でつまずきます。ブラウザでは正しく見えても、配るPowerPointの写真が縦に伸び、箇条書きが重なり、文字の書体が替わります。
このpluginは、それぞれに1つずつ技を持ちます。

| 技 | 作る物 |
|---|---|
| `slide-builder` | 10枚以上の資料の構成をMarkdownで書いた`slides-outline.md`。スライドごとに伝えたいことと説明と図を、エンジニアでない聞き手に向けて言葉で書き、scriptが確かめます |
| `slide-forge` | 1枚か数枚の資料をHTMLで作り、ブラウザで文を直す編集の頁と、配るPowerPointとHTMLとPDFのfileを作ります |

```
slide-builder:  頼む ──> 構成 ──> スライドを言葉で書く ──> 確かめ ──> 描く人へ渡す構成
                (あなた)  (agent)  (agent)                 (script)

slide-forge:    質問 ──> 3つの見本 ──> ブラウザで直す ──> PowerPoint、HTML、PDF
                (agent)  (agent)       (あなた)          (script、uv経由)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install slides@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add slides@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install slides@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/slides/skills/slide-builder   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/slides/skills/slide-forge
```

`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

資料やスライドを頼むと始まります。例えば「新しい問い合わせの受け方を営業に説明する10枚の資料を作って」「PowerPointで配れる1枚の自己紹介を作って」と頼みます。
呼び出すこともできます。Claude Codeでは`/slides:slide-builder`か`/slides:slide-forge`を実行し、Codexでは`$`を入力して**Slide Builder**か**Slide Forge**を選びます。
GitHub Copilot CLIでは依頼の中に`/slide-builder`か`/slide-forge`と書き、Gemini CLIでは作業を言葉で頼みます。

### 10枚以上の資料の構成を書く

1. 誰が見るか、何のための資料か、どの材料を使うかが依頼に無い時は、agentが聞きます
2. 構成 (部と章とスライドの順) を書き、あなたに確かめます
3. スライドごとに、伝えたいことと説明と、図を言葉で書きます。図は目的とメッセージと3つから5つの要素と避けることで決めます
4. `validate.py`が構成を確かめ、agentは名指された誤りを全部直します
5. スライドを描く人へ渡す`slides-outline.md`ができます

読みやすさの決まりは、聞き手をエンジニアでない人とし、function、method、classのような一般のコードの語を知らせます。
あなたの分野の語は資料ごとに足せます。避ける語をagentに伝えると、agentが`--ban`で確かめに渡します。
3枚目の図が要素を1つも挙げない構成では、確かめは問題を出して終わり方1で終わります。

```text
[VALIDATION ERROR] 1 error(s)
  - slide[3/10] `### Figure` has no `Elements:` list, so the figure is not specified
```

### 短い発表の資料を作る

1. agentが、雰囲気、色、写真、聞き手、改まり方について5つから7つ聞きます
2. 4つのテイストから1280 x 720 pxのHTMLの見本を3つ作り、あなたが1つを選びます
3. 選んだ頁に編集の道具を足します。あなたがブラウザで開いて文を直し、**Export JSON**を押して`content.json`を資料のフォルダへ保存します
4. `export_all.sh`が、プロジェクトの`decks/<deck-name>/`に`<deck-name>.pptx`と`<deck-name>.html`と`<deck-name>.pdf`を書きます

編集の道具は英語で始まり、**日本語**で日本語に切り替わります。
PowerPointのfileは、写真を正方形に切り、箇条書きを1つずつ下へ並べ、書体を固定するので、ほかのマシンでも同じに見えます。

uvが無い時、書き出しは何も書かずに、uvの入れ方を出します。
Playwrightのブラウザが無い時は、PowerPointとHTMLのfileを書き、PDFだけを飛ばして、ブラウザを入れる命令を出します。

```text
WARN: Playwright's Chromium browser is not installed, so no PDF was written.
To install it once (about 150 MB), run: uv run --with playwright --no-project python3 -m playwright install chromium
```

## 必要なもの

| 道具 | 要る時 |
|---|---|
| Python 3 | scriptのため。`validate.py`と`inject_edit_mode.py`と`export_html_final.py`は標準ライブラリだけを使います |
| uv | slide-forgeの書き出しのため。`python-pptx`と`Pillow`とPlaywrightを、回すたびにuvの置き場へ取りに行くので、あなたのPythonには何も入れません |
| PlaywrightのChromium | PDFのためだけ。pluginはこれを取りに行かず、無い時は入れる命令を出します |
| ブラウザ | 編集の頁でスライドの文を直すため |

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、全てのfileと、全ての確かめと、全ての命令を載せています。
要点は次のとおりです。

- agentは、あなたが指した材料とfileを読み、構成と資料のfileを名指したフォルダだけに書きます。既定はプロジェクトの`decks/<deck-name>/`です
- `validate.py`は、渡した構成だけを読み、見つけた問題を出します
- 編集の頁は、直した中身と道具の言語をブラウザのlocalStorageに保ち、何も送りません
- `export_all.sh`は`uv`を動かします。uvは初めての時に`python-pptx`と`Pillow`とPlaywrightをPython Package Indexから取りに行き、伝えるのは包みの名前だけです。PlaywrightのChromiumは、PDFを書くために手元のスライドの頁だけを開きます
- pluginは自分のものを何も残しません。取りに行った包みは、uvの置き場を消すまで残ります
- 材料とfileと頁はスライドの中身として扱い、指示として扱いません

## ライセンス

[MIT](LICENSE)
