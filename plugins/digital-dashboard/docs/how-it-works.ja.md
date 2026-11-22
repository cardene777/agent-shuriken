# 仕組み

[English](how-it-works.md) · 日本語

プラグインは技`digital-dashboard`を1つだけ持ちます。
エージェントは`skills/digital-dashboard/SKILL.md`に従い、`skills/digital-dashboard/scripts/`の3つのスクリプトを動かします。どれもPython 3の標準ライブラリだけを使います。

## 技のファイル

| ファイル | 中身 |
|---|---|
| `SKILL.md` | 画面の判定、取得、添える物の一覧、頼みの文、結果の確かめの手順 |
| `scripts/screen_kind.py` | 判定の1段目 |
| `scripts/fetch_official.py` | 公式資料を取る命令 |
| `scripts/attachments.py` | 添えるファイルの一覧 |
| `references/official-files.json` | 公式資料の一覧。置く所、公開先、SHA-256、添える時 |
| `references/*.md` | ガイドブックから英語で書いた技の決まり。設計の原則、グラフの選び方、色、数、時間軸、テンプレートの書式、グラフの部品の一覧、完成形、すべき事とすべきでない事 |
| `references/conventions/<domain>.md` | 金融、医療、SaaS、行政のダッシュボードの慣行 |

## 判定

`screen_kind.py <spec.md>...`は、画面の仕様書ごとに項目定義の見出し (日本語では`## 項目定義`、英語では`## Item definitions`) の下の表を読み、種別の列を見出し (`種別`か`Kind`) で探します。見出しが無い時は2列目を使います。
欄が`グラフ`、`chart`、`graph`のどれかを含めばグラフに、`数値`、`サマリー`、`KPI`、`合計`、`推移`、`number`、`summary`、`total`、`trend`のどれかを含めば集計値に数えます。
日本語の語は`scripts/screen_kind.py`が並べています。
どちらも1件以上在る画面を`candidate`とし、ほかは`other`とします。ほかの見出しの下の表は数えません。

その後エージェントが、複数の指標から全体の状況を読み、異常に気付くか次の行動を決めることが主な目的の候補を`dashboard`に残します。決まらない時は利用者に尋ねます。

## 取得

`fetch_official.py [--dest <dir>] [--manifest <path>]`は`references/official-files.json`を読みます。一覧は配列で、各行が`path`、`url`、`sha256`を持ち、添える物の一覧が使う`title`、`attach`、`when`、`palette`も持ちます。

| 段 | 起きること |
|---|---|
| ファイルが置き場に在り、SHA-256が合う | 触りません。取らず、番号も変更の時刻も変わりません |
| ファイルが無いか、違う | 置き場の隣の一時ファイルに取ります。待つのは120秒までです |
| 取った物が合う | 一時ファイルをあなただけが読める形にして置き場へ移します |
| 取った物が違う | 一時ファイルを消し、置き場に在った写しも消して、拒んだと出します |

置き場は`~/.local/share/digital-dashboard/`か`$DIGITAL_DASHBOARD_HOME`か`--dest`です。スクリプトが作るフォルダーはあなただけが読めます。
ファイルごとに1行 (`kept`、`fetched`、`rejected`、`failed`) とまとめの行を出します。全部が合えば0、取れないか拒んだ物が在れば1、一覧を読めなければ2で終わります。
取るのは`https://`の宛先だけで、`--manifest`で渡した手元の写しの`file://`も読みます。

一覧は24のファイル、約37MBです。

| ファイル | 公開先 |
|---|---|
| `guidebook.pdf`、`guidebook-alt.txt`、`manual.pdf`、`worksheet.pptx`、`toolkit.pptx`、`checklist.xlsx`、`summary-format.docx` | `www.digital.go.jp`のガイドブックの頁 |
| `templates/<Color>_1_0_0.zip`、Power BIのテンプレート7つ | `www.digital.go.jp`のガイドブックの頁 |
| `themes/CustomTheme<Color>Default_2026.json`、配色のテーマ7つ | GitHubのデジタル庁の`policy-dashboard-assets`のrepoの、決めたcommit |
| `map/ja_prefecture_area.json`、`map/ja_municipality_area.json`、`map/ja_municipality_area_with_pref_boundary.json` | 同じrepoと同じcommit |

## 宣言

repoは`.claude/design-sources.json`に自分の資料を書けます。

```json
{
  "schema_version": 3,
  "dashboard_attach_globs": ["catalog/dashboard/guide.md"],
  "dashboard_convention_template": "catalog/dashboard/conventions/{domain}.md",
  "dashboard_on_demand_globs": [
    "catalog/dashboard/numbers.md",
    {"glob": "catalog/dashboard/manual.md", "when": "When the steps of the official tool are needed"}
  ]
}
```

| 版 | 読み方 |
|---|---|
| 1 | 資料の欄を持たないので、技の一覧を使います |
| 2 | `dashboard_attach_globs`が資料を名指します。ほかの2つの欄は任意で、随時の要素はpathです |
| 3 | 版2と同じで、随時の要素を`{"glob": ..., "when": ...}`でも書けます |
| ほか | 終わり方2で断ります |

宣言が`dashboard_attach_globs`を持つ時は、3つの欄を全て宣言から取り、技からは何も足しません。
型はスクリプトがrepoの根から展開し、何にも当たらない型は終わり方1で一覧を止めます。

## 添える物の一覧

`attachments.py [--repo <dir>] [--domain <d>] [--theme <name>] [--official <dir>] [--manifest <path>]`は、ファイルごとにtabで区切った1行を出します。

| 1列目 | 意味 |
|---|---|
| `required` | 添えます |
| `domain` | `--domain`で渡した業界の慣行です。添えます |
| `on-demand` | 3列目の「要る時」に当たる時だけ添えます |
| `request` | 頼みの文に写す文です。`--theme`を渡した時に出ます |

宣言が無い時は、取ったガイドブックと技の決まりを必須に、業界の慣行を業界に、ほかの決まりと取ったファイルを随時に並べます。
取ったファイルが欠けていれば、終わり方1で止まり、`fetch_official.py`を回すよう出します。
`--theme`を渡すと、`color-palette.md`、`theme-spec.md`、`chart-library.md`、テンプレート、配色のテーマを外し、`request`の行でガイドブックの配色の代わりにテーマの色を使うよう描く道具に頼みます。

## 頼みの文

エージェントは、あなたの描く道具に渡す頼みの文を1つ書きます。対象の画面、添えるファイル、ガイドブックを当てる画面、ほかの画面には当てないという文を持ちます。
頼みの文には寸法、色、字、配置を書かず、path、禁止、見本のデータだけを書きます。
描いた結果は、描く道具の報告を信じず、画面を数え、書き出したファイルと画像を読んで自分で確かめます。

## 書く物と残す物

プラグインが書くのは、`~/.local/share/digital-dashboard/`に取ったファイルだけで、あなたがフォルダーを消すまで残します。
あなたのプロジェクトにはファイルを書かず、一覧のファイルを求める依頼のほかには何も送りません。
