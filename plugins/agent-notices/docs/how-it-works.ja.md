# Agent Noticesの仕組み

[English](how-it-works.md) · 日本語

Claude CodeとCodexは、シェルの命令、編集、Grep、スキルの呼び出し、MCPの呼び出しの後と、会話の始めと終わりに各フックを動かし、出来事をJSONで標準入力に渡します。
知らせることがあるフックは、エージェントが呼び出しの後に読む`additionalContext`を持つJSONを1つ出し、無ければ何も出しません。
拒否、確認、ブロック、停止は決して出さず、出来事を読めなくても0で終わるので、呼び出しは常にエージェント自身の決まりのとおりに進みます。
全てのフックは1つのPythonのファイル`hooks/lib/agent_notices.py`を共有し、各`hooks/<name>.sh`がフックの名前を付けてそれを動かします。

## 編集の読み方

| 呼び出し | ファイル | 足した文 | 消した文 |
|---|---|---|---|
| Write | `file_path` | `content` | 無し |
| Edit | `file_path` | `new_string` | `old_string` |
| MultiEdit | `file_path` | 全ての`new_string` | 全ての`old_string` |
| Codexの`apply_patch` | 作業フォルダから数えた`*** Add File:`、`*** Update File:`、`*** Move to:`の各path | `+`で始まる行 | `-`で始まる行 |

消したファイルは飛ばします。
コードを見るフックは足した文を読むので、編集の前からファイルに在った行では知らせません。

## pipefail-grep

`.sh`、`.bash`、`.zsh`、`.ksh`で終わるか、シェルの`#!`の行で始まる編集したファイルを見ます。
ファイルに`pipefail`を含む`set`の行がある時、編集で足した行のうち、`-q`、`--quiet`、`--silent`付きの`grep`へ流す行を名指します。
`grep -q`は最初に当たった所で読むのをやめ、その前の命令がSIGPIPEで終わることがあり、`pipefail`のため文字が見つかってもパイプが失敗します。

## nohup

命令を、引用符の中の文を除いて読みます。
`nohup`で命令を始め、`disown`か、命令を裏へ回す`&`もある時に知らせます。
`&&`、`2>&1`、`>&2`、`&>`、`|&`の`&`は数えません。

## grep-binary

Claude CodeのGrepが何も見つけなかった後、探した所を`.git`を飛ばして辿り、5000個までのファイルを読みます。
最初の8 KiBにNULのバイトがあるファイルをバイナリとし、その最初の16 MiBから語を探します。
語を持つバイナリのファイルを5個まで名指します。

## branch

`git switch`、`git checkout`、`git commit`を含むシェルの命令を、`;`、`&&`、`||`、`|`、改行で切って読みます。
gitの命令の前の`git -C <folder>`と`cd <folder>`を辿ってリポジトリを決めます。

| 命令 | 知らせる時 |
|---|---|
| `git switch <branch>`、`git switch -c <branch>`、`git checkout <branch>`、`git checkout -b <branch>` | 命令の後、リポジトリが別のブランチか、切り離したHEADに居る |
| `git commit` | リポジトリが、その会話がそのリポジトリで最後に切り替えたのと違うブランチに居る |

`--`付きや、ブランチでない名前の`git checkout`はファイルの取り出しで、切り替えではありません。
会話が最後に切り替えたブランチは、会話とリポジトリごとに`~/.local/share/agent-notices/branches/`に残し、7日より古い記録は消します。

## env-example

編集で足した文が環境から読む名前のうち、消した文が読んでいた名前を除いた物を読みます。

| 言語 | 読む形 |
|---|---|
| JavaScriptとTypeScript | `process.env.NAME`、`process.env["NAME"]`、`import.meta.env.NAME`、`Deno.env.get("NAME")`、`Bun.env.NAME` |
| Python | `os.environ["NAME"]`、`os.environ.get("NAME")`、`os.getenv("NAME")` |
| Go | `os.Getenv("NAME")`、`os.LookupEnv("NAME")` |
| Ruby | `ENV["NAME"]`、`ENV.fetch("NAME")` |
| Rust | `env::var("NAME")`、`env::var_os("NAME")`、`env!("NAME")`、`option_env!("NAME")` |

例のファイルは、リポジトリの一番上にある`.env.example`、`.env.sample`、`.env.template`と、`.env.local.example`のように別の部分を持つ同じ形の名前のファイルです。
`NAME=`や`# NAME=`のように、説明にした行かどうかに関わらず名前を設定する行があれば、その名前は載っているとします。
例のファイルが無いリポジトリでは知らせず、`NODE_ENV`、`PATH`、`HOME`、`USER`、`PWD`、`SHELL`、`TMPDIR`、`TEMP`、`TMP`、`LANG`、`CI`、`TZ`は名指しません。

## tmp-space

シェルの命令のたびに、`TMPDIR`か、設定が無ければシステムの一時ディレクトリの空きを読みます。
空きが`AGENT_NOTICES_TMP_MIN_GB`ギガバイト (既定は5) を下回る間、知らせます。

## security

