# Agent Guardsの仕組み

[English](how-it-works.md) · 日本語

Claude CodeとCodexは、シェルの命令とファイルの読み取りと書き換えの前に各フックを起動し、呼び出しをJSONで標準入力に渡します。
フックは、断る時は理由を付けた拒否の判断を出し、断らない時は何も出しません。
許可の判断は出さないので、断らなかった呼び出しも、エージェント自身の許可の決まりを通ります。
6つのフックは1つのPythonのファイル`hooks/lib/agent_guards.py`を使い、各`hooks/<name>.sh`がフックの名前を渡して起動します。

| フック | 動く時 | 外す変数 |
|---|---|---|
| `secret-read.sh` | シェルの命令とRead toolの前 | `AGENT_GUARDS_SECRET_READ=off` |
| `secret-write.sh` | シェルの命令、Write、Edit、MultiEdit、NotebookEditのtool、Codexの`apply_patch`の前 | `AGENT_GUARDS_SECRET_WRITE=off` |
| `onepassword.sh` | シェルの命令の前 | `AGENT_GUARDS_ONEPASSWORD=off` |
| `outbound.sh` | シェルの命令の前 | `AGENT_GUARDS_OUTBOUND=off` |
| `git.sh` | シェルの命令の前 | `AGENT_GUARDS_GIT=off` |
| `delete.sh` | シェルの命令の前 | `AGENT_GUARDS_DELETE=off` |

## 命令の読み方

フックは、シェルが分けるのと同じように命令を読みます。
`;`、`&&`、`||`、`|`、`&`、括弧、改行で命令を区切り、区切った1つずつを読みます。
先頭の変数の代入と、`sudo`、`doas`、`env`、`command`、`builtin`、`nohup`、`nice`、`time`、`timeout`、`exec`の語をそのオプションごと飛ばすので、`sudo rm -rf /`は`rm`として読みます。
値を取るオプションは値ごと飛ばすので、`sudo -u root rm -rf /`、`nice -n 10 rm -rf /`、`env -C /tmp rm -rf ~`も`rm`として読みます。
`env -S`の後の文字列は、envが分けるのと同じく、後に続く語として読みます。
`bash -c`、`sh -c`、`zsh -c`、`eval`の後の文と、`xargs`が走らせる命令と、`find`の`-exec`、`-execdir`、`-ok`、`-okdir`の後の命令と、`watch`が走らせる文は、3段まで別の命令として読みます。
引用符の外で始めたヒアドキュメントの本文は、命令として読みません。
`~`、`$HOME`、`${HOME}`はホームのフォルダにし、それ以外の変数と命令の置き換えは分からない物として残します。

## 秘密の読み取り

フックは、読む命令が受け取るファイルを見ます。
読む命令は`cat`、`head`、`tail`、`less`、`more`、`grep`、`rg`、`sed`、`awk`、`jq`、`cut`、`sort`、`diff`、`base64`、`source`とソースの中のほかの読む命令で、`<`の後のファイルと、`cp`、`scp`、`rsync`の元のファイルも見ます。
`grep`、`rg`、`sed`、`awk`、`jq`では、最初の語はファイルではなく検索の形かプログラムです。
`python`、`node`、`ruby`、`perl`、`php`、`bun`、`deno`では、`-c`か`-e`の後のコードの中の引用した文字列を見ます。
Read toolでは`file_path`を見ます。

