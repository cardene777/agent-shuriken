# Repo Progress

作業しているリポジトリ全部の状態を1つの表で見せます。動いている物、開いたIssueを抱えたまま止まっている物、もう終わった作業を指したままのworktreeが分かります。

[English](README.md) · 日本語

たくさんのリポジトリを並行して進めていると、状態があちこちに散らばります。
開いているIssueとプルリクエストはGitHubにあり、worktree、コミットしていない変更、最後のコミットは手元の各クローンにあります。
このプラグインは、プロジェクトのフォルダの下にある、あなたのコミットを含むクローンを全部読み、開いているIssueとプルリクエストをGitHubに尋ね、1つの表にまとめます。開いたIssueを抱えたまま長く止まっているリポジトリほど上に並びます。
リポジトリ、ブランチ、worktree、Issueは一切変えません。

```
クローンを探す ──> gitとGitHubを読む ──> 表を見せる ──> 1つのリポジトリを見せる
 (エージェント)     (エージェント)        (エージェント)   (頼まれた時にエージェント)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install repo-progress@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add repo-progress@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install repo-progress@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/repo-progress/skills/repo-progress   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「リポジトリ全体で、何をやりかけだった？」「止まっているプロジェクトはどれ？」のように、作業の状態を尋ねると始まります。
呼び出して始めることもできます。Claude Codeでは`/repo-progress:repo-progress`を実行し、Codexでは`$`を入力して**Repo Progress**を選びます。
GitHub Copilot CLIでは依頼の中に`/repo-progress`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントが、プロジェクトのフォルダの直下と1段下から、あなたのコミットを含むgitのクローンを探します
2. エージェントがクローンごとに1行の表を見せ、止まっている物、コミットしていない変更がある物、閉じたIssueを指したままのブランチをまとめます
3. 1つのリポジトリについて尋ねると、エージェントが進行中のブランチ、片付けるブランチとworktree、まだ誰も手を付けていない開いたIssueを並べます

表は次のようになります。

```text
repo            worktrees  issues  prs  uncommitted  idle  last commit  now
shop                    2      14    1            0   294  21 days ago  default branch
blog                    0       4    0            2    12   3 days ago  #1 Dark mode
clients/portal          0       6    0            0     0    0 min ago  default branch
dotfiles                0       ?    ?            0     ?  40 days ago  default branch

1 repository could not be measured and is listed last (idle is ?).
```

`idle`は、最後のコミットからの日数に開いているIssueの数を掛けた値です。開いたIssueが多く、最近の作業が無いリポジトリほど上に来ます。
`?`は、リモートがGitHubに無い、`gh`にサインインしていないなどの理由でGitHubに尋ねられなかったことを表します。0とは表示しません。

1つのリポジトリは次のようになります。

```text
acme/shop
  folder       shop
  branch       main
  uncommitted  0 files
  last commit  21 days ago

  [In progress]
    feat/1-partial-refund                        #1 Refund partial orders  (pull request #31)

  [To clean up]
    fix/40-old-tax                               #40 is not an open issue

  [Waiting] 13 issues
    #2       2033-05-02 Task 2
    #3       2033-05-03 Task 3
    #4       2033-05-04 Task 4
    #5       2033-05-05 Task 5
    #6       2033-05-06 Task 6
    #7       2033-05-07 Task 7
    #8       2033-05-08 Task 8
    #9       2033-05-09 Task 9
    #10      2033-05-10 Task 10
    #11      2033-05-11 Task 11
    #12      2033-05-12 Task 12
    #13      2033-05-13 Task 13
    #14      2033-05-14 Task 14
```

## プロジェクトのフォルダ

設定が無い時は、ホームフォルダにある`~/projects`、`~/code`、`~/src`、`~/Developer`、`~/Desktop/projects`のようなよく使われるフォルダを探します。
リポジトリを別の場所に置いている時は、そのフォルダをエージェントに伝えると、次からも使えるように保存します。
`git config --global`の`user.name`か`user.email`でのコミットがあるリポジトリを、あなたのリポジトリとして数えます。仕事で使う名前など、別の作者を指定することもできます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に |
| `git` | 常に |
| `gh` | 開いているIssueとプルリクエストを数える時に、GitHubにサインインした状態で使います。無ければその列が`?`になり、ほかはそのまま動きます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、リポジトリの探し方、ブランチの分け方、`idle`の値の出し方を載せています。
要点は次のとおりです。

- プロジェクトのフォルダの下にあるクローンのgitの情報(コミット、ブランチ、worktree、コミットしていない変更があるファイル)を読みます。ファイルの中身は読みません
- GitHubのリポジトリごとに`gh issue list`と`gh pr list`を1回ずつ動かします。あなた自身の`gh`のサインインで、リポジトリの名前をGitHubに送ります
- リポジトリ、ブランチ、worktree、Issueは一切変えません
- 保存したフォルダだけを`~/.local/share/repo-progress/roots`に置き、あなただけが読めるようにします。消すまで残ります

## ライセンス

[MIT](LICENSE)
