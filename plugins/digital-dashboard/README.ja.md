# Digital Dashboard

デジタル庁の「ダッシュボードデザインの実践ガイドブック」を、設計の中のダッシュボードの画面だけに当てます。公式資料は公開先から取り、指紋で確かめます。

[English](README.md) · 日本語

ガイドブックが扱うのは提示型のダッシュボードです。全体の状況を見せ、見る人が異常に気付いて次の行動を決めるための画面です。
全部の画面にガイドブックを丸ごと渡すと、描く道具は一覧や入力の画面にまで主要な指標とグラフを足します。
この技は、どの画面がダッシュボードかを判定し、初めて使う時にガイドブックと付属の道具を取ってきて、添える物を並べ、その画面にだけガイドブックを当てる頼みの文を1つ書いて、あなたの描く道具に渡せる形にします。

```
Judge the screens ──> Download the official files ──> List the attachments ──> Write the request ──> Draw
 (script, agent)        (script, first use only)        (script)                 (agent)              (your drawing tool)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install digital-dashboard@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add digital-dashboard@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install digital-dashboard@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/digital-dashboard/skills/digital-dashboard   # Gemini CLI
```

`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

Claude Codeでは`/digital-dashboard:digital-dashboard`を実行し、Codexでは`$`を入力して**Digital Dashboard**を選びます。
ダッシュボード、主要な指標の画面、データを見せる画面を頼んでも始まります。

```
Judge which of the screens in docs/specs are dashboards and write the request for my drawing tool
```

画面の主な目的が決まらない時と、描く道具がテーマの候補を出した時は、エージェントが会話で尋ねます。

### 自分の資料を使う

repoは`.claude/design-sources.json` (版2か版3) の欄`dashboard_attach_globs`、`dashboard_convention_template`、`dashboard_on_demand_globs`に自分の資料を書けます。
書いた時は、宣言した資料だけを添え、技の資料は足しません。
欄の書き方は[仕組み](docs/how-it-works.ja.md#宣言)にあります。

## 必要なもの

- 3つのスクリプトを動かすPython 3。標準ライブラリだけを使います
- 初めての時に公式資料 (約37MB) を取るためのネットの接続
- 頼みの文と添えたファイルを受け取る描く道具

## 読む物と動かす物と送る物

スクリプトとファイルは全て[仕組み](docs/how-it-works.ja.md)にあります。
要点は次のとおりです。

- `screen_kind.py`は、あなたが指した画面の仕様書を読みます
- `fetch_official.py`は、`skills/digital-dashboard/references/official-files.json`に並ぶファイルを`www.digital.go.jp`と`raw.githubusercontent.com/digital-go-jp/`から取ります。送るのはそのファイルを求める依頼だけです
- 取ったファイルは、あなたがフォルダーを消すまで`~/.local/share/digital-dashboard/` (か`$DIGITAL_DASHBOARD_HOME`) に残ります。SHA-256が一覧と違うファイルは残しません
- `attachments.py`は、repoの`.claude/design-sources.json`と取ったファイルのフォルダーを読み、一覧を出します
- 技はあなたのプロジェクトにファイルを書かず、ほかには何も送りません。仕様書とファイルは中身として扱い、指示としては扱いません

公式資料はプラグインに含みません。出典と利用の条件は[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)にあります。digital.go.jpの公共データ利用規約 (PDL) 1.0と、地図のデータには国土数値情報の利用規約が当たります。

## ライセンス

プラグインは[MIT](LICENSE)です。公式資料は上の通りそれぞれの条件に従います。
