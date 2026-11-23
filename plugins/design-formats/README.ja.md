# Design Formats

ドキュメントとレポートの説明の構造と見た目を、それを書くスキルのために持ちます。2つの書式、出所の付いた規則を持つ4つのfile、4つのHTMLの頁の雛形、頁とドキュメントを確かめるscriptを持ちます。

[English](README.md) · 日本語

複数のスキルが頁とドキュメントを書くと、各スキルが色と見出しと切り替えを別々に持ち、頁どうしが少しずつずれていきます。
このpluginはそれを1つにまとめます。
`page-design`のスキルが、説明の構造、見た目の決まり、どの画面の型が合うかと理由を持つ4つの規則のfile、4つの頁の型、scriptで見られる決まりを頁とドキュメントで確かめる`verify`を持ちます。
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
| `look` | `formats/look.md` | 見た目の決まりです。コロンの無い見出し、表で見せる付帯の情報、日本語の「。」ごとの改行、文字の大きさ、情報の種類ごとに使う図、拡大、動き、言語と明暗の切り替え、色、外のfileを読まない頁を持ちます |
| `details` | `formats/patterns/details.md` | 選んだ物の詳細を出す場所です。一定の幅の一覧の横、狭い画面での1枚ずつの表示、全幅の画面、短い作業だけに使うダイアログを持ちます |
| `lists-and-tables` | `formats/patterns/lists-and-tables.md` | 一覧と表の行の見せ方です。カードか表、見出しの欄を持つ表に置く付帯の情報、頁送り、タブ、並べ替え、行ごとの数を持ちます |
| `input-and-confirmation` | `formats/patterns/input-and-confirmation.md` | 選択と入力の受け取り方と確かめ方です。行を押して選ぶこと、ボタン、エラー、消す操作、チャットに貼り返す文を持ちます |
| `states-and-notices` | `formats/patterns/states-and-notices.md` | 読み込み中、空、エラー、保存済みの状態と、帯や一時の知らせの出し方を持ちます |
| `report` | `templates/report.html` | レポートの頁です。付帯の情報、結果の数、横棒とドーナツの図、一定の幅の一覧と、残りの幅に押した行の詳細を出す欄を持ちます |
| `sheet` | `templates/sheet.html` | 承認の頁です。選ぶ項目、項目の詳細、チャットに貼り返す文を持ちます |
| `document` | `templates/document.html` | 説明の頁です。手順の帯で見せる全体像、横に目次を置いた節、手順、用語集を持ちます |
| `choice` | `templates/choice.html` | 案を選ぶ頁です。依頼、今の形、横に並べた案、貼り返す文を持ちます |
| `theme` | `formats/theme.md` | 意匠のfileの鍵です。色、書体、文字の大きさ、頁の幅、角の丸みと、雛形ごとの既定の値を持ちます |
| `verify` | `scripts/page-design.py` | 頁とドキュメントが、scriptで見られる決まりを守るかを確かめます。意匠のfileを頁に書く`theme`も持ちます |

4つの規則のfileは、規則ごとにデザインシステム、調査と記事、公的な手引き、アクセシビリティの出所を番号で示し、`formats/patterns/sources.md`が出所ごとの頁と読んだ日と短い引用を持ちます。
出所どうしが食い違う所は、どちらを採ったかと理由を各fileが書きます。

題が「パン屋: 週の売り上げ」の頁では、`verify`が行と直し方を出して1で終わります。

```text
report.html:42: heading-punctuation: take the colon and any Japanese comma or period out of the heading; keep the name as the title and put the detail on the line under it
page-design: 1 problem; fix each line named above and run verify again
```

## 自分の意匠

雛形から作る頁は、色と書体と文字の大きさと頁の幅と角の丸みを意匠のfileから取ります。作る頁が全て同じ見た目に揃います。
スキルは頁を書いた後に`page-design.py theme <page>`を動かし、次の2つのうち先に在るfileを読みます。

| 順 | file | 使い道 |
|---|---|---|
| 1 | repoの根の`.design-theme.json` | 1つのプロジェクトの見た目 |
| 2 | `~/.design-theme.json` | 自分が作る全ての頁の見た目 |

全ての鍵を持つ意匠のfileは次の形です。
どの鍵も省けて、省いた鍵は雛形の値のまま残ります。

```json
{
  "light": {
    "bg": "#fafaf7", "surface": "#ffffff", "ink": "#111111", "sub": "#444444", "line": "#dddddd",
    "accent": "#0b6e4f", "accent-ink": "#ffffff", "accent-soft": "#e3f2ec", "bar": "#eeeeee", "label": "#f2f2f2"
  },
  "dark": {
    "bg": "#101312", "surface": "#181c1a", "ink": "#eeeeee", "sub": "#b0b8b4", "line": "#2c3330",
    "accent": "#5fd0a5", "accent-ink": "#0b1410", "accent-soft": "#1b3a2f", "bar": "#232a27", "label": "#1f2523"
  },
  "font": { "sans": "\"Inter\", sans-serif", "mono": "\"JetBrains Mono\", monospace", "size": 16, "line-height": 1.75 },
  "space": { "page-width": 1100, "radius-small": 4, "radius": 6, "radius-large": 8 }
}
```

鍵ごとの型と雛形ごとの既定の値は`formats/theme.md`が持ち、`page-design.py theme --defaults <page>`は頁の値をJSONで出します。
意匠のfileが無ければ、頁は雛形の見た目のままです。
自分の大きさを持つ頁を作るスキルは一部の鍵だけを取ります。色と書体だけなら`page-design.py theme --keys light,dark,font.sans,font.mono <page>`です。
知らない鍵か正しくない値を持つ意匠のfileは、鍵を名指して断り、頁を変えません。

## このスキルに従うスキル

このリポジトリの10のスキルが、musubiで`page-design`に従います。どれもバージョンの範囲`^1.0.0`と`"optional": true`を持つ任意の準拠です。
各スキルは`page-design`が入っている時はそれを読み、入っていない時は単独で動きます。

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

HTMLの頁を書く5つのスキルは自分の雛形を持ち続け、仕上げた頁に`verify`を回します。
チャットで報告する5つのスキルは、`structure`の順で報告を書きます。

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
- `theme`は頁と意匠のfileを読み、頁だけを書きます。意匠のfileは書き換えません
- 図を描く時は、エージェントが`npx -y @cardenelabs/dragon@<version> check`と`embed`を動かします。最初の1回に、npmの置き場から`@cardenelabs/dragon`をnpmのキャッシュへ取りに行きます。PC全体には何も入れず、頁の文はどこにも送りません
- `dragon embed`の前の雛形は、jsDelivrからdragonを読むscriptの行を1つ持ちます。`dragon embed`が図を描いてその行を消すので、頁はほかのfileを読みません。styleとscriptと図を頁の中に持ち、選んだ言語と明暗だけをブラウザの保存領域に残します
- 頁とドキュメントの文はデータとして扱い、指示として扱いません

## ライセンス

[MIT](LICENSE)
