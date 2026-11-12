<div align="center">

<img src="assets/icon.svg" width="96" alt="agent-shurikenのアイコン">

# agent-shuriken

**Claude CodeとCodexで使える、慎重なプラグイン集。**

どのプラグインでも、面倒な作業はエージェントが進め、取り消せない操作はすべてあなたが決めます。
同じプラグインを、Claude CodeにもCodexにもインストールできます。

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
| [account-cleanup](plugins/account-cleanup) | パスワードを一切読まずに、使っていないWebアカウントを見つけます。あなたが承認したアカウントは、サブスクリプションを解約してからアカウントを削除します | Claude Codeでは`/account-cleanup:account-cleanup`を実行し、Codexでは`$`を入力して**Account Cleanup**を選びます。やりたいことを言葉で頼んでも始まります | [0.1.1](plugins/account-cleanup/CHANGELOG.md) |
| [pc-tidy](plugins/pc-tidy) | Macの中で使われなくなった物を一覧にし、あなたが選んだ物だけを消してディスクの空きを増やします | Claude Codeでは`/pc-tidy:pc-tidy`を実行し、Codexでは`$`を入力して**PC Tidy**を選びます。呼び出した時だけ始まります | [0.1.1](plugins/pc-tidy/CHANGELOG.md) |
| [root-cause](plugins/root-cause) | コードを変える前にバグの原因を証拠から突き止め、落ちるテストを先に書いて原因だけを直します | Claude Codeでは`/root-cause:root-cause`を実行し、Codexでは`$`を入力して**Root Cause**を選びます。バグを言葉で伝えても始まります | [0.1.0](plugins/root-cause/CHANGELOG.md) |

各プラグインのREADMEに、何をするか、何を読んで何を送るか、何が必要かを書いています。

## インストール

このリポジトリをマーケットプレイスとして一度だけ追加し、使いたいプラグインをインストールします。

**Claude Code**

```
/plugin marketplace add cardene777/agent-shuriken
/plugin install pc-tidy@agent-shuriken
```

**Codex**

```
codex plugin marketplace add cardene777/agent-shuriken
codex plugin add pc-tidy@agent-shuriken
```

`pc-tidy`の部分は、表にある別のプラグイン名に置き換えられます。
インストールでコピーされるのは、そのプラグインのフォルダだけです。
起動、アップデート、バージョンの固定、削除の方法は[はじめに](docs/getting-started.ja.md)で説明しています。

## ドキュメント

| ページ | 内容 |
|---|---|
| [はじめに](docs/getting-started.ja.md) | Claude CodeとCodexでのプラグインのインストール、起動、アップデート、削除 |
| [安全性](docs/safety.ja.md) | あなたのアカウントやファイルに触れる時に、どのプラグインも守る約束 |
| [プラグインの作り方](docs/creating-a-plugin.ja.md) | このリポジトリに新しいプラグインを追加する方法 |
| [リリースの手順](docs/releasing.ja.md) | プラグインのバージョンとリポジトリのバージョンをリリースする方法 |
| [公式ディレクトリへの掲載](docs/publishing.ja.md) | AnthropicとOpenAIのプラグインの公式ディレクトリにプラグインを提出する方法 |

どのページも日本語で読めます。

## バージョン

プラグインごとにバージョンがあり、`pc-tidy--v0.1.0`のようなタグでリリースします。
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
