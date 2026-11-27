# Mechanism Explainer

仕組みや研究の説明資料を作ります。
材料が1種類で問いが5個以下の資料は1つの頁に収め、問いが6個以上か材料が2種類以上の資料は全体像の頁と話題ごとの頁に分け、横の目次から開きます。
各節は1つの問いに、1文の答えと、`####`の見出しで分けた頁と、流れか仕組みを追ってdragonの記法で描いた図1枚で答えます。
同じ頁をPDFにも書き出します。

[English](README.md) · 日本語

図が何枚も続いて間に短い文しか無い資料や、文が図より先に来る資料では、読み手が追う筋を見失います。
このプラグインは、読み手が持つ問いを先に並べ、問いごとの頁を見出しで分け、流れか仕組みを追う図を1枚ずつdragonに描かせます。
2枚目の図は、問いに答えるのに要る時だけ足します。
値の一覧やコマンドは、図にせず表とコードで書きます。
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

頁の頭に仕組みの全体像の図が出て、横の目次に全ての話題と問いが番号を付けずに短い名前で並びます。
頁の中の問いの番号は、`2-1`のように話題ごとに振ります。
話題が2つ以上の時は、頁の上にタブを置かず、全体像の頁と話題ごとの頁に分かれ、話題の中は問いごとの頁になります。
横の目次は、話題と、その問いと、開いた頁の見出しを3段で並べ、どの段も矢印で開け閉めできます。
どの頁も終わりに前と次の頁へのリンクが付きます。
話題は、仕組みの説明を先に、実行の記録と引くための資料を後に並べます。
全体像の図の箱を押すと、その部分を説明する話題の頁が開き、話題の頁の頭には、全体像のうちその話題の箱だけに色を残した図と、問いごとの1文の答えが並びます。
問いの下には1文の答えが先に来て、`####`の見出しが頁を分け、図の前に見る所の1文が、後に図が示すことの短い段落が続きます。
知らないかもしれない語には下線が付き、押すと意味の札が開きます。確かめの問いは押すと答えが開きます。
PDFは既定でA3の紙に書き出します。
全体像と全ての話題が順に紙に出て、図は段ごとに並び、箱の札は図の下に開きます。
既定では、作業しているフォルダの`explainer/<name>/`に置きます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| Node.js 20以降と`npx` | いつも。エージェントは`npx -y @cardenelabs/dragon@0.89.0`を実行し、初回にnpmがdragonをキャッシュへ取ってきます |
| `python3` | PDFを書き出す時。macOSに入っている物で動きます |
| Chrome、Chromium、Edge、Brave、またはPlaywrightのheadless shell | PDFを書き出す時。無くてもHTMLはでき、どのブラウザでも印刷できます |
| dragonのプラグイン | 任意。`dragon`のスキルが入っていると、エージェントはその`plan`、`page`、`notation`、`cheatsheet`の形に沿って図を立てて書きます |
| japanese-writingのプラグイン | 任意。日本語の頁では、エージェントがその書き方の規範`japanese-writing/rules`に照らして文を確かめます |
| `musubi`コマンド | 任意。入っていると、エージェントはdragonの形とjapanese-writingの書き方の規範を読む前に`musubi check`を実行します |

## 読む物と実行する物と送る物

[仕組み](docs/how-it-works.ja.md)に、手順と、頁が持つ物と、どこで何が動くかを書いています。
要点は次のとおりです。

- 渡した材料を読みます。題材、メモ、Markdownのファイル、プロジェクトのファイルです。ファイルに書かれたことは材料として扱い、指示としては扱いません
- dragonを手元のマシンで`npx`経由で実行します。初回にnpmがnpmのレジストリからdragonのパッケージを取ってきます。材料は送りません
- PDFは、ブラウザをheadlessの形と使い捨てのプロファイルで動かして書き出し、終わったらプロファイルを消します。自分のブラウザのプロファイルは使いません
- Markdown、HTML、ネットに繋がずに開けるHTML、PDFを`explainer/<name>/`か指定のフォルダに書き、ほかには何も残しません
- `skills/mechanism-explainer/musubi.json`は、このスキルが`dragon`のスキルの`plan`、`page`、`notation`、`cheatsheet`の形に従うことを、musubiで`"optional": true`の任意の従い先として宣言します。エージェントはdragonのプラグインが入っている時だけそれを読みます。japanese-writingの書き方の規範`japanese-writing/rules`も、`"when": {"languages": ["ja"]}`で日本語だけの任意の従い先として宣言し、japanese-writingが入っている時に日本語の頁でだけ読みます

## ライセンス

[MIT](LICENSE)
