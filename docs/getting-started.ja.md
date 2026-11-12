# はじめに

[English](getting-started.md) · 日本語

このページでは、Claude Code、Codex、GitHub Copilot CLI、Gemini CLIでプラグインをインストール、起動、アップデート、削除する方法と、`SKILL.md`を読むほかのエージェントで使う方法を説明します。
同じプラグインのフォルダがどれでも動くので、1つのエージェントにも複数のエージェントにもインストールできます。

## インストール

このリポジトリを、マーケットプレイスとして一度だけ追加します。
その後は、[プラグインの表](../README.ja.md#プラグイン)にあるプラグインを名前でインストールできます。

| | Claude Code | Codex | GitHub Copilot CLI |
|---|---|---|---|
| マーケットプレイスを追加する | `/plugin marketplace add cardene777/agent-shuriken` | `codex plugin marketplace add cardene777/agent-shuriken` | `copilot plugin marketplace add cardene777/agent-shuriken` |
| プラグインをインストールする | `/plugin install techdebt@agent-shuriken` | `codex plugin add techdebt@agent-shuriken` | `copilot plugin install techdebt@agent-shuriken` |
| インストール済みの物を見る | `/plugin` | `codex plugin list` | `copilot plugin list` |

Claude Codeでは、同じ操作をターミナルから`claude plugin marketplace add ...`や`claude plugin install ...`として実行することもできます。
GitHub Copilot CLIはClaude Codeと同じマーケットプレイスのファイルを読むので、追加の準備は要りません。
インストールした後は、エージェントがプラグインを読み込めるよう、新しいセッションを始めてください。

Gemini CLIにはスキルのマーケットプレイスが無いので、各プラグインのスキルのフォルダをこのリポジトリから直接インストールします。

```
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/techdebt/skills/techdebt
gemini skills list
```

インストールでは、そのプラグインのフォルダだけ、Gemini CLIではそのスキルのフォルダだけがコピーされます。
インストールの時点では何も実行されません。

## プラグインを起動する

起動の仕方は、各プラグインのREADMEに書いてあります。
やりたいことを普通の言葉で伝えると起動するプラグインと、呼び出した時だけ起動するプラグインがあります。

| | Claude Code | Codex | GitHub Copilot CLI | Gemini CLI |
|---|---|---|---|---|
| プラグインのスキルを呼び出す | `/<plugin>:<skill>`の形で呼びます。例えば`/techdebt:techdebt`です | `$`を入力してスキルを選びます。例えば**Tech Debt**です | 依頼の中でスキルの名前にスラッシュを付けて書きます。例えば「/techdebtのスキルを使って」です | やりたいことを伝えます。Gemini CLIはスキルを読み込む前に承認を求めます |
| やりたいことを伝える | 例えば「このリポジトリで先に直すべき技術的負債を知りたい」のように、やりたいことを書きます | Claude Codeと同じです | Claude Codeと同じです | Claude Codeと同じです |

エージェントは、あなたが書いた言語で返事をします。
プラグインが開くページは最初は英語で表示され、上部のEnglish / 日本語の切り替えで日本語にできます。

プラグインはプロジェクトのフォルダの外を読み書きし、ネットワークを使うプラグインもあります。
Codexのように、エージェントのサンドボックスでコマンドが止まった時は、そのコマンドを承認すると、プラグインが続きを実行します。

Claude CodeとCodexでは呼び出した時だけ起動するプラグインも、ほかのエージェントでは、やりたいことを伝えただけで起動することがあります。起動を止める設定を読まないエージェントがあるためです。
その場合も、READMEに書いた手順で項目を選んで承認するまで、プラグインは何も変えません。

## アップデート

| | Claude Code | Codex | GitHub Copilot CLI | Gemini CLI |
|---|---|---|---|---|
| 最新のマーケットプレイスを取得する | `claude plugin marketplace update agent-shuriken` | `codex plugin marketplace upgrade agent-shuriken` | `copilot plugin marketplace update agent-shuriken` | 要りません |
| プラグインをアップデートする | `claude plugin update techdebt@agent-shuriken` | `codex plugin add techdebt@agent-shuriken` | `copilot plugin update techdebt` | インストールのコマンドをもう一度実行します。入っている写しが置き換わります |

アップデートした後は、エージェントを起動し直してください。
何が変わったかは、各プラグインの`CHANGELOG.md`に書いてあります。

## バージョンを固定する

マーケットプレイスを、最新のコミットではなくタグを指定して追加します。
`techdebt--v0.1.0`のようなプラグインのタグでも、`v0.2.0`のようなリポジトリのタグでも指定でき、マーケットプレイスの全プラグインがそのタグの時点の物になります。

| | Claude Code | Codex | GitHub Copilot CLI |
|---|---|---|---|
| タグを指定してマーケットプレイスを追加する | `/plugin marketplace add cardene777/agent-shuriken#v0.2.0` | `codex plugin marketplace add cardene777/agent-shuriken --ref v0.2.0` | `copilot plugin marketplace add cardene777/agent-shuriken#v0.2.0` |

Gemini CLIでは、次の節のとおりリリースのスキルのzipをインストールします。
プラグインのタグとリポジトリのタグの違いは、[リリースの手順](releasing.ja.md)で説明しています。

## マーケットプレイスを使わずにインストールする

プラグインのリリースには、それぞれスキルのフォルダをまとめたzipが添付されています。
これを、エージェントのスキル用フォルダに展開します。
GitHub Copilot CLI、Gemini CLI、Agent Skillsの形式に従うほかのエージェントは`~/.agents/skills/`を読みます。

```
unzip techdebt-0.1.0-skill.zip -d ~/.claude/skills/   # Claude Code
unzip techdebt-0.1.0-skill.zip -d ~/.codex/skills/    # Codex
unzip techdebt-0.1.0-skill.zip -d ~/.agents/skills/   # GitHub Copilot CLI, Gemini CLI, and other agents
```

別のフォルダを読むエージェントでは、そのフォルダに展開します。フォルダの名前は、そのエージェントの資料に書いてあります。
この方法で入れたスキルにはプラグイン名の接頭辞が付かないので、Claude Codeでは`/techdebt`で呼び出します。
自動ではアップデートされません。
アップデートするには、新しいzipをダウンロードしてください。

## 削除する

| | Claude Code | Codex | GitHub Copilot CLI | Gemini CLI |
|---|---|---|---|---|
| プラグインを削除する | `claude plugin uninstall techdebt@agent-shuriken` | `codex plugin remove techdebt@agent-shuriken` | `copilot plugin uninstall techdebt` | `gemini skills uninstall techdebt` |
| マーケットプレイスを削除する | `claude plugin marketplace remove agent-shuriken` | `codex plugin marketplace remove agent-shuriken` | `copilot plugin marketplace remove agent-shuriken` | 要りません |

プラグインを削除しても、プラグインが保存したデータは消えません。
データの置き場所は、各プラグインのREADMEに書いてあります。
