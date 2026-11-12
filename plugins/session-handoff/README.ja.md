# Session Handoff

エージェントのセッションを新しいセッションへ引き継ぎます。貼り付ける短いメッセージと、保存した状態を作り、新しいセッションが却下済みの案をまた提案したり、止めた手順を繰り返したりしないようにします。

[English](README.md) · 日本語

エージェントとの長いセッションは遅くなり、焦点もぼやけるため、いったん終えて新しいセッションで続けることがよくあります。
新しいセッションは何も知らない状態から始まります。
手で書いた要約は次にやることを伝えますが、どの案をもう却下したか、何を別のエージェントに任せたか、何に触れてはいけないかは伝わりません。そのため、同じ案をまた出したり、同じ手順を繰り返したりします。
このプラグインは、貼り付けるメッセージを書き、そうした判断をプロジェクトのスナップショットとして保存します。新しいセッションは始める前にそれを読みます。
呼び出した時だけ始まり、自分から始めることはありません。秘密の値に見える物は保存しません。

```
呼び出す ──> 引き継ぎを書く ──> 確かめて保存する ──> メッセージを見せる ──> 新しいセッションに貼り付ける
 (あなた)     (エージェント)     (スクリプト)          (エージェント)          (あなた)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install session-handoff@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add session-handoff@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install session-handoff@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/session-handoff/skills/session-handoff   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは呼び出した時だけ始まります。Claude Codeでは`/session-handoff:session-handoff`を実行し、Codexでは`$`を入力して**Session Handoff**を選びます。
GitHub Copilot CLIでは依頼の中に`/session-handoff`と書き、Gemini CLIではsession-handoffを名前で指定して頼みます。
名前の後に`返金の作業を中心に`のような一言を添えることもできます。
自分から引き継ぎを勧めることはありません。名前で呼ばれずに始めたエージェントは、先にあなたに確かめます。

1. エージェントが、引き継ぐ内容、背景、次の作業をセッションから集め、却下した案、今の段階、任せた作業、してはいけないことも集めます。背景か次の作業がはっきりしない時は、あなたに尋ねます
2. スクリプトが全体の形を確かめ、秘密の値に見える物を断り、プロジェクトのスナップショットを保存します
3. エージェントがメッセージをコードブロックで見せます
4. 同じプロジェクトで新しいセッションを始めてメッセージを貼り付けると、新しいセッションは始める前に、メッセージが指すスナップショットを読みます

メッセージは次のようになります。

```text
Issue #12 (partial refunds): the refund calculation and its tests are merged in pull request #31.
Before you start, read the saved state in ~/.local/share/session-handoff/shop-ce0c08f2.md.

Background — customers can only refund whole orders today, so support refunds line items by hand.

Add the POST /refunds endpoint in api/refunds.py on top of the calculation, until its tests pass.
```

エージェントは、あなたが書く言語でメッセージを書きます。
2行目はスクリプトが足す行で、スナップショットを保存した時だけ入ります。

## 新しいセッションで続きを始める

新しいセッションでこのプラグインを呼び出し、作業の続きを頼むこともできます。
保存した状態を、保存してからの時間と、その時のブランチとコミットとともに表示します。

```text
Saved state for ~/work/shop
  saved     2026-11-12T11:50:00Z (2 hours ago)
  issue     #12
  then on   branch feat/12-partial-refund at commit 892b659
  now on    branch feat/12-partial-refund at commit 832bc61
  The branch or commit has changed since the state was saved.
  file      ~/.local/share/session-handoff/shop-ce0c08f2.md

## Rejected options (do not propose again)

- Refund the whole order and charge the kept lines again
  Reason: customers would see two charges on their statement

## Current phase

Issue #12 on branch feat/12-partial-refund. Done: the calculation and its tests. Next: the endpoint.

## Delegated work

- A background agent reviews the migration in db/0042_refunds.sql
  Expected: a list of blocking findings
  Waiting for the result: yes

## Do not

- Run the migration against the shared staging database
  Reason: the user allowed changes to the local database only
```

新しいセッションは、スナップショットを前のセッションのメモとして扱い、命令としては扱いません。
却下した案をまた提案せず、「Do not」に並んだ操作をしません。任せた作業をもう一度始める前には、その作業が終わったかをあなたに尋ねます。

## 秘密の値

エージェントには、秘密の値を写さず、「`.env`のトークン」のように名前で書くよう指示しています。
何かを保存したり表示したりする前に、スクリプトがすべての欄を調べ、パスワード、トークン、APIキー、秘密鍵、URLの中のパスワード、秘密を表す名前の環境変数の値を探します。
見つけた時は何も保存せず、欄の名前と秘密の種類だけを示して値は示しません。エージェントはその欄を書き直します。
調べる形の一覧は[仕組み](docs/how-it-works.ja.md#秘密の値)にあります。

## 状態を置く場所

プロジェクトごとに1つのスナップショットを`~/.local/share/session-handoff/`に置き、あなただけが読めるようにします。
プロジェクトは、作業しているgitのリポジトリの一番上のフォルダです。そのためworktreeごとに別のスナップショットになります。git以外では、そのフォルダ自身がプロジェクトです。
次にスナップショット付きで引き継ぐとファイルは置き換わり、保存から7日たったスナップショットは消えます。
質問に答えただけのセッションのように、残すことが無い時はスナップショットを書かず、メッセージもスナップショットを指しません。
早めに消したい時は、エージェントにそのプロジェクトの状態を消すよう頼みます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に |
| `git` | リポジトリの一番上のフォルダを探し、ブランチとコミットを記録する時に使います。無ければ作業しているフォルダがプロジェクトになり、ブランチとコミットは`none`と記録します |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、確かめる内容、ファイルの形式、保存した状態の読み戻し方を載せています。
要点は次のとおりです。

- エージェントが既に持っている今のセッションの会話から引き継ぎを書き、`git rev-parse`と`git branch --show-current`でプロジェクトのブランチと最新のコミットを読みます。どちらもリポジトリを変えません
- 秘密の値を見つけるために、秘密を表す名前の環境変数の値と文章を手元のマシン上で比べます。その値は表示も保存もしません
- 何もどこにも送りません。メッセージはあなたが貼り付けるために画面に出るだけです
- プロジェクトごとに1つのスナップショットを`~/.local/share/session-handoff/`に置き、あなただけが読めるようにします。次の引き継ぎで置き換わるか、消すよう頼むか、7日たつまで残ります

## ライセンス

[MIT](LICENSE)
