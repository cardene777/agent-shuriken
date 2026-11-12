# はじめに

[English](getting-started.md) · 日本語

このページでは、Claude CodeとCodexでプラグインをインストール、起動、アップデート、削除する方法を説明します。
同じプラグインのフォルダがどちらでも動くので、片方のエージェントにも両方にもインストールできます。

## インストール

このリポジトリを、マーケットプレイスとして一度だけ追加します。
その後は、[プラグインの表](../README.ja.md#プラグイン)にあるプラグインを名前でインストールできます。

| | Claude Code | Codex |
|---|---|---|
| マーケットプレイスを追加する | `/plugin marketplace add cardene777/agent-shuriken` | `codex plugin marketplace add cardene777/agent-shuriken` |
| プラグインをインストールする | `/plugin install pc-tidy@agent-shuriken` | `codex plugin add pc-tidy@agent-shuriken` |
| インストール済みの物を見る | `/plugin` | `codex plugin list` |

Claude Codeでは、同じ操作をターミナルから`claude plugin marketplace add ...`や`claude plugin install ...`として実行することもできます。
インストールした後は、エージェントがプラグインを読み込めるよう、新しいセッションを始めてください。

インストールでは、そのプラグインのフォルダだけがエージェントのプラグイン用キャッシュにコピーされます。
インストールの時点では何も実行されません。

## プラグインを起動する

起動の仕方は、各プラグインのREADMEに書いてあります。
やりたいことを普通の言葉で伝えると起動するプラグインと、呼び出した時だけ起動するプラグインがあります。

| | Claude Code | Codex |
|---|---|---|
| プラグインのスキルを呼び出す | `/<plugin>:<skill>`の形で呼びます。例えば`/pc-tidy:pc-tidy`です | `$`を入力してスキルを選びます。例えば**PC Tidy**です |
| やりたいことを伝える | 例えば「Macのディスクの空きを増やしたい」のように、やりたいことを書きます | Claude Codeと同じです |

エージェントは、あなたが書いた言語で返事をします。
プラグインが開くページは最初は英語で表示され、上部のEnglish / 日本語の切り替えで日本語にできます。

Codexでは、プラグインがプロジェクトのフォルダの外を読み書きし、ネットワークを使うプラグインもあります。
Codexのサンドボックスでコマンドが止まった時は、そのコマンドを承認すると、プラグインが続きを実行します。

## アップデート

| | Claude Code | Codex |
|---|---|---|
| 最新のマーケットプレイスを取得する | `claude plugin marketplace update agent-shuriken` | `codex plugin marketplace upgrade agent-shuriken` |
| プラグインをアップデートする | `claude plugin update pc-tidy@agent-shuriken` | `codex plugin add pc-tidy@agent-shuriken` |

アップデートした後は、エージェントを起動し直してください。
何が変わったかは、各プラグインの`CHANGELOG.md`に書いてあります。

## バージョンを固定する

マーケットプレイスを、最新のコミットではなくタグを指定して追加します。
`pc-tidy--v0.1.0`のようなプラグインのタグでも、`v0.2.0`のようなリポジトリのタグでも指定でき、マーケットプレイスの全プラグインがそのタグの時点の物になります。

| | Claude Code | Codex |
|---|---|---|
| タグを指定してマーケットプレイスを追加する | `/plugin marketplace add cardene777/agent-shuriken#v0.2.0` | `codex plugin marketplace add cardene777/agent-shuriken --ref v0.2.0` |

プラグインのタグとリポジトリのタグの違いは、[リリースの手順](releasing.ja.md)で説明しています。

## マーケットプレイスを使わずにインストールする

プラグインのリリースには、それぞれスキルのフォルダをまとめたzipが添付されています。
これを、エージェントのスキル用フォルダに展開します。

```
unzip pc-tidy-0.1.0-skill.zip -d ~/.claude/skills/   # Claude Code
unzip pc-tidy-0.1.0-skill.zip -d ~/.codex/skills/    # Codex
```

この方法で入れたスキルにはプラグイン名の接頭辞が付かないので、Claude Codeでは`/pc-tidy`で呼び出します。
自動ではアップデートされません。
アップデートするには、新しいzipをダウンロードしてください。

## 削除する

| | Claude Code | Codex |
|---|---|---|
| プラグインを削除する | `claude plugin uninstall pc-tidy@agent-shuriken` | `codex plugin remove pc-tidy@agent-shuriken` |
| マーケットプレイスを削除する | `claude plugin marketplace remove agent-shuriken` | `codex plugin marketplace remove agent-shuriken` |

プラグインを削除しても、プラグインが保存したデータは消えません。
データの置き場所は、各プラグインのREADMEに書いてあります。