| 秘密のファイルになる時 | 例 |
|---|---|
| 名前が`.env`か、`.env.`で始まる。ただし`.example`、`.sample`、`.template`で終わる名前と`.env.test`は除く | `.env`、`.env.local`、`.env.production` |
| 秘密鍵か、`.pem`、`.key`、`.p12`、`.pfx`、`.token`、`.secret`、`.private`で終わる | `id_ed25519`、`server.pem` |
| 名前に`_token`か`_key`を含み、ソースコードではない | `api_token.txt`、`service_key.json` |
| `secrets`か`.secrets`という名前のフォルダの中に在る | `secrets/api.txt` |
| 認証のファイルかシェルの履歴 | `~/.aws/credentials`、`~/.npmrc`、`~/.netrc`、`~/.git-credentials`、`~/.docker/config.json`、`~/.kube/config`、`~/.pgpass`、`~/.zsh_history`、`~/.config/gcloud/`と`~/.azure/`と`~/.gnupg/`の中のファイル |
| macOSのアプリの個人データ | `~/Library`の`Keychains`、`Messages`、`Mail`、`Calendars`、`Safari`、`Cookies`、`Group Containers`の中のファイルと、`~/Library/Application Support`のChrome、Firefox、1Password、連絡先のフォルダ |
| Claude Codeの会話の記録 | `~/.claude/history.jsonl`、`~/.claude/projects/*/*.jsonl` |
| `secret-paths`の一覧に在る | `~/Documents` |

読む命令のファイルが`cat "$FILE"`や`cat $(find . -name '*.key')`のように変数か命令の置き換えの時は、何を読むか分からないので断ります。
`xargs`が読む命令にファイルを渡す時は、命令のどれかの語が秘密のファイルなら断ります。
`find -exec`が見つけたファイルを`{}`で読む命令に渡す時は、`find . -name .env -exec cat {} \;`のように`find`の命令のどれかの語が秘密のファイルなら断ります。

## 秘密の書き込み

フックは、秘密の読み取りのフックが秘密と数えるファイルへの書き込みを断ります。
`secret-paths`の一覧の置き場も含みます。
これらのファイルはgitに無いことが多く、上書きすると戻せません。

| 所 | 見る物 |
|---|---|
| シェルの命令 | `>`、`>>`、`>\|`、`&>`、`>&`の後のファイル、`tee`が書くファイル、`cp`、`mv`、`install`、`ln`、`rsync`、`scp`の最後のファイル、`sed -i`と`perl -i`のファイル、`truncate`のファイル、`dd`の`of=` |
| Write、Edit、MultiEditのtool | `file_path` |
| NotebookEditのtool | `notebook_path` |
| Codexの`apply_patch` | パッチの中の`*** Add File:`、`*** Update File:`、`*** Delete File:`、`*** Move to:`の後のファイル |

`2>&1`のように出力を別の出力へ向ける形はファイルではありません。
`echo x > "$OUT"`のように書く先が変数か命令の置き換えから来る書き込みは通します。
そうしたファイルは、秘密のファイルよりも一時のファイルであることがずっと多いためです。

## 1Password

フックは、1PasswordのCLIの全ての`op`の命令を読みます。
`&&`、`;`、パイプの後と、`bash -c`と`eval`の中と、`$(...)`とバッククォートの中も読みます。
1Passwordに控えた値を出さず、何も消さない命令だけを通します。

| 通す物 | 理由 |
|---|---|
| `op whoami`、`op account list`、`op vault list`、`op item list`、`op document list` | 名前とIDを出し、控えた値は出さない |
| `op document create`、`op document edit` | `.env`のようなファイルを、中身を出さずに控える |
| `op --version`、`op help`、`op`だけ | CLI自身の文を出す |

ほかの`op`の命令は全て断ります。
値は多くの命令と指定から出るためです。
例えば`op read`、`op item get` (`--reveal`のほか`--format json`、`--otp`、`--share-link`でも出す)、`op document get`、`op run`、`op inject`、セッションのトークンを出す`op signin`です。
`op item create`と`op item edit`も断ります。
命令の行に書いた値が会話に残るためです。
消す命令は、保管庫の項目を消すので断ります。
命令を読む前に、全体の指定`--account`、`--config`、`--encoding`、`--format`、`--session`を値ごと飛ばします。
断った命令は先頭に`!`を付けた形で返しません。
自分で打った`!`の命令が出した値も会話に入るためで、エージェントの外の端末で打ってください。

## 外へ送る文

フックは、文を送るか記録する命令を見ます。
対象は、作る、コメントする、直す、レビューする、閉じる`gh issue`、`gh pr`、`gh release`、`gh gist`の命令と、全ての`gh api`の命令と、`git commit`です。
次の所に鍵の形の値が無いかを調べます。

