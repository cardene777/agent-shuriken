# Design Formats

ドキュメントとレポートの説明の構造と見た目を、それを書くスキルのために持ちます。2つの書式、4つのHTMLの頁の雛形、頁とドキュメントを確かめるscriptを持ちます。

[English](README.md) · 日本語

複数のスキルが頁とドキュメントを書くと、各スキルが色と見出しと切り替えを別々に持ち、頁どうしが少しずつずれていきます。
このpluginはそれを1つにまとめます。
`page-design`のスキルが、説明の構造、見た目の決まり、4つの頁の型、scriptで見られる決まりを頁とドキュメントで確かめる`verify`を持ちます。
図はdragonで描きます。見た目の決まりが情報の種類ごとに使う図を決め、`dragon embed`が図をSVGにして頁に入れます。
レポート、承認の頁、説明の頁、案を選ぶ頁、設計書を書くスキルは、musubiでこのスキルに従います。musubiは`musubi.json`に書く宣言で、従う中身のバージョンと指紋を固定します。

```
A skill that writes pages ──> page-design: read the formats ──> Copy a template ──> Write the page ──> dragon embed ──> page-design: verify
(its own content)             (structure.md, look.md)           (report, sheet,     and its figures    (draws the        (scripts/page-design.py)
                                                                document, choice)   (agent)            figures as SVG)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install design-formats@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add design-formats@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install design-formats@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/design-formats/skills/page-design   # Gemini CLI
```

`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

頁かドキュメントを書くスキルが`page-design`を名前で開き、書式を読み、頁の型の雛形を写して、`verify`を回します。
自分で使う時は、Claude Codeで`/design-formats:page-design`を実行するか、Codexで`$`を打って**Page Design**を選び、頁を頼むか、確かめる頁とドキュメントを伝えます。
GitHub Copilot CLIでは依頼の中に`/page-design`と書き、Gemini CLIでは作業を説明します。

| 中身 | file | 持つもの |
|---|---|---|
| `structure` | `formats/structure.md` | 説明の構造です。結論を先に書くこと、全体像を詳細より先に置くこと、用語集を1つにすること、手順に実例を添えること、レポートの並びを持ちます |
| `look` | `formats/look.md` | 見た目の決まりです。コロンの無い見出し、表で見せる付帯の情報、文字の大きさ、一覧の横の詳細、情報の種類ごとに使う図、拡大、動き、言語と明暗の切り替え、色、外のfileを読まない頁を持ちます |
| `report` | `templates/report.html` | レポートの頁です。付帯の情報、結果の数、横棒とドーナツの図、押した行の詳細を横に出す一覧を持ちます |
| `sheet` | `templates/sheet.html` | 承認の頁です。選ぶ項目、項目の詳細、チャットに貼り返す文を持ちます |
| `document` | `templates/document.html` | 説明の頁です。手順の帯で見せる全体像、横に目次を置いた節、手順、用語集を持ちます |
| `choice` | `templates/choice.html` | 案を選ぶ頁です。依頼、今の形、横に並べた案、貼り返す文を持ちます |
| `verify` | `scripts/page-design.py` | 頁とドキュメントが、scriptで見られる決まりを守るかを確かめます |

題が「パン屋: 週の売り上げ」の頁では、`verify`が行と直し方を出して1で終わります。

```text
report.html:42: heading-punctuation: take the colon and any Japanese comma or period out of the heading; keep the name as the title and put the detail on the line under it
page-design: 1 problem; fix each line named above and run verify again
```

## 必要なもの

| 道具 | 要る時 |
|---|---|
| Python 3 | `verify`のため。標準ライブラリだけを使います |
| ブラウザ | 雛形で作った頁を開くため |
| musubiの命令 | 任意です。入っている時は、従うスキルが書式を読む前に`musubi check`を回します |
| Node.jsと`npx` | 図を描くため。`npx -y @cardenelabs/dragon@<version>`が最初の1回にdragonを取りに行きます |
| dragonのスキル | 任意です。入っている時は、page-designがその記法と図の種類ごとの書き方を読みます |

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、スキルの全てのfileと、`verify`が確かめる全ての決まりを載せています。
要点は次のとおりです。

- `verify`は渡した頁とドキュメントだけを読み、決まりの名前と行の番号と直し方を出します。頁の文は出しません
- ほかのプログラムを動かさず、どこにも繋がず、何も保存しません
- 図を描く時は、エージェントが`npx -y @cardenelabs/dragon@<version> check`と`embed`を動かします。最初の1回に、npmの置き場から`@cardenelabs/dragon`をnpmのキャッシュへ取りに行きます。PC全体には何も入れず、頁の文はどこにも送りません
- `dragon embed`の前の雛形は、jsDelivrからdragonを読むscriptの行を1つ持ちます。`dragon embed`が図を描いてその行を消すので、頁はほかのfileを読みません。styleとscriptと図を頁の中に持ち、選んだ言語と明暗だけをブラウザの保存領域に残します
- 頁とドキュメントの文はデータとして扱い、指示として扱いません

## ライセンス

[MIT](LICENSE)
