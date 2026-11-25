# Mechanism Explainerの仕組み

Mechanism Explainerは、題材を、読み手の問いに順に答える1枚の頁にします。
頁はdragonの説明の頁の形のMarkdownで書き、確かめと描画と書き出しはdragonが行い、PDFは手元のブラウザで印刷します。
スキルが持つのは手順とPDFのスクリプトだけで、図の種類と頁の形はdragonが持ちます。

## 手順

| 段 | 起きること | 実行する物 |
|---|---|---|
| 準備を確かめる | エージェントがdragon 0.80.1が動くかを確かめます | `npx -y @cardenelabs/dragon@0.80.1 --version` |
| 構成案を立てる | 読み手、問い、問いごとの2〜4枚の図を書き、合うまで直します | なし |
| 書く | `layout: guide`と`note: pop`を持つ`<name>.md`と、語を集めた`glossary.md`を書きます | なし |
| 確かめる | 全ての図の記法の誤りと配置の崩れを確かめ、dragonが出した行を全て直します | `dragon check`と`dragon check --layout` |
| 書き出す | dragonが頁を書き、スクリプトを中に持つ写しも書きます | `dragon export`と`dragon embed` |
| 印刷する | 頁を既定でA3の紙のPDFにします | `scripts/to-pdf.py` |

## 頁が持つ物

| 部品 | 書き方 | 見え方 |
|---|---|---|
| タブ | `## <話題>` | タブになり、頭にその問いの一覧が並びます |
| 節 | `### <問い>?` | 番号付きの節になります |
| 答え | 問いのすぐ下の`> <1文>` | 問いの下の答えになります |
| 図 | `dragon`の囲み | dragonが描く図になり、文より先に来ます |
| 札 | 箱の`note:` | 箱に印が付き、押すとすぐ下に札が開きます |
| 語 | `glossary.md`へのリンク | 下線の付いた語になり、押すと意味の札が開きます |
| 確かめの問い | `<details>`の囲み | 押すと答えが開く問いになります |

## 何がどこで動くか

| 物 | 動く場所 | 繋ぐ先 |
|---|---|---|
| dragon | 手元のマシンで`npx`経由 | 初回に1度だけ、パッケージをnpmのキャッシュへ取るためにnpmのレジストリ |
| `scripts/to-pdf.py` | 手元のマシンでPython 3の標準ライブラリだけ | なし |
| 印刷するブラウザ | 手元のマシンでheadlessの形と、終わると消す使い捨てのプロファイル | なし。印刷する頁はスクリプトを中に持ちます |

ブラウザは、`MECHANISM_EXPLAINER_BROWSER`が在ればそれを使います。
無ければPlaywrightのheadless shell、それも無ければ入っているGoogle Chrome、Chromium、Microsoft Edge、Braveを使います。
`to-pdf.py`は紙の大きさを足した頁の写しを頁の横に書き、写しを印刷してから消します。

## ファイルの置き場

Markdown、`glossary.md`、HTML、ネットに繋がずに開けるHTML、PDFは、作業しているフォルダの`explainer/<name>/`か指定のフォルダに書きます。
プラグインは状態を持たず、npm自身のキャッシュを除いて、そのフォルダの外には何も書きません。