| 所 | 読む物 |
|---|---|
| 命令の行 | 命令の全体。文と一緒に外へ出るため |
| 本文のファイル | `--body-file`、`-F`、`--notes-file`の後のファイル、`gh api`の`-F field=@file`と`--input`、`git commit -F` |
| コミット | ステージした変更、`-a`かpathを付けた時の作業中の変更、同じ命令の前の`git add`が名指すファイル |

| 鍵の形 | |
|---|---|
| 決まった前置きを持つトークン | GitHub、npm、Anthropic、AWS、GitLab、Google、Slack、Stripe、PyPI、Hugging Face、DigitalOcean、Shopify、Linear、Doppler、SendGrid、OpenAI |
| ほかの形 | 秘密鍵の塊、`Authorization`ヘッダーの中のパスワード、URLの中のパスワード |

決まった前置きを持つ形は、gitleaks (MIT) の既定の規則に倣っています。
断る時は鍵の種類とファイルと行を出し、値は出しません。
`--body "$(cat file)"`、`--body -`、変数で名指した本文のファイル、ほかの命令から作ったコミットの文のように読めない文は断り、`--body-file <path>`か`git commit -F <path>`の形を示します。
命令の中に書いたヒアドキュメントから作った文は、文が命令に在るので読みます。

## git

| 断る物 | 理由 |
|---|---|
| `--force`、`-f`、`--force-with-lease`、`--force-if-includes`、`+`の付いた参照を持つ`git push` | 遠くのブランチの履歴を上書きする |
| 全てのgitの命令の`--no-verify`と`git commit -n` | リポジトリの検査を飛ばす |
| `git reset --hard` | コミットしていない作業を捨てる |
| `-f`を持ち`-n`を持たない`git clean` | 追跡していないファイルを消す |
| `--`、`.`、`-f`、`--force`、`--discard-changes`を持つ`git checkout`と`git switch` | コミットしていない変更を捨てる |
| `--staged`を持たないか、`--worktree`を持つ`git restore` | コミットしていない変更を捨てる |

## 削除

| 断る物 | 例 |
|---|---|
| ルート、ホームのフォルダ、今のフォルダ、`..`、`*`、`/usr`や`/Users`のような最上位のシステムのフォルダに対する`rm -r`か`mv` | `rm -rf /`、`rm -rf ~`、`rm -rf .` |
| それらの置き場から始める`-delete`か`-exec rm`付きの`find`。今のフォルダから始める時は、`-name`、`-path`、`-regex`が在れば通す | `find / -delete` |
| `protected-paths`の一覧の置き場かその中に対する`rm`、`mv`、`rmdir`、`unlink`、`find -delete` | `rm ~/work/keep/a.txt` |
| それらの置き場か`protected-paths`の一覧の置き場に対する、`-R`か`--recursive`付きの`chmod`、`chown`、`chgrp`。木の全体から権限を外すと、消した時と同じく入れなくなるため。最初の語は権限か持ち主で、`-w`のような権限も権限として読む | `chmod -R 000 ~`、`chown -R nobody ~` |

## 判断できない時

出来事を読めないか判断の途中で失敗したフックは、黙って通さずに、呼び出しを断ってそう伝えます。
Python 3が無いと、各フックは毎回断り、Python 3を入れるかフックを外すように言います。
各フックは、冒頭の表のとおり、自分の変数を`off`にすると外れます。

## 限界

- フックが見るのは、エージェントが送る命令の文だけです。命令が動かすスクリプトのファイルは読まないので、`bash cleanup.sh`の中身は調べません
- ランダムなパスワードのように決まった前置きを持たない鍵の形は見つけません
- `printf`の出力を`sh`に渡すように、動かす時に作る命令は読みません
- 書く先が変数から来る書き込みは断りません。`python3 -c "open('.env', 'w')"`のように、プログラム自身のコードが書く物も読みません
