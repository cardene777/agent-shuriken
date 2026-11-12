# OSS Contribute

外部のオープンソースのプロジェクトへ、そのプロジェクトの決まりに沿った直しを送ります。送るのは、あなたが承認した下書きそのものだけです。

[English](README.md) · 日本語

上流へ直しを送るには、直すこと以外にも手間がかかります。
プロジェクトごとに決まりがあります。先にIssueを立てるか、ブランチとコミットの書き方、コミットに署名(sign-off)が要るか、プルリクエストの雛形が何を求めるか、どの検査を通すか、AIの道具をどこまで認めるか、です。
しかも、送った物は公開され、取り消せません。
このプラグインは、その決まりを読み、クローンの中で直し、プロジェクトの検査をDockerのコンテナの中で動かします。プロジェクトのコードがあなたのマシンの上で動くことはありません。Issueやプルリクエストはプロジェクトの言語で書き、あなた向けの訳を添えます。
あなたがその下書きを承認するまで何も送らず、承認の後に変わった下書きも送りません。

```
決まりを読む ──> クローンで直す ──> 検査を動かす ──> 下書きを見せる ──> 承認した物を送る
 (エージェント)   (エージェント)     (Docker)         (エージェント)     (あなたが承認し、エージェントが送る)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install oss-contribute@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add oss-contribute@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install oss-contribute@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/oss-contribute/skills/oss-contribute   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「この直しをacme/shopの上流に送りたい」「このライブラリで不具合を見つけたので、プルリクエストを出そう」のように、プロジェクトへ直しや報告を送りたいと頼むと始まります。
エージェントがほかの作業の途中で外部のプロジェクトの不具合に気付いた時は、それを伝え、あなたが同意した時だけ始めます。自分から貢献を始めることはありません。
呼び出して始めることもできます。Claude Codeでは`/oss-contribute:oss-contribute`を実行し、Codexでは`$`を入力して**OSS Contribute**を選びます。
GitHub Copilot CLIでは依頼の中に`/oss-contribute`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントがプロジェクトを`~/.local/share/oss-contribute/clones/`にクローンし、決まりが書かれたファイルを並べます
2. エージェントがそれを読み、プロジェクトの流儀で名付けたブランチを作って直し、プロジェクトの書き方でコミットします
3. エージェントが、プロジェクトのlint、書式、テストの命令をDockerのコンテナの中で動かします
4. エージェントがIssueかプルリクエストをプロジェクトの言語で書き、あなた向けの訳を添えて、下書きを見せます。題、本文、コミット、差分と、秘密の値、ホームフォルダのパス、メールアドレスに見える物です
5. あなたがその下書きを承認すると、エージェントが送ります。プルリクエストの時は、フォークが無ければあなたのアカウントの下にフォークを作り、ブランチをpushして、プルリクエストを開きます
6. あとでメンテナーに頼まれた変更も、新しい下書きと新しい承認を通して送ります

プロジェクトの決まりは次のように表示されます。

```text
Rules of acme/shop
  folder           ~/.local/share/oss-contribute/clones/acme/shop
  contributing     .github/CONTRIBUTING.md
  security         SECURITY.md
  code of conduct  none
  issue templates  none
  pr templates     .github/pull_request_template.md
  agent guidance   none
  checks           go.mod, .github/workflows/ci.yml
  sign-off         asked for
    .github/CONTRIBUTING.md:5  Sign off every commit with `git commit -s` (DCO).
  CLA              not mentioned
  AI policy        1 line
    .github/CONTRIBUTING.md:6  If you used AI tools, say so in the pull request description.

Check commands in the project's files
  .github/workflows/ci.yml:8  go-version: '1.24'
  .github/workflows/ci.yml:9  run: go mod download
  .github/workflows/ci.yml:10  run: go vet ./...
  .github/workflows/ci.yml:11  run: go test ./...
```

プルリクエストの下書きは次のように表示されます。

```text
Draft acme-shop-pr-1
  repository   acme/shop
  kind         pull request
  from         fix/readme-typo on your fork, which is created when sending if you have none
  into         main
  title        Fix the spelling of "library" in the README
  status       drafted, not approved
  fingerprint  670b63aadf45

