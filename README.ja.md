<div align="center">

<img src="assets/icon.svg" width="96" alt="agent-shurikenのアイコン">

# agent-shuriken

**Claude Code、Codex、ほかのコーディングエージェントで使える、慎重なプラグイン集。**

どのプラグインでも、面倒な作業はエージェントが進め、取り消せない操作はすべてあなたが決めます。
同じプラグインを、Claude Code、Codex、GitHub Copilot CLIにインストールでき、そのスキルはGemini CLIや`SKILL.md`を読むほかのエージェントでも動きます。

[English](README.md) · 日本語

[プラグイン](#プラグイン) ·
[インストール](#インストール) ·
[ドキュメント](#ドキュメント) ·
[リリース](https://github.com/cardene777/agent-shuriken/releases) ·
[変更履歴](CHANGELOG.md)

</div>

## プラグイン

| プラグイン | できること | 呼び出し方 | 最新バージョン |
|---|---|---|---|
| [account-cleanup](plugins/account-cleanup) | パスワードを一切読まずに、使っていないWebアカウントを見つけます。あなたが承認したアカウントは、サブスクリプションを解約してからアカウントを削除します | Claude Codeでは`/account-cleanup:account-cleanup`を実行し、Codexでは`$`を入力して**Account Cleanup**を選びます。やりたいことを言葉で頼んでも始まります | [0.2.0](plugins/account-cleanup/CHANGELOG.md) |
| [compare-report](plugins/compare-report) | 選ぶ時の候補を調べ、すべての主張に出典を、すべての点数に判定の根拠を付けた比較のレポートをHTMLとPDFで作ります | Claude Codeでは`/compare-report:compare-report`を実行し、Codexでは`$`を入力して**Compare Report**を選びます。比較を言葉で頼んでも始まります | [0.2.0](plugins/compare-report/CHANGELOG.md) |
| [diagram-explainer](plugins/diagram-explainer) | すべての節に図を描いた説明資料を、JSONから組んで確かめ、1つのHTMLファイルにします | Claude Codeでは`/diagram-explainer:diagram-explainer`を実行し、Codexでは`$`を入力して**Diagram Explainer**を選びます。説明資料を言葉で頼んでも始まります | [0.2.0](plugins/diagram-explainer/CHANGELOG.md) |
| [secure-dotfile](plugins/secure-dotfile) | シェルの起動ファイルに書いたAPIキーやトークンを見つけ、選んだ物だけを、エージェントに値を見せずにmacOSのキーチェーンへ移します | Claude Codeでは`/secure-dotfile:secure-dotfile`を実行し、Codexでは`$`を入力して**Secure Dotfile**を選びます。シェルの設定にある秘密の値の話をしても始まります | [0.2.0](plugins/secure-dotfile/CHANGELOG.md) |
| [techdebt](plugins/techdebt) | ファイルごとの変更の回数に、大きさ、古いTODOのコメント、テストの有無、長い関数、重複を合わせて直す価値の高いファイルに順位を付け、上位のファイルを説明します | Claude Codeでは`/techdebt:techdebt`を実行し、Codexでは`$`を入力して**Tech Debt**を選びます。技術的負債について尋ねても始まります | [0.2.0](plugins/techdebt/CHANGELOG.md) |

各プラグインのREADMEに、何をするか、何を読んで何を送るか、何が必要かを書いています。

## インストール

このリポジトリをマーケットプレイスとして一度だけ追加し、使いたいプラグインをインストールします。

**Claude Code**

```
/plugin marketplace add cardene777/agent-shuriken
/plugin install techdebt@agent-shuriken
```

**Codex**

```
codex plugin marketplace add cardene777/agent-shuriken
codex plugin add techdebt@agent-shuriken
```

**GitHub Copilot CLI**

```
copilot plugin marketplace add cardene777/agent-shuriken
copilot plugin install techdebt@agent-shuriken
```

**Gemini CLI**

```
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/techdebt/skills/techdebt
```

`techdebt`の部分は、表にある別のプラグイン名に置き換えられます。
`SKILL.md`を読むほかのエージェントでは、各プラグインのリリースに添付したスキルのzipを使えます。
インストールでコピーされるのは、そのプラグインのフォルダだけです。
起動、アップデート、バージョンの固定、削除の方法は[はじめに](docs/getting-started.ja.md)で説明しています。

## ドキュメント

| ページ | 内容 |
|---|---|
| [はじめに](docs/getting-started.ja.md) | Claude Code、Codex、GitHub Copilot CLI、Gemini CLI、ほかのエージェントでのプラグインのインストール、起動、アップデート、削除 |
| [安全性](docs/safety.ja.md) | あなたのアカウントやファイルに触れる時に、どのプラグインも守る約束 |
| [プラグインの作り方](docs/creating-a-plugin.ja.md) | このリポジトリに新しいプラグインを追加する方法 |
| [リリースの手順](docs/releasing.ja.md) | プラグインのバージョンとリポジトリのバージョンをリリースする方法 |
| [公式ディレクトリへの掲載](docs/publishing.ja.md) | AnthropicとOpenAIのプラグインの公式ディレクトリにプラグインを提出する方法 |

どのページも日本語で読めます。

## バージョン

プラグインごとにバージョンがあり、`techdebt--v0.1.0`のようなタグでリリースします。
リポジトリにもバージョンがあり、`v0.2.0`のようなタグでリリースします。
リポジトリのバージョンを見ると、その時点でマーケットプレイスにあった各プラグインのバージョンが分かります。
どちらもセマンティックバージョニングに従い、[リリースのページ](https://github.com/cardene777/agent-shuriken/releases)に並びます。

## 開発に参加する

Issueとプルリクエストを歓迎します。
先に[プラグインの作り方](docs/creating-a-plugin.ja.md)と[`AGENTS.md`](AGENTS.md)を読み、プルリクエストを出す前に`bash scripts/check.sh`を実行してください。

## セキュリティ

脆弱性は、[`SECURITY.md`](SECURITY.md)に書いた方法で非公開で報告してください。

## ライセンス

[MIT](LICENSE)です。
各プラグインのフォルダには、ライセンスのコピーと、同梱している第三者の素材の一覧が入っています。
