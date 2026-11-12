# プラグインの作り方

[English](creating-a-plugin.md) · 日本語

このページでは、Claude CodeとCodexの両方にインストールできるプラグインを、このリポジトリに追加する方法を説明します。
どの変更でも守る決まりは[`AGENTS.md`](../AGENTS.md)に、どのプラグインも守る約束は[安全性](safety.ja.md)に書いてあります。

## フォルダの構成

プラグインは、`plugins/`の下の1つのフォルダです。
インストールではこのフォルダだけがコピーされるので、プラグインに要る物はすべてこの中に置きます。

```
plugins/<name>/
├── .claude-plugin/plugin.json     Claude Codeが読む設定 (次の設定が無い時はCodexも読む)
├── .codex-plugin/plugin.json      Codexが読む設定。OpenAIの公式ディレクトリに載せる紹介文も持つ
├── README.md                      何をするか、使い方、何を読み、何を実行し、何を送るか
├── README.ja.md                   その日本語版
├── CHANGELOG.md                   このプラグインのリリース
├── LICENSE                        リポジトリのライセンスのコピー
├── THIRD_PARTY_NOTICES.md         第三者のファイルを同梱する時だけ
├── assets/                        READMEと公式ディレクトリに出すスクリーンショットとアイコン
├── docs/                          詳しいページ。それぞれに.ja.mdの日本語版を付ける
└── skills/<skill>/
    ├── SKILL.md                   エージェントが従う指示
    ├── agents/openai.yaml         Codexでの表示名と呼び出し方
    ├── scripts/                   スキルが実行するスクリプト
    ├── templates/                 スクリプトが書き出すファイルのひな形
    └── data/                      同梱するデータ
```

マーケットプレイスの定義`.claude-plugin/marketplace.json`には全プラグインのフォルダが載っていて、両方のエージェントがこれを読みます。

## 手順

1. `plugins/<name>/skills/<name>/SKILL.md`を作ります。フロントマターの`name`にはフォルダ名を、`description`にはスキルが何をし、いつ使うかを書きます。ユーザーが呼び出した時だけ動かすスキルには、`disable-model-invocation: true`を足します
2. `SKILL.md`は両方のエージェントに向けて書きます。片方のエージェントのツール名を書く代わりに「shell command」と書きます。Claude CodeのAskUserQuestionのように片方にしか無いツールが要る手順では、もう片方でどうするかも書きます
3. `SKILL.md`の隣に`agents/openai.yaml`を置き、`interface.display_name`、`interface.short_description`、`$<name>`に触れた`interface.default_prompt`、`policy.allow_implicit_invocation`を書きます。`policy.allow_implicit_invocation`を`false`にするのは、`SKILL.md`に`disable-model-invocation: true`がある時だけです
4. `.claude-plugin/plugin.json`と`.codex-plugin/plugin.json`を足します。既存のプラグインからコピーし、`name`、`description`、`keywords`、`interface`を書き換えます。バージョンは`0.1.0`から始めます
5. `README.md`と`README.ja.md`を足します。公式ディレクトリのセキュリティ審査ではREADMEとコードの実際の動きを突き合わせるため、プラグインが読む物、実行する物、接続する先、残す物をすべて書きます。画像は`assets/`に置き、Markdownの画像の記法で表示します
6. 空の`## [Unreleased]`節だけを持つ`CHANGELOG.md`を足し、ルートの`LICENSE`をコピーします
7. `.claude-plugin/marketplace.json`に、同じ`name`と`description`、そして`"source": "./plugins/<name>"`を持つ項目を足します
8. `README.md`と`README.ja.md`のプラグインの表に行を足します
9. `bash scripts/check.sh`を実行し、報告された問題をすべて直します

## プラグインを小さく審査しやすく保つ

画像以外のファイルが256 KiBを超える時、ファイルが512個を超える時、画像とフォント以外のバイナリを含む時は、公式ディレクトリでそのバージョンが審査担当者の確認待ちになります。
スクリプトは読みやすく保ち、依存はBash、`jq`、Python 3の標準ライブラリ、ブラウザを操作する場合のNode.jsまでに抑えます。
利用者にグローバルなパッケージのインストールを求めないでください。
フックがあるプラグインはOpenAIの公式ディレクトリに載せられないため、フックも足さないでください。

## テスト

プラグインは使い捨てのデータフォルダか`HOME`で試し、本物のアカウント、保管庫、ファイルでは試さないでください。
利用者と同じ形で試すには、作業中のコピーから使い捨ての設定へインストールします。
こうすると自分の環境は変わりません。

```
export CLAUDE_CONFIG_DIR="$(mktemp -d)"
claude plugin marketplace add ./
claude plugin install <name>@agent-shuriken

export CODEX_HOME="$(mktemp -d)"
codex plugin marketplace add ./
codex plugin add <name>@agent-shuriken
codex debug prompt-input hi | grep '<name>'
```

最後のコマンドで、Codexがスキルをモデルに提示しているかが分かります。
提示するのは、`allow_implicit_invocation`が`true`の時だけです。
