# Agent Guards

Claude CodeとCodexで、エージェントが鍵のファイルを読む、鍵をGitHubへ送る、強制pushを打つ、ホームのフォルダを消す、の手前で止めるフックです。

[English](README.md) · 日本語

シェルの命令を代わりに打つエージェントは、設定を探す途中で`~/.ssh/id_ed25519`や`.env`を読み、読んだ物をIssueに貼り、断られたpushを通すために`git push --force`を打ち、空白を1つ間違えて`rm -rf ~ /tmp/build`を打つことがあります。
どれも命令1つで起き、打った後には戻せません。
このプラグインは、エージェントが打つ全てのシェルの命令と全てのファイルの読み取りの前に動くフックを4つ足し、こうした命令を、エージェントが次の手を決められる理由を付けて断ります。
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
Codexの会話で`/hooks`を開き、agent-guardsの5つのフックを信用してください。
更新でフックが変わると、Codexはそのフックを変更済みにして止めるので、`/hooks`でもう一度信用してください。

## 各フックが断る物

| フック | 断る物 | 通す物 | 外す変数 |
|---|---|---|---|
| 秘密の読み取り | `.env`のファイル、秘密鍵、`.pem`と`.key`のファイル、`secrets`フォルダの中のファイル、`~/.aws/credentials`や`~/.npmrc`や`~/.netrc`のような認証のファイル、シェルの履歴、macOSのアプリの個人データ (キーチェーン、メッセージ、メール、カレンダー、Safari、Cookie、Chrome、Firefox、1Password、連絡先)、Claude Codeの会話の記録を、シェルの命令でもRead toolでも読むこと。読むファイルが変数や命令の置き換えから来る読み取りも断ります | `.env.example`、`.env.sample`、`.env.template`、`.env.test`、公開鍵、そのほかの全てのファイル | `AGENT_GUARDS_SECRET_READ=off` |
| 外へ送る文 | `gh issue`、`gh pr`、`gh release`、`gh gist`、`gh api`の命令と`git commit`で、命令の行か本文のファイルかステージした変更に、GitHub、AWS、Anthropic、OpenAI、Google、Slack、Stripeの鍵や秘密鍵の塊やURLの中のパスワードのような鍵の形の値が在るもの。鍵の種類と行を出し、値は出しません。`--body "$(cat file)"`や`--body -`のように読めない本文も断り、`--body-file <path>`の形を示します | 鍵の形の値が無い文 | `AGENT_GUARDS_OUTBOUND=off` |
| git | `git push --force`とその別の形、`git reset --hard`、`--no-verify`、`git clean -f`、`git checkout -- .`、`git restore`など、コミットしていない変更を捨てる形 | 普通のpush、ブランチの切り替え、`git clean -n`、`git restore --staged`、そのほかの全てのgitの命令 | `AGENT_GUARDS_GIT=off` |
| 削除 | ルート、ホームのフォルダ、今のフォルダ、最上位のシステムのフォルダ、`*`に対する`rm -r`と`mv`、それらに対する`-delete`付きの`find` | 名指したファイルやフォルダの削除、例えば`rm -rf ./build` | `AGENT_GUARDS_DELETE=off` |

断ったgitと削除の命令は、先頭に`!`を付けた同じ命令と一緒に返るので、本当に打つ時は自分で打てます。
Claude Codeでは、先頭に`!`を付けて打った行は本人の命令としてシェルで動きます。
Codexでは、その命令を端末で打ちます。

変数は、Claude Codeでは`~/.claude/settings.json`の`env`に、Codexではシェルの起動ファイルに書きます。

## 自分の置き場

2つの一覧のファイルで、このPCの置き場を足せます。
1行に1つの置き場を書きます。
`~/`で始まる行はホームのフォルダから数え、`/`を含まない行はどこに在ってもファイルの名前で当て、`#`で始まる行は説明として読み飛ばします。
ファイルが無ければ何も足しません。

| ファイル | 置き場がどうなるか |
|---|---|
| `~/.config/agent-guards/secret-paths` | 中身ごと、読み取りを断ります |
| `~/.config/agent-guards/protected-paths` | 中身ごと、削除と移動を断ります |

```
# ~/.config/agent-guards/secret-paths
~/Documents
~/work/keys
*.dump
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
| `git` | コミットでステージした変更の読み取り |

## 読む物と動かす物と送る物

- Claude CodeやCodexがシェルの命令とファイルの読み取りの前に送る出来事、`gh`の命令が名指す本文のファイル、コミットの前のステージした変更と`git add`が名指すファイル、2つの一覧のファイルを読みます
- コミットのリポジトリで`git rev-parse`、`git diff`、`git ls-files`を動かし、ほかは何も動かしません
- どこにも何も送りません。`AGENT_GUARDS_RECORD=on`にしない限り何も残しません
- フックを持つプラグインはOpenAIのプラグインの公式ディレクトリに載せられないので、載せていません。このマーケットプレイスから入れます

各フックが従う決まりは[仕組み](docs/how-it-works.ja.md)にあります。

## ライセンス

MIT