----- what the project's files say about AI (read before approving) -----
  .github/CONTRIBUTING.md:6  If you used AI tools, say so in the pull request description.

----- body (sent) -----
## What changed

Fixes the spelling of "library" in the README.

## How it was tested

Ran `go vet ./...` and `go test ./...` in a `golang:1.24` container. Both passed.

This change was prepared with an AI coding agent and reviewed by me.

----- commits (1) -----
  10d9cff Fix the spelling of "library" in the README  (Ada Example <ada@example.com>)

----- diff (1 file, +1 -1) -----
diff --git a/README.md b/README.md
index b324362..a651e2f 100644
--- a/README.md
+++ b/README.md
@@ -1,3 +1,3 @@
 # Shop
 
-Shop is a small cart libary for Go.
+Shop is a small cart library for Go.

----- findings -----
  none
```

## 承認が及ぶ範囲

承認は、リポジトリ、下書きの種類、題、本文、コミット、差分、送り先のブランチから作る指紋(fingerprint)として記録します。
承認の後にどれかが変わると、送る段階で断り、エージェントが新しい下書きを見せてもう一度尋ねます。
送る直前には送り先をもう一度確かめ、次の時は理由を示して止めます。プロジェクトがアーカイブされたか名前が変わった時、送り先のブランチが無くなった時、同じブランチからのプルリクエストか、同じ題のあなたのプルリクエストがすでに開いている時、Issueの状態が変わった時、あなたのフォークのブランチが変わった時です。
同じ下書きを2回送ることはありません。
指紋は、送る物があなたに見せた物と同じであることを保証します。「はい」と打ったのが誰かまでは分からないため、エージェントにはあなたの答えを受けてから承認するよう指示しています。

## AIの利用を制限するプロジェクト

Issueとプルリクエストの本文には、AIの道具を使ったことを、プロジェクトの言語で1行書きます。
AIが書いた貢献を禁じ、さらにコミットの署名を求めるプロジェクトでは、下書きを作る前に止めます。署名は「自分が書いたか、出す権利がある」と宣言する物だからです。
署名を求めずにAIの利用を制限するプロジェクトでは、下書きにプロジェクトの文面をそのまま引用し、あなたがそれを読んだと確かめてから送ります。

## セキュリティの問題

脆弱性は、公開のIssue、プルリクエスト、コメント、コミット、フォークに一切載せません。
プラグインはプロジェクトのセキュリティの方針のファイルと、GitHubの非公開の脆弱性報告が有効かを示し、エージェントがその窓口からあなたが送る報告の下書きを書きます。
プラグイン自身はセキュリティの報告を送りません。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に |
| `git` | 常に。フォークへpushするには、GitHubに登録したSSHの鍵か、HTTPSなら`gh auth setup-git`が要ります |
| `gh` | 送る時と、送る前に送り先を確かめる時に、`gh auth login`でGitHubにサインインした状態で使います |
| Docker | プロジェクトの検査を動かす時。無ければ検査は動かさず、下書きにそう書きます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、各コマンド、指紋、送る前の確かめ、コンテナを説明しています。
要点は次のとおりです。

- プロジェクトのクローンのファイルと、クローンのgitの情報を読みます。クローンの外を指すシンボリックリンクはたどりません
- `git`で公開のプロジェクトをGitHubからクローンしてクローンの中で作業し、`gh api`でプロジェクト、あなたのGitHubのログイン名、開いているIssueとプルリクエストを読み、`docker`でプロジェクトの検査をコンテナの中で動かします。検査ではイメージとプロジェクトの依存をダウンロードします
- あなたが承認するまで、あなたの物は何も送りません。下書きを承認すると、必要ならフォークを作り、ブランチをpushし、題、本文、コメントを、あなた自身の`gh`のサインインでGitHubに送ります。送った物は公開されます
- クローン、下書き、承認、送った物のリンクを`~/.local/share/oss-contribute/`に置いてあなただけが読めるようにし、プロジェクトごとのDockerのキャッシュのボリュームとともに、片付けの段階で消すまで残します。GitHubのあなたのフォークには触れません

## ライセンス

[MIT](LICENSE)
