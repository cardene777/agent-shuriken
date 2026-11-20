# Repo Progressの仕組み

[English](how-it-works.md) · 日本語

このページでは、リポジトリの探し方、各列の意味、ブランチの分け方、プラグインが残す物を説明します。
ここに書いたことは全部`skills/repo-progress/scripts/repo_progress.py`が行い、Pythonの標準ライブラリ、`git`、`gh`だけを使います。

## どのリポジトリを読むか

起点のフォルダごとに、その直下のフォルダと、さらに1段下のフォルダを見て、gitのクローンだけを残します。
クローンの中は探さず、隠しフォルダと、元のクローンの下に表示するworktreeも飛ばします。

起点のフォルダは、次のうち最初に設定されている物を使います。

| 出どころ | 例 |
|---|---|
| コマンドの`--root`。何度でも書けます | `--root ~/work --root ~/oss` |
| 環境変数`REPO_PROGRESS_ROOTS`。`:`で区切ります | `REPO_PROGRESS_ROOTS=~/work:~/oss` |
| `--save-roots`で保存した一覧 | `~/.local/share/repo-progress/roots` |
| ホームフォルダにある、よく使われるフォルダ | `projects`、`code`、`src`、`dev`、`Developer`、`repos`、`workspace`、`work`、`git`、`Documents/GitHub`、`Desktop/projects`、`Desktop/work` |

どれかのブランチに、作者があなたの名前かメールアドレスに一致するコミットがあるクローンだけを並べます。照合は`git log --author`で、文字列のまま比べます。
名前とメールアドレスは`git config --global`の`user.name`と`user.email`から取り、`--author`か`REPO_PROGRESS_AUTHOR`があればそちらを使います。
どれも無い時は、全部のクローンを並べることも1つも並べないこともせず、終了コード2で止まります。

## 列

| 列 | 測り方 |
|---|---|
| `repo` | 起点のフォルダから見たクローンのフォルダです。同じリポジトリを2か所にクローンしていても別の行になります |
| `worktrees` | `git worktree list`の項目の数から、クローン自身を除いた数です |
| `issues` | `gh issue list --state open`で取る開いたIssueの数です。500件までです |
| `prs` | `gh pr list --state open`で取る開いたプルリクエストの数です。200件までです |
| `uncommitted` | `git status --porcelain`の行の数で、変更があるファイルとgitが追跡していないファイル1つにつき1行です |
| `idle` | 今のブランチの最後のコミットからの日数(端数は切り捨て)に`issues`を掛けた値です |
| `last commit` | 今のブランチの最後のコミットからの時間です |
| `now` | 今のブランチの分け方で、次の節に書いたとおりです |

行は`idle`の大きい順に並びます。
開いたIssueが無いリポジトリと、今日コミットしたリポジトリは0になります。終わっているか、動いているかのどちらかだからです。
`idle`は大事さを測っていません。gitにもGitHubにも、リポジトリがどれだけ大事かの記録が無いためです。

`gh`には、同じリポジトリを何か所にクローンしていてもGitHubのリポジトリごとに1回だけ尋ね、最大8つのリポジトリを同時に尋ねます。
どのリポジトリかはリモート`origin`で決まり、GitHub以外のホストにあるリモートはホスト名を付けて`gh`に渡します。

## GitHubに尋ねられない時

`gh`が無い、サインインしていない、失敗した、リモートがGitHubに無い時は、`issues`、`prs`、`idle`が`?`になり、`--json`は`null`を出します。
0とは表示しません。開いたIssueを0件とすると、番号の付いたブランチが全部終わった扱いになり、作業中の物を片付けるよう案内してしまうためです。
こうしたリポジトリはほかの後に並び、表の下の1行がその数を示します。

## ブランチの分け方

ブランチの名前が`<接頭辞>/<番号>-<言葉>`、`<番号>-<言葉>`、`issue-<番号>`の形の時、そのブランチはIssueを指していると見ます。例えば`feat/12-login`です。

| 分類 | 当てはまる時 |
|---|---|
| 進行中(In progress) | 開いたIssueを指しているか、Issueの番号が無いブランチです |
| 片付け(To clean up) | 開いていないIssueを指しているブランチと、フォルダが無くなったworktree(`prunable`)です |
| 不明(Unknown) | Issueを指しているが、開いたIssueを読めなかったブランチです |
| 表示しない | `main`、`master`、`develop`、`trunk`、`origin/HEAD`が指すブランチなどの既定のブランチです |

開いたIssueの一覧に無い番号は、閉じたか存在しないかのどちらかで、どちらもそのブランチの作業は終わっています。そのため番号ごとには尋ねません。
`--repo`は、クローンと全worktreeのブランチをこの分類で並べ、そのブランチから開いたプルリクエストも添えます。
待ち(Waiting)は、進行中のブランチがどれも指していない開いたIssueです。同じIssueを2回数えません。
worktreeの無い手元のブランチは並べません。古いブランチは溜まる一方で、進行中の作業を表さないためです。

## 残す物

| 何を | どこに | いつまで |
|---|---|---|
| `--save-roots`で保存した起点のフォルダ | `~/.local/share/repo-progress/roots`。あなただけが読めるフォルダに置きます。`REPO_PROGRESS_HOME`があればその下に置きます | 消すか、別の一覧を保存するまで |

ほかには何も書きません。
出力は端末にだけ出ます。

## しないこと

- リポジトリを変えません。動かすのは`git log`、`git status`、`git branch --show-current`、`git worktree list`、`git remote get-url`、`git symbolic-ref`と、名前を読むための`git config --global`だけです
- ファイルの中身を読みません
- ブランチやworktreeを消したり動かしたりせず、Issueとプルリクエストも変えません
- 開いたIssueとプルリクエストを並べるために`gh`が使うリポジトリの名前のほかは、何も送りません

## 環境変数

| 変数 | 用途 |
|---|---|
| `REPO_PROGRESS_ROOTS` | 起点のフォルダ。`:`で区切ります |
| `REPO_PROGRESS_AUTHOR` | あなたのリポジトリと見なす作者 |
| `REPO_PROGRESS_HOME` | 保存した起点のフォルダを置く場所 |
| `REPO_PROGRESS_GH` | 検査で`gh`の代わりに使う命令 |
| `REPO_PROGRESS_NOW` | 検査で使う固定の時刻。1970年からの秒数です |
