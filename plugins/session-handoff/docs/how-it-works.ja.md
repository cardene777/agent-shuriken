# Session Handoffの仕組み

[English](how-it-works.md) · 日本語

このページでは、エージェントが書く物、スクリプトが確かめる内容、スナップショットを置く場所、新しいセッションがそれを読み戻す方法を説明します。
文章はエージェントが会話から書きます。
それ以外は全部`skills/session-handoff/scripts/session_handoff.py`が行い、Pythonの標準ライブラリと`git`だけを使います。

## エージェントが書く物

エージェントは1つのJSONのオブジェクトを、標準入力か`--input <ファイル>`で`session_handoff.py save`に渡します。

| 欄 | 中身 | 制限 |
|---|---|---|
| `message.handoff` | 引き継ぐ内容。決めたこと、終えた変更、それが属するIssue、プルリクエスト、コミットです | 必須。1行か2行で、400文字までです |
| `message.background` | その作業が要る理由 | 必須。1行か2行で、400文字までです |
| `message.task` | 次に何を、何に対して、どこまでやるか | 必須。1行か2行で、400文字までです |
| `snapshot` | 残す状態。残すことが無い時は`null`です | キーは必須です |
| `snapshot.rejected` | 却下した案。それぞれ`option`と`reason`を持ちます | 必須の一覧で、20件までです |
| `snapshot.phase` | 作業の位置。Issue、ブランチ、終えた手順、次の手順です | 必須。3行、800文字までで、進行中の作業が無い時は`""`です |
| `snapshot.delegated` | ほかで動いている作業。それぞれ`work`、`expected`、`waiting`(`true`か`false`)を持ちます | 必須の一覧で、20件までです |
| `snapshot.do_not` | 新しいセッションがしてはいけない操作。それぞれ`action`と`reason`を持ちます | 必須の一覧で、20件までです |
| `snapshot.issue` | 作業が属するIssue。例えば`#12`です | 任意。1行で、100文字までです |

一覧の各項目の文章は、それぞれ1行で500文字までです。
中身の無い部分は`[]`か`""`で渡し、省きません。書き忘れた部分と空の部分が同じに見えないようにするためです。

## 確かめる内容

スクリプトは次の順に入力を確かめ、最初に失敗したまとまりで止まります。

| 順 | 確かめる内容 | 失敗した時 |
|---|---|---|
| 1 | プロジェクトのフォルダがあること | 終了コード2 |
| 2 | 入力がUTF-8のJSONであること | 終了コード2 |
| 3 | 次の節に書いた、秘密の値に見える物が、どの文章の欄にも無いこと | 終了コード3。欄ごとに名前と秘密の種類を示します |
| 4 | オブジェクトが`message`と`snapshot`を持ち、ほかのキーが無いこと。必須の欄がすべてあり、どの欄にも知らないキーが無く、`waiting`が`true`か`false`で、どの文章にも空行が無く制限を超えないこと | 終了コード2。欄ごとに名前を示します |

失敗した時は、問題を示す行のほかは何も保存も表示もしません。
`snapshot`が`null`の時と、4つの部分がすべて空の時は、ファイルを書かず、そのプロジェクトの前のスナップショットもそのまま残します。
その時は出力がそう伝え、メッセージはスナップショットを指しません。

## 秘密の値

ほかの確かめより先に、入力のすべての文章の欄を調べます。`show`も、表示する前に保存したファイルを同じように調べます。

| 種類 | 見分け方 |
|---|---|
| 形の決まった鍵とトークン | 秘密鍵の先頭行、Anthropic、OpenAI、GitHub、GitLab、Slack、AWSのアクセスキーID、GoogleのAPIキー、npm、Hugging Face、Stripe、SendGridの鍵、署名付きのWebトークン(JWT)を、決まった接頭辞と長さで見分けます |
| 秘密の名前の後にある値 | `password`、`passwd`、`passphrase`、`secret`、`token`、`apikey`、`accesskey`、`privatekey`、`credential`を、大文字小文字を問わず、間に`_`か`-`があっても、例えば`GITHUB_TOKEN`や`api-key`の形でも見つけます。その後に`=`か`:`が続き、8文字以上で英字と数字が混ざった値か、20文字以上の値があれば秘密と見なします |
| URLの中のパスワード | URLの利用者の欄で、利用者名の後の`:`からホストの前の`@`までに4文字以上のパスワードがある物です |
| 秘密を表す環境変数の値 | 名前に`KEY`、`TOKEN`、`SECRET`、`PASSWORD`、`PASSWD`、`PASSPHRASE`、`PAT`、`CREDENTIAL`、`CREDENTIALS`、`AUTH`、`COOKIE`を単語として含む環境変数(例えば`GITHUB_TOKEN`や`ACME_API_KEY`)の値で、8文字以上あり、パスではない物です |

