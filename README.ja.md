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
| [docs-publish](plugins/docs-publish) | オープンソースのプロジェクトの公開ドキュメントを、Quickstart、Concepts、APIリファレンス、Cookbook、FAQの5つの部に分けて、英語とあなたが選ぶもう1つの言語で書きます。すべてのページに翻訳があり、すべてのリンクが切れていないかを確かめます | Claude Codeでは`/docs-publish:docs-publish`を実行し、Codexでは`$`を入力して**Docs Publish**を選びます。プロジェクトのドキュメントを頼んでも始まります | [0.1.0](plugins/docs-publish/CHANGELOG.md) |
| [excalidraw-diagram](plugins/excalidraw-diagram) | アーキテクチャ図、フロー図、シーケンス図、ER図を、スクリプトが配置して重なり、詰まった間隔、線に重なるラベルを確かめたExcalidrawのファイルとして描きます。SVGとPNGの写しも作ります | Claude Codeでは`/excalidraw-diagram:excalidraw-diagram`を実行し、Codexでは`$`を入力して**Excalidraw Diagram**を選びます。図を言葉で頼んでも始まります | [0.1.0](plugins/excalidraw-diagram/CHANGELOG.md) |
| [feedback-loop](plugins/feedback-loop) | エージェントの出力を訂正すると、訂正を記録してファイルを直し、何も編集しない評価者がすべての基準に合格と判定するまでレビューを繰り返し、学んだことを検査かルールとして残します | Claude Codeでは`/feedback-loop:feedback-loop`を実行し、Codexでは`$`を入力して**Feedback Loop**を選びます。前の出力を訂正しても始まります | [0.1.0](plugins/feedback-loop/CHANGELOG.md) |
| [init-project](plugins/init-project) | プロジェクトを手元で動かす準備をします。空いているローカルのポートを選び、Dockerの設定を書き、envファイルを参照の形で1Passwordにつなぎます。どのファイルも書く前に見せます | Claude Codeでは`/init-project:init-project`を実行し、Codexでは`$`を入力して**Init Project**を選びます。プロジェクトの準備を頼んでも始まります | [0.1.0](plugins/init-project/CHANGELOG.md) |
| [learning-to-skill](plugins/learning-to-skill) | 会話で得た学びを、AGENTS.md、CLAUDE.md、スキルのSKILL.mdのようなエージェントが読む指示のファイルに、必要なエージェントに届く場所へ1回だけ書きます。書くのはあなたが差分を承認した後だけです | Claude Codeでは`/learning-to-skill:learning-to-skill`を実行し、Codexでは`$`を入力して**Learning to Skill**を選びます。学びを覚えておくよう頼んでも始まります | [0.1.0](plugins/learning-to-skill/CHANGELOG.md) |
| [oss-contribute](plugins/oss-contribute) | 外部のオープンソースのプロジェクトへ、その決まりに沿った直しを用意します。検査はコンテナの中で動かし、Issueやプルリクエストは相手の言語で訳を添えて下書きし、あなたが承認した下書きだけを送ります | Claude Codeでは`/oss-contribute:oss-contribute`を実行し、Codexでは`$`を入力して**OSS Contribute**を選びます。名前を挙げたプロジェクトへ直しを送りたいと頼んでも始まります | [0.1.0](plugins/oss-contribute/CHANGELOG.md) |
| [portman](plugins/portman) | プロジェクトごとに使うlocalhostのポートを1つの台帳で管理し、今それぞれのポートを何が使っているかを示し、よく使われる既定のポートを避けた空きポートを提案し、承認した後にプロジェクトの`.env.local`とDocker Composeにポートを書きます | Claude Codeでは`/portman:portman`を実行し、Codexでは`$`を入力して**Portman**を選びます。ポートが使われていて困った時にも始まります | [0.1.0](plugins/portman/CHANGELOG.md) |
| [repo-progress](plugins/repo-progress) | 作業しているリポジトリ全部を、worktree、開いたIssueとプルリクエスト、コミットしていない変更とともに1つの表にし、止まっている物から並べます。何も変えません | Claude Codeでは`/repo-progress:repo-progress`を実行し、Codexでは`$`を入力して**Repo Progress**を選びます。何をやりかけだったか尋ねても始まります | [0.1.0](plugins/repo-progress/CHANGELOG.md) |
| [secure-dotfile](plugins/secure-dotfile) | シェルの起動ファイルに書いたAPIキーやトークンを見つけ、選んだ物だけを、エージェントに値を見せずにmacOSのキーチェーンへ移します | Claude Codeでは`/secure-dotfile:secure-dotfile`を実行し、Codexでは`$`を入力して**Secure Dotfile**を選びます。シェルの設定にある秘密の値の話をしても始まります | [0.2.0](plugins/secure-dotfile/CHANGELOG.md) |
| [session-handoff](plugins/session-handoff) | 新しいセッションに貼り付ける短いメッセージを書き、却下した案、今の段階、任せた作業、してはいけないことをプロジェクトごとに保存します。秘密の値に見える物は保存しません | Claude Codeでは`/session-handoff:session-handoff`を実行し、Codexでは`$`を入力して**Session Handoff**を選びます。呼び出した時だけ始まります | [0.1.0](plugins/session-handoff/CHANGELOG.md) |
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
