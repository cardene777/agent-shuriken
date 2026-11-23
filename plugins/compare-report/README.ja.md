# Compare Report

選ぶ時の候補をエージェントに調べさせ、人に渡せる比較のレポートをHTMLとPDFで作ります。

[English](README.md) · 日本語

![4つの静的サイトジェネレーターを比べたレポートの、事実の表を載せたPDFの表紙、ビルド時間の棒グラフが2つ載ったPDFのページ、暗い色の画面で候補の一覧の横にAstroの詳細を出したところ](assets/screenshot.png)

ツールの比較を頼むと、エージェントは根拠の無い点数を付けたり、提供元の主張と第三者の計測を混ぜたり、分からない所を推測で埋めたりしがちです。
このプラグインは、代わりに従う1つのやり方をエージェントに渡します。
まず候補と評価の観点をあなたと決め、エージェントはすべての主張に出典と日付を付けて集め、レポートのすべての点数に判定の根拠を添えます。
公開されていない数値は推測せず、「非公開」と書きます。

```
Webを検索して候補を挙げる          エージェント
  ↓
候補と評価の観点を決める            あなた
  ↓
候補ごとに調べる                    エージェント
  ↓
レポートを書いて確かめる            エージェント
  ↓
読んで直してほしい所を伝える        あなた
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install compare-report@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add compare-report@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install compare-report@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/compare-report/skills/compare-report   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「ドキュメントのサイト向けに主な静的サイトジェネレーターを比べて」のように比較を頼むと始まります。
呼び出して始めることもできます。Claude Codeでは`/compare-report:compare-report`の後に題材を続けて実行し、Codexでは`$`を入力して**Compare Report**を選びます。
GitHub Copilot CLIでは依頼の中に`/compare-report`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントがWebを検索し、10〜15の候補を示します。比べる物を選び、漏れている物があれば足します。表紙に載せる作者名も尋ね、答えを次のレポートで最初の案にします
2. エージェントが、性能、費用、リスクのような評価の観点を5〜8個示します。そのままにするか、直します
3. エージェントが候補ごとに調べます。Claude Codeでは並べて調べます
4. エージェントがレポートを書き、すべての点数に根拠があることと、ネットから何も読み込まないことを確かめます
5. エージェントがレポートをPDFにして開き、2つのファイルの場所を伝えます。PDFの目次には各節が始まるページを載せ、表紙を除く各ページの下にページ番号を入れます。直してほしい所を伝えると、両方を直します

レポートには、候補と観点と出典の数、調べた日、作者名を載せた事実の表を持つ表紙、上位3つの推奨を含む要約、候補ごとのカード、表とグラフを含む観点ごとの節、リスク、推奨を含む採点表、番号付きの出典が入ります。
レポートは、あなたが書いた言語で書かれます。
画面では、候補の一覧の横に、押した候補の詳細が出ます。詳細には、その候補の観点ごとの点数と判定の根拠と、リスクがまとまります。スマートフォンでは一覧と詳細を切り替えて見せ、PDFではカードを順に載せます。
表紙の右上には2つの切り替えがあります。言語の切り替え(English / 日本語)は、事実の表の見出しや候補の一覧のボタンのような枠の言葉を変え、レポートの本文は書いた言語のまま残します。明るい / 暗いは色を変えます。
選ぶまでは、色はシステムの設定に従います。PDFは切り替えを除き、いつも明るい色で印刷します。

## 自分の色と書体

design-formatsのプラグインが入っていれば、レポートはpage-designの形式の意匠のfileから色と書体を取ります。
エージェントは次の2つのうち先に在るfileを読みます。

| 順 | file | 使い道 |
|---|---|---|
| 1 | repoの根の`.design-theme.json` | 1つのプロジェクトの見た目 |
| 2 | `~/.design-theme.json` | 自分が作る全てのレポートの見た目 |

当てるのは色と書体 (`light`と`dark`、`font.sans`と`font.mono`) だけで、文字の大きさと幅と角の丸みはレポートのままです。
線と縞と副の文字の薄い色と濃い色は意匠の色から混ぜて作るので、どの背景にも馴染み、PDFは意匠の明るい色で印刷します。
表紙と状態の色と種類の札は、自分の色のままです。

```json
{
  "light": { "bg": "#fafaf7", "surface": "#ffffff", "ink": "#111111", "sub": "#444444", "line": "#dddddd", "accent": "#0b6e4f", "accent-ink": "#ffffff", "accent-soft": "#e3f2ec", "label": "#f2f2f2" },
  "dark": { "bg": "#101312", "surface": "#181c1a", "ink": "#eeeeee", "sub": "#b0b8b4", "line": "#2c3330", "accent": "#5fd0a5", "accent-ink": "#0b1410", "accent-soft": "#1b3a2f", "label": "#1f2523" },
  "font": { "sans": "\"Inter\", sans-serif", "mono": "\"JetBrains Mono\", monospace" }
}
```

鍵と型はpage-designの`formats/theme.md`が持ちます。
design-formatsか意匠のfileが無ければ、レポートは自分の色と書体のままです。

## 必要な物

| ツール | 必要な時 |
|---|---|
| エージェントのWeb検索 | 常に。Claude CodeにもCodexにもあります。ほかのエージェントでは、Web検索が使える状態かを確かめてください |
| `python3` | レポートを確かめる時。macOSに最初から入っている物で動きます |
| Chrome、Chromium、Edge、Braveのどれか | PDFにする時。無い時はHTMLを渡すので、どのブラウザーからでも印刷できます |
| `design-formats`のプラグイン | 任意です。`page-design`のスキルが入っていれば、エージェントはその形式に沿ってレポートを書き、意匠のfileを当て、棒グラフをdragonで描き、仕上がったページにその`verify`を回します |
| Node.js | 任意です。`page-design`と一緒に使います。`npx`がグラフを描くdragonを取ってきます。無い時は、レポートはCSSの棒グラフのままです |
| `musubi`のコマンド | 任意です。入っていれば、エージェントは`page-design`の形式を読む前に`musubi check`を回します |

## 読む物と実行する物と送る物

レポートに入る物、確かめる物、ファイルを置く場所は、すべて[仕組み](docs/how-it-works.ja.md)に載せています。
要点は次のとおりです。

- Webの検索には、題材と、候補と提供元の名前だけを使います。会話やファイルにあるプロジェクト名、会社名、人の名前、社内のURL、コードは検索に入れません
- 公開されているWebページを読み、書かれている内容はデータとして扱い、指示としては扱いません
- レポートは`~/.local/share/compare-report/<題材>-<日付>/`に置き、`COMPARE_REPORT_HOME`を設定した時はそちらに置きます。あなただけが読めます
- 表紙に載せると伝えた作者名か、載せないと選んだことを、同じフォルダーの`author.txt`に、あなただけが読める形で残します。名前を`git config`やシステムから取ることはありません
- PDFは、ブラウザーを画面に出さずに動かして作ります。使い捨てのプロフィールを使い、終わったら消すので、あなたのブラウザーのプロフィールは使いません
- `page-design`が入っていれば、棒グラフを`npx -y @cardenelabs/dragon@<version>`で描きます。`npx`はdragonをnpmのレジストリーからnpmのキャッシュに取ってきます。`dragon embed`がグラフをSVGとしてレポートに描き込むので、レポートはほかのファイルを読みません
- レポートを開いても、ネットからは何も読み込みません。切り替えで選んだ物は、ブラウザーがローカルストレージに`compare-report-theme`と`compare-report-lang`の名前で覚え、どこへも送りません
- `skills/compare-report/musubi.json`は、`compare-report`が`design-formats`のプラグインにある`page-design`の形式`structure`と`look`、ページの型`report`、`verify`に、`"optional": true`の任意の準拠で従うことをmusubiで宣言します。エージェントは`page-design`が入っている時だけこれらを読み、仕上がったレポートに`page-design`の`verify`を回します。入っていなければ、スキルのひな形で書きます。ほかのプラグインからはこれ以外を読みません

## ライセンス

[MIT](LICENSE)
