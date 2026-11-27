# Agent Guards

Claude CodeとCodexで、エージェントが鍵のファイルを読むか上書きする、1Passwordに控えた値を出す、鍵をGitHubへ送る、強制pushを打つ、ホームのフォルダを消す、デスクトップが動くのに要るプロセスを止める、の手前で止めるフックです。

[English](README.md) · 日本語

シェルの命令を代わりに打つエージェントは、設定を探す途中で`~/.ssh/id_ed25519`や`.env`を読み、読んだ物をIssueに貼り、断られたpushを通すために`git push --force`を打ち、空白を1つ間違えて`rm -rf ~ /tmp/build`を打つことがあります。
どれも命令1つで起き、打った後には戻せません。
このプラグインは、エージェントが打つ全てのシェルの命令と、全てのファイルの読み取りと書き換えの前に動くフックを6つ足し、こうした命令を、エージェントが次の手を決められる理由を付けて断ります。
3つのフックは同じプロセスの中で2つ以上の検査を回すので、12の検査が起動するプロセスは6つのフックの分だけです。
フックは命令を許可しません。
断らなかった命令は、今までどおりエージェントの許可の決まりへ進みます。

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install agent-guards@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add agent-guards@agent-shuriken
```

フックは次の会話から動きます。
Codexは、信用したプラグインのフックだけを動かします。
Codexの会話で`/hooks`を開き、agent-guardsの8つのフックを信用してください。
更新でフックが変わると、Codexはそのフックを変更済みにして止めるので、`/hooks`でもう一度信用してください。

## 各検査が断る物

各検査は自分の変数で外れます。
括弧でほかの検査の名前を添えた検査は、そのフックの中で動きます。

| 検査 | 断る物 | 通す物 | 外す変数 |
|---|---|---|---|
| 秘密の読み取り | `.env`のファイル、秘密鍵、`.pem`と`.key`のファイル、`secrets`フォルダの中のファイル、`~/.aws/credentials`や`~/.npmrc`や`~/.netrc`のような認証のファイル、シェルの履歴、macOSのアプリの個人データ (キーチェーン、メッセージ、メール、カレンダー、Safari、Cookie、Chrome、Firefox、1Password、連絡先)、Claude Codeの会話の記録を、シェルの命令でもRead toolでも読むこと。読むファイルが変数や命令の置き換えから来る読み取りも断ります | `.env.example`、`.env.sample`、`.env.template`、`.env.test`、公開鍵、そのほかの全てのファイル | `AGENT_GUARDS_SECRET_READ=off` |
| 秘密の書き込み | 同じ秘密のファイルと`secret-paths`の一覧の置き場に、`>`、`>>`、`tee`、`cp`、`mv`、`sed -i`、`truncate`、`dd`で書くこと、Claude CodeのWrite、Edit、MultiEdit、NotebookEditのtoolで書くこと、それらを足す、直す、移す、消すCodexのパッチ。これらのファイルはgitに無いので、上書きすると戻せません | `.env.example`とそのほかの全てのファイルへの書き込み、書く先が変数から来る書き込み | `AGENT_GUARDS_SECRET_WRITE=off` |
| 1Password | 1PasswordのCLIの`op`の命令のうち、控えた値を出せる物。例えば`op read`、`op item get`、`op document get`、`op run`、`op inject`、`op signin`と、項目を作るか消す命令。`bash -c`と`$(...)`の中も見ます | `op whoami`、`op account list`、`op vault list`、`op item list`、`op document list`、`op document create`、`op document edit`、`op --version`、`op help`。`.env`を読まずに1Passwordへ控えられます | `AGENT_GUARDS_ONEPASSWORD=off` |
| 外へ送る文 | `gh issue`、`gh pr`、`gh release`、`gh gist`、`gh api`の命令と`git commit`で、命令の行か本文のファイルかステージした変更に、GitHub、AWS、Anthropic、OpenAI、Google、Slack、Stripeの鍵や秘密鍵の塊やURLの中のパスワードのような鍵の形の値が在るもの。鍵の種類と行を出し、値は出しません。`--body "$(cat file)"`や`--body -`のように読めない本文も断り、`--body-file <path>`の形を示します | 鍵の形の値が無い文 | `AGENT_GUARDS_OUTBOUND=off` |
| git | `git push --force`とその別の形、`git reset --hard`、`--no-verify`、`git clean -f`、`git checkout -- .`、`git restore`など、コミットしていない変更を捨てる形 | 普通のpush、ブランチの切り替え、`git clean -n`、`git restore --staged`、そのほかの全てのgitの命令 | `AGENT_GUARDS_GIT=off` |
| 削除 | ルート、ホームのフォルダ、今のフォルダ、最上位のシステムのフォルダ、`*`に対する`rm -r`と`mv`、それらに対する`-delete`付きの`find`、それらに対する`chmod -R`と`chown -R`と`chgrp -R`。権限を変えると、消した時と同じくフォルダに入れなくなることがあります | 名指したファイルやフォルダの削除と権限の変更、例えば`rm -rf ./build`と`chmod -R 755 ./build` | `AGENT_GUARDS_DELETE=off` |
| ハードリンク (秘密の書き込み) | 別名 (ハードリンク) を持つファイルへの、file tool、Codexのパッチ、`>`、`tee`、`cp`、`truncate`、`dd`での書き込み。害の無い名前から、別の名前の鍵のファイルを上書きできるため | 名前が1つのファイル、新しいファイル、名前を置き換える`mv`と`ln`と`sed -i` | `AGENT_GUARDS_HARD_LINKS=off` |
| 起動ファイルの鍵 (秘密の書き込み) | 鍵のような名前 (`_KEY`、`_TOKEN`、`_SECRET`、`_PASSWORD`で終わる) の変数にそのまま書いた値か、鍵の形の値を、`.zshrc`、`.bashrc`、`.profile`、fishの設定などのシェルの起動ファイルへ書くこと。dotfilesのフォルダとchezmoiの元の名前も含み、file tool、Codexのパッチ、`echo ... >> ~/.zshrc`のような命令で書く物を見ます。ファイルと変数を出し、値は出しません | `"$(security find-generic-password -s NAME -w)"`のように起動の時に読む値、`REPLACE_ME`のような置き換え用の値、そのほかの全ての行 | `AGENT_GUARDS_STARTUP_KEYS=off` |
| チェーン (外へ送る文) | 送り先が`127.0.0.1`、`localhost`、`::1`でないか読めない、`cast send`、`cast publish`、`cast rpc`と`cast erc20-token`の送る形、`forge script --broadcast`、`forge create`、`hardhat ignition deploy` | このPCのチェーンへの同じ命令と、`cast call`のような読むだけの命令 | `AGENT_GUARDS_CHAIN=off` |
| 他人のリポジトリ (外へ送る文) | `own-owners`の一覧が在る時に、一覧に無い持ち主のリポジトリへ`gh`か`gh api`で送るissue、pull request、コメント、レビュー、題と本文の書き換えと、そうしたリポジトリへの`git push`と、GraphQLのmutationと、変数で渡したリポジトリ | 自分の持ち主への送信、読むだけの命令、ラベルの変更、一覧が無い時の全ての送信 | `AGENT_GUARDS_OTHER_REPOS=off` |
| システム (削除) | `mount`、`umount`、`chroot`、`pfctl`、`mkfs`と、管理者の権限でシェルのスクリプトを走らせる`osascript`。`sudo`と`bash -c`の後ろも見ます | `grep mount notes.txt`のように引数に在るだけの同じ名前と、ほかの`osascript`のスクリプト | `AGENT_GUARDS_SYSTEM=off` |
| プロセス (削除) | PID 1、PID 0、`-1`のような負のPIDへの`kill` (`-1`は全てのプロセスに信号を送ります)。`ps`がlaunchd、WindowServer、Finder、systemd、sshdのようなシステムのプロセスと答えるPIDへの`kill`。システムのプロセスの名前か、`pgrep`がそれに当てるパターンへの`pkill`と`killall`。ユーザーだけでプロセスを選ぶ`pkill`と`killall`。`Terminal`、`iTerm2`、ghostty、konsoleのような、エージェント自身の窓を閉じるターミナルのアプリを止める命令。`kill $PID`や`kill $(pgrep -f node)`のように変数か命令の置き換えから来る対象。`sudo`と`bash -c`の後ろも見ます | `2>&1`のようなリダイレクトを付けた物も含む、ほかのPIDへの`kill`、`kill $!`、`kill %1`、どの対象への`kill -0`の確かめ、システムのプロセスに当たらないパターンへの`pkill -f`、`killall node` | `AGENT_GUARDS_PROCESSES=off` |

断ったgit、削除、システム、プロセス、チェーン、他人のリポジトリの命令は、先頭に`!`を付けた同じ命令と一緒に返るので、本当に打つ時は自分で打てます。
Claude Codeでは、先頭に`!`を付けて打った行は本人の命令としてシェルで動きます。
Codexでは、その命令を端末で打ちます。

変数は、Claude Codeでは`~/.claude/settings.json`の`env`に、Codexではシェルの起動ファイルに書きます。

## 自分の置き場

2つの一覧のファイルで、このPCの置き場を足せます。
3つ目の一覧のファイルには、自分の物であるGitHubの持ち主を書きます。
置き場の一覧には、1行に1つの置き場を書きます。
`~/`で始まる行はホームのフォルダから数え、`/`を含まない行はどこに在ってもファイルの名前で当て、`#`で始まる行は説明として読み飛ばします。
ファイルが無ければ何も足しません。

