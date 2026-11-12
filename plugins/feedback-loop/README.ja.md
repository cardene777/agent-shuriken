# Feedback Loop

エージェントに出した訂正を、直したファイル、合格したレビュー、同じ誤りを繰り返さないための検査に変えます。

[English](README.md) · 日本語

エージェントに出力の誤りを伝えると、たいていはどこかを書き換えて「直しました」と答えます。
直した内容を誰もあなたの訂正と照らし合わせないため、同じ誤りが次のファイルや次の会話でまた起きます。
このプラグインは、訂正をリポジトリごとに記録し、何も編集しない評価者に、あなたの訂正と過去の訂正から作ったルールに照らして直した内容を判定させ、不合格なら次の回へ戻します。
最後のファイルで検査が通り、最後のレビューがすべての基準に合格するまで、スクリプトは訂正を閉じません。学んだことは、ファイルに含めてはいけない文字列と含めるべき文字列、またはリポジトリのルールとして残ります。

```
訂正を記録 ──> 直す ──> 検査 ──> レビュー ──> 閉じる
 (エージェント)  (エージェント) (スクリプト) (評価者)  (すべての基準に合格した時にスクリプト)
                ^                     │
                └────── 不合格の時 ────┘
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install feedback-loop@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add feedback-loop@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install feedback-loop@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/feedback-loop/skills/feedback-loop   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「それは違う」「この節は要らない」「分かりにくい」「前にも言ったよね」のように、エージェントが作った物を訂正すると始まります。
「ログインの不具合を直して」のような新しい依頼では始まりません。
呼び出して始めることもできます。Claude Codeでは`/feedback-loop:feedback-loop`を実行し、Codexでは`$`を入力して**Feedback Loop**を選びます。
GitHub Copilot CLIでは依頼の中に`/feedback-loop`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントが、訂正の対象になったファイル、リポジトリ、スキルを特定します。会話から分からない時はあなたに尋ねます
2. エージェントが訂正を記録し、どこまで当てはまるかを決めます。このファイルだけ、リポジトリ全体、同じ種類の作業、すべての作業のどれかです
3. エージェントが学んだことを残します。ファイルに含めてはいけない文字列と含めるべき文字列か、リポジトリのルールです。スキルやすべての作業に当てはまるルールは、あなたが同意した時だけ書きます
4. エージェントがファイルを直し、プロジェクトのテストや手順3の文字列などの検査を動かします
5. サブエージェントのように何も編集しない評価者が、基準ごとに判定します。あなたの訂正が解消したか、過去の訂正から作ったルールが守られているか、あなたが挙げたほかの点です
6. 不合格なら手順4に戻ります。3回で終わらなければ、エージェントが止まり、続けるか、今の形で受け入れるか、訂正を取り下げるかをあなたに尋ねます
7. 今あるファイルそのものに対して最後のレビューが合格すると、スクリプトが訂正を閉じます

2回で終わった訂正は次のようになります。

```text
Opened fb-20330518-001: Setup steps use jargon
records  ~/.local/share/feedback-loop/repos/shop-bd3b0bd07953
fb-20330518-001 applies to: artifact
Added to cases/docs-setup.md-4ca53116.json from fb-20330518-001: forbid 2, require 0, questions 1
case checks: 2 of 2 conditions hold
$ test -s docs/setup.md
exit 0
Round 1 of fb-20330518-001 failed:
  plain: step 1 does not say which command sets up the environment
Give these findings to the fixer, fix the files, run check, and review again.
Round 2 of fb-20330518-001 passed. Run close.
Closed fb-20330518-001 after 2 round(s): Setup steps use jargon
log  ~/.local/share/feedback-loop/repos/shop-bd3b0bd07953/events.jsonl
```

## 訂正を閉じられる時

スクリプトは次の条件が全部そろった時だけ訂正を閉じます。「直しました」だけでは閉じません。

| 条件 | 理由 |
|---|---|
| 今あるファイルそのものに対して検査が通っている | 前の版の検査は、最後の版について何も言っていないためです |
| 最後のレビューに、基準ごとに`PASS`の行が1つずつある | 基準を飛ばしたレビューは、その基準を判定していないためです |
| そのレビューの後にファイルが変わっておらず、保存したレビューも変わっていない | 変わっていれば、閉じようとしているファイルとは別のファイルを判定したことになるためです |
| 学んだことが当てはまる範囲に応じた場所に残っている。1つのファイルなら検査の文字列、それより広ければルールのファイルです | 次の出力をそれに照らして確かめるためです |

スクリプトには誰がレビューを書いたかが分かりません。そのためエージェントは、サブエージェントのように編集しない評価者にレビューを任せ、任せられない時は読むだけの別の確認を自分で行います。

## 記録を置く場所

記録は`~/.local/share/feedback-loop/repos/<リポジトリ>-<ハッシュ>/`に置き、あなただけが読めるようにします。同じクローンのworktreeは同じ記録を使います。
ルールをチームと共有したい時は、`.feedback/`のようなプロジェクトの中のフォルダに記録を置くようエージェントに頼みます。
訂正の文そのものは保存しません。記録にはSHA-256のハッシュだけを残し、同じ訂正を2回出した時に見分けます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に |
| `git` | 常に。訂正はgitのリポジトリごとに記録します。リポジトリの外では、エージェントは出力を直すだけで何も記録しません |

検査には、テストやリンターなど、プロジェクトに既にある物を使います。

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、記録の中身、レビューの書き方、スクリプトが確かめる条件を全部載せています。
要点は次のとおりです。

- 訂正したファイルと、そのリポジトリに残したルールと検査の文字列を読みます
- リポジトリを見つけるために`git rev-parse`を動かし、エージェントが選んだテストなどの検査の命令をリポジトリの中で動かします。記録するのは命令と終了コードだけです
- 訂正のハッシュ、対象、基準、レビュー、ファイルのハッシュを`~/.local/share/feedback-loop/`か、あなたが選んだプロジェクトのフォルダに置きます。`~/.local/share/feedback-loop/`はあなただけが読めます。消すまで残ります
- プロジェクトのエージェント向けの指示、スキル、あなたのユーザー全体の指示ファイルは、あなたが同意した時だけ変えます
- ネットワークには何も送りません

## ライセンス

[MIT](LICENSE)