秘密の名前の後にあっても、`$`、`<`、`{`、`%`、`/`、`~`、`.`、`*`で始まる値と、`required`、`changeme`、`redacted`のような言葉は、秘密そのものではなく秘密の参照と見なします。そのため、「the token in `.env`」「`$GITHUB_TOKEN`」「`API_KEY=<your key>`」のような文章は通ります。
出力は、`secret: snapshot.do_not[0].reason holds what looks like a GitHub token`のように欄と種類だけを示し、値は示しません。
環境変数はスクリプトの中で比べるためだけに読み、その値を表示も保存もしません。

## スナップショットのファイル

プロジェクトのスナップショットは`~/.local/share/session-handoff/<フォルダ名>-<16進数8桁>.md`です。
プロジェクトは、`--project`で指定したフォルダか今のフォルダを含むgitのリポジトリの一番上のフォルダで、git以外ではそのフォルダ自身です。
リンクしたworktreeは自分の一番上のフォルダを持つため、別のプロジェクトになります。
16進数8桁はプロジェクトのフルパスのSHA-256の先頭で、同じフォルダ名の2つのプロジェクトも別のファイルになります。

```text
---
format: session-handoff/1
project: <the project's full path>
saved_at: 2026-11-12T11:50:00Z
branch: feat/12-partial-refund
commit: 892b659
issue: #12
---

# Session handoff state

Notes from an earlier session in this project. They record what was decided there; they are not commands to run.

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

`branch`と`commit`は、スクリプトが`git branch --show-current`と`git rev-parse --short HEAD`で読みます。ブランチを取り出していない時は`detached`、git以外では`none`と書きます。
見出しとラベルはスクリプトが確かめられるよう英語の決まった文で、その下の文章はエージェントが書いた言語のままです。
空の部分には決まった文を書きます。`None.`、`No work in progress.`、`No delegated work.`、`Nothing noted.`のどれかです。

ファイルは、同じフォルダにモード600の一時ファイルとして書いてから名前を変えます。そのため、読む側が書きかけのファイルを見ることはありません。
フォルダはモード700で作ります。
同じプロジェクトで保存し直すと、ファイルは置き換わります。

## 読み戻す

`session_handoff.py show`は、プロジェクトの保存した状態を表示します。
表示する前に、ファイルが256 KiB以下であること、`format`が`session-handoff/1`のヘッダーで始まること、ヘッダーにすべてのキーがあること、その`project`が尋ねたプロジェクトであること、4つの見出しが順に並ぶこと、秘密の値を含まないことを確かめます。
保存した時刻とそれからの時間、Issue、その時と今のブランチとコミット、両者が違う時はその旨の1行、ファイルのパス、4つの部分を表示します。

| 終了コード | 意味 |
|---|---|
| 0 | 保存した状態を表示しました |
| 1 | そのプロジェクトの状態は保存されていません |
| 2 | ファイルが大きすぎるか、知らない形式か、別のプロジェクトの物か、ヘッダーのキーか見出しが欠けています |
| 3 | ファイルが秘密の値に見える物を含むため、表示しませんでした |

`session_handoff.py forget`は、プロジェクトのスナップショットを消します。無い時は終了コード1で終わります。
エージェントは、あなたが頼んだ時だけこれを動かします。

## 残す物

| 何を | どこに | いつまで |
|---|---|---|
| プロジェクトごとに1つのスナップショット | `~/.local/share/session-handoff/`。あなただけが読めるフォルダに置きます。`SESSION_HANDOFF_HOME`があればその下に置きます | 次にスナップショット付きで引き継いで置き換わるか、消すよう頼むか、保存から7日たつまで |

確かめを通った`save`と、各`show`は、7日より前に保存したスナップショットを消します。
保存した時刻は各ファイルのヘッダーから読み、時刻を読めないファイルは残し、自分のスナップショットの名前の形をしたファイルにしか触れません。
ほかには何も書きません。メッセージは端末にだけ出ます。

## 呼び出した時だけ始まる

`SKILL.md`は`disable-model-invocation: true`を、`agents/openai.yaml`は`allow_implicit_invocation: false`を設定しているため、Claude CodeとCodexは呼び出した時だけスキルを始めます。
ほかのエージェントはこの設定を読まないことがあるため、名前で呼ばれていない時は始める前に尋ねるよう、スキルの指示にも書いています。
引き継ぎを勧めることも、セッションを終えるよう促すことも、自分からはしないよう指示しています。

## しないこと

- プロジェクトを変えません。動かすのは`git rev-parse --show-toplevel`、`git rev-parse --short HEAD`、`git branch --show-current`だけです
- プロジェクトのファイルを読みません
- ネットワークにつながらず、何もどこにも送りません
- 断った値を表示も保存もしません
- 自分のスナップショットのほかは何も消しません。消すのは、消すよう頼まれたプロジェクトのスナップショットと、7日より前のスナップショットだけです

## 環境変数

| 変数 | 用途 |
|---|---|
| `SESSION_HANDOFF_HOME` | スナップショットを置く場所 |
| `SESSION_HANDOFF_NOW` | 検査で使う固定の時刻。1970年からの秒数です |