| ファイル | 働き |
|---|---|
| `~/.config/agent-guards/secret-paths` | 置き場の中身ごと、読み取りと書き込みを断ります |
| `~/.config/agent-guards/protected-paths` | 置き場の中身ごと、削除と移動と`chmod -R`と、コピーやリンクや`tee`や`dd`やリダイレクトでの上書きと、`git rm`を断ります。そこから読むことと、エージェント自身のfileの道具での書き込みは通します |
| `~/.config/agent-guards/own-owners` | 各行に自分の物であるGitHubのユーザーか組織を書き、ほかの持ち主のリポジトリへの送信を断ります。無ければ、送り先で断る送信はありません |

```
# ~/.config/agent-guards/secret-paths
~/Documents
~/work/keys
*.dump
```

```
# ~/.config/agent-guards/own-owners
your-github-name
your-organization
```

`XDG_CONFIG_HOME`を設定していると、ファイルは`$XDG_CONFIG_HOME/agent-guards/`に置きます。

## 記録

フックは既定では何も書きません。
`AGENT_GUARDS_RECORD=on`にすると、断るたびに、時刻、フック、断った種類の1行を`~/.local/share/agent-guards/refusals.log`に足します。
その行は命令も値も持ちません。

## 必要な物

| 必要な物 | 使う所 |
|---|---|
| Python 3 | 全てのフック。無いと、全てのフックが毎回断り、Python 3を入れるかフックを外すように言います |
| `bash` | フックの起動 |
| `git` | コミットでステージした変更と、`gh`の送信かpushを打つクローンのリモートの読み取り |
| `ps`と`pgrep` | `kill`、`pkill`、`killall`が名指すプロセスを調べる。無いと、それらの命令はエージェントの許可の決まりへ進みます |

## 読む物と動かす物と送る物

- Claude CodeやCodexがシェルの命令とファイルの読み取りと書き換えの前に送る出来事、`gh`の命令が名指す本文のファイル、コミットの前のステージした変更と`git add`が名指すファイル、書き込みが名指す各ファイルの名前の数、3つの一覧のファイルを読みます
- コミットのリポジトリで`git rev-parse`、`git diff`、`git ls-files`を動かし、`gh`の送信かpushを打つクローンでリモートを読むために`git config`、`git symbolic-ref`、`git remote get-url`を動かし、`kill`、`pkill`、`killall`が名指すプロセスを調べるために`ps`と`pgrep`を動かし、ほかは何も動かしません
- どこにも何も送りません。`AGENT_GUARDS_RECORD=on`にしない限り何も残しません
- フックを持つプラグインはOpenAIのプラグインの公式ディレクトリに載せられないので、載せていません。このマーケットプレイスから入れます

各フックが従う決まりは[仕組み](docs/how-it-works.ja.md)にあります。

## ライセンス

MIT
