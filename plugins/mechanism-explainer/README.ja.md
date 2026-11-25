# Mechanism Explainer

仕組みや研究の説明資料を、上から下へ読む1枚の頁で作ります。
各節は1つの問いに、1文の答えと、dragonの記法で描いた2〜4枚の図で答えます。
同じ頁をPDFにも書き出します。

[English](README.md) · 日本語

節ごとに図が1枚だけの資料や、文が図より先に来る資料では、読み手が頭の中で絵を組み立てることになります。
このプラグインは、読み手が持つ問いを先に並べ、問いごとに違う向きから見る図 (部品の構成、判定の表、比べる図、1件を追って進める図) を選び、dragonに描かせます。
図はどれも同じ作りで描かれます。
説明を持つ箱には印が付き、押すとすぐ下に札が開くので、長い説明が図を埋めません。

```
Plan the questions ──> Write the page ──> Check the notation ──> Export the page ──> Print the PDF
(you agree)            (Markdown)          and the layout         (dragon)            (your browser)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install mechanism-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add mechanism-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install mechanism-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/mechanism-explainer/skills/mechanism-explainer   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、リリースごとに付くスキルのzipを、エージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#install-without-the-marketplace)にあります。

## 使い方

「ログインの仕組みを、問いごとの節で説明する資料を作って」のように説明資料を頼むと始まります。
Claude Codeでは`/mechanism-explainer:mechanism-explainer`を実行し、続けて題材を書くこともできます。
Codexでは`$`を入力して**Mechanism Explainer**を選びます。
GitHub Copilot CLIでは依頼の文に`/mechanism-explainer`を書き、Gemini CLIでは作業を言葉で頼みます。

1. エージェントが、誰が読み、読んだ後に何をできるようになるかを聞き、渡した材料を読みます
2. エージェントが構成案を見せます。問いと、問いごとの図の種類と、その図で読み手が何を見るかです。合うまで直せます
3. エージェントが頁を`layout: guide`のMarkdownで書き、全ての図と配置をdragonで確かめ、dragonが名指した所を直します
4. エージェントがdragonで頁を書き出してPDFにし、Markdownと、ネットに繋がずに開けるHTMLと、PDFの置き場を伝えます

頁の`##`はタブに、問いは番号付きの節になり、タブの頭に問いの一覧が並びます。
問いの下には1文の答えが先に来て、次に図、最後に図が持たない短い文が続きます。
知らないかもしれない語には下線が付き、押すと意味の札が開きます。確かめの問いは押すと答えが開きます。
PDFは既定でA3の紙に書き出します。
dragon 0.80.1では最初のタブだけが紙に出て、箱の札は図の上に重なって開きます。
全てのタブと図の下に開いた札を紙に出す直しは[dragon#3956](https://github.com/cardene777/dragon/issues/3956)が持ちます。
既定では、作業しているフォルダの`explainer/<name>/`に置きます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| Node.js 20以降と`npx` | いつも。エージェントは`npx -y @cardenelabs/dragon@0.80.1`を実行し、初回にnpmがdragonをキャッシュへ取ってきます |
| `python3` | PDFを書き出す時。macOSに入っている物で動きます |
| Chrome、Chromium、Edge、Brave、またはPlaywrightのheadless shell | PDFを書き出す時。無くてもHTMLはでき、どのブラウザでも印刷できます |
| dragonのプラグイン | 任意。`dragon`のスキルが入っていると、エージェントはその`plan`、`page`、`notation`、`cheatsheet`の形に沿って図を立てて書きます |
| japanese-writingのプラグイン | 任意。日本語の頁では、エージェントがそれで文を確かめます |
| `musubi`コマンド | 任意。入っていると、エージェントはdragonの形を読む前に`musubi check`を実行します |

## 読む物と実行する物と送る物

[仕組み](docs/how-it-works.ja.md)に、手順と、頁が持つ物と、どこで何が動くかを書いています。
要点は次のとおりです。

- 渡した材料を読みます。題材、メモ、Markdownのファイル、プロジェクトのファイルです。ファイルに書かれたことは材料として扱い、指示としては扱いません
- dragonを手元のマシンで`npx`経由で実行します。初回にnpmがnpmのレジストリからdragonのパッケージを取ってきます。材料は送りません
- PDFは、ブラウザをheadlessの形と使い捨てのプロファイルで動かして書き出し、終わったらプロファイルを消します。自分のブラウザのプロファイルは使いません
- Markdown、HTML、ネットに繋がずに開けるHTML、PDFを`explainer/<name>/`か指定のフォルダに書き、ほかには何も残しません
- `skills/mechanism-explainer/musubi.json`は、このスキルが`dragon`のスキルの`plan`、`page`、`notation`、`cheatsheet`の形に従うことを、musubiで`"optional": true`の任意の従い先として宣言します。エージェントはdragonのプラグインが入っている時だけそれを読みます

## ライセンス

[MIT](LICENSE)