手を加えずに写したAnthropicのファイル`hooks/lib/security_guidance/patterns.py`から`SECURITY_PATTERNS`を読み、上流のフックと同じやり方で編集したファイルを見ます。
`path_filter`を持つ型は、それが受け入れるpathにだけ当てます。
型は、`path_check`がpathを受け入れた時、`substrings`のどれかが足した文に在る時、`regex`が足した文に当たった時に当たります。
当たった型ごとに、その`reminder`を5つまで付けます。
モデルは呼ばず、どこにも繋ぎません。

## format

編集したファイルごとに、ファイルのフォルダからリポジトリの一番上まで辿り、READMEの表のとおり、設定が整形の道具を名指す最初のフォルダを選びます。
そのフォルダで20秒の上限を付けて道具を回し、出力は捨てます。
ファイルの中身が変わった時は、古い文を引く編集が失敗するので、読み直すようにエージェントに知らせます。
名指されていても入っていない道具は飛ばします。
何も入れず、`npx`は決して動かしません。

## edit-loop

編集のたびに、上の表のとおり読んだ、編集が変えたファイルごとの回数に1を足し、`~/.local/share/agent-notices/edit-loop/`の下の会話の回数のファイルに残します。
ファイルの名前は会話のIDのハッシュで、中身はファイルの実のパスから回数への1つのJSONです。
回数が`AGENT_NOTICES_EDIT_LOOP_EVERY` (既定は5) の倍数になると、ファイルと回数をエージェントに知らせ、次の直しの前に失敗を再現する命令を書いて根本原因を確かめるように言います。
`AGENT_NOTICES_EDIT_LOOP_SKILL=<スキル>`を置くと、知らせはそのスキルでそうするように言います。英数字、`_`、`:`、`.`、`-`以外を含む値は使いません。
gitが無視するファイルと、Pythonが示す一時ディレクトリ (`TMPDIR`が在ればそれ、無ければ`/tmp`) のファイルには知らせません。下書きであって作業の本体ではないからです。gitが無視するかは、回数が知らせに届いた時だけ、ファイルのフォルダで`git check-ignore`を回して確かめます。
別の会話の編集は、別の回数のファイルに数えます。

## sequential

`CLAUDECODE=1`がフックの環境に在るClaude Codeで、全ての道具の呼び出しの後に動きます。ほかのエージェントでは何もせず、`AskUserQuestion`と`ExitPlanMode`の後も何もしません。
1つずつ続いた呼び出しの数と、最後の呼び出しの時刻を、`~/.local/share/agent-notices/sequential/`の下の、会話のIDのハッシュを名前にした会話の回数のファイルに残します。
最後の呼び出しから200ミリ秒未満の呼び出しは、同じ返答でまとめて出た呼び出しとして、数を0に戻します。
500ミリ秒以上後の呼び出しは新しい返答として1を足し、その間の呼び出しは数をそのままにします。
数が`AGENT_NOTICES_SEQUENTIAL_AFTER` (既定は10) に届くと、互いの結果を要らない呼び出しを1つの返答にまとめるようにエージェントに知らせ、0に戻します。
回数のファイルは鍵を掛けて読み書きするので、同時に終わった2つの呼び出しが数を取りこぼしません。

どちらのフォルダもあなただけが読め、回数のファイルは600の権限で作り、7日より古い回数のファイルは次に書く時に消します。

## presence

`SessionStart`で、`CLAUDE_CLIENT_PRESENCE_FILE`が名指すファイルをフォルダごと作るか、時刻を新しくします。
`SessionEnd`で、そのファイルを消します。
変数が無ければ何もしません。

## skill-logとmcp-log

`PreToolUse`で、呼び出しの始めの時刻を、呼び出しの`tool_use_id`をキーにして`~/.local/share/agent-notices/pending/`に残します。
`PostToolUse`か`PostToolUseFailure`で、終わりの時刻、かかった時間、呼び出しが成功したかを表す`ok`を持つ1行を書き、始めの時刻を消します。
スキルのログはSkillの呼び出しの`skill`から名前を取り、MCPのログは`mcp__<server>__<tool>`をサーバーと道具に分けます。
フォルダはあなただけが読め、ファイルは600の権限で作り、1 MBを超えたファイルは次の行の前に`.1`へ移します。

## フックが判断できない時

出来事を読めないフックや、判断の途中で失敗したフックは、何も出さずに0で終わります。
Python 3が無いと、全てのフックが何もしません。
READMEのとおり、各フックは自分の変数を`off`にすると外れ、2つのログは自分の変数を`on`にすると動きます。

## 限り

- nohupとbranchのフックは、エージェントが送る命令の文だけを見ます。命令が動かすスクリプトは読みません
- env-exampleのフックは各言語のよくある形を読みます。動かす時に組み立てる名前は見つけません
- grep-binaryのフックは語をPythonの正規表現として読みます。ripgrepの多くの形に当たりますが、全てではありません
- sequentialのフックは、まとめた呼び出しと1つずつの呼び出しを間の時間だけで見分けます。このため、いくつかの呼び出しを持つ返答の最初の呼び出しは1つだけの呼び出しに数えます。シェルの命令で書いた編集は、edit-loopが数えません
