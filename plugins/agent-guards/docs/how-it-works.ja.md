# Agent Guardsの仕組み

[English](how-it-works.md) · 日本語

Claude CodeとCodexは、シェルの命令とファイルの読み取りと書き換えの前に各フックを起動し、呼び出しをJSONで標準入力に渡します。
フックは、断る時は理由を付けた拒否の判断を出し、断らない時は何も出しません。
許可の判断は出さないので、断らなかった呼び出しも、エージェント自身の許可の決まりを通ります。
6つのフックは1つのPythonのファイル`hooks/lib/agent_guards.py`を使い、各`hooks/<name>.sh`がフックの名前を渡して起動します。
3つのフックは同じプロセスの中で2つ以上の検査を回すので、検査ごとにプロセスを起動しません。
各検査は自分の変数で外れ、検査が全て外れたフックはすぐに終わります。

| フック | 検査 | 動く時 | 外す変数 |
|---|---|---|---|
| `secret-read.sh` | 秘密の読み取り | シェルの命令とRead toolの前 | `AGENT_GUARDS_SECRET_READ=off` |
| `secret-write.sh` | 秘密の書き込み | シェルの命令、Write、Edit、MultiEdit、NotebookEditのtool、Codexの`apply_patch`の前 | `AGENT_GUARDS_SECRET_WRITE=off` |
| `secret-write.sh` | ハードリンク | 秘密の書き込みと同じ呼び出しの前 | `AGENT_GUARDS_HARD_LINKS=off` |
| `secret-write.sh` | 起動ファイルの鍵 | 秘密の書き込みと同じ呼び出しの前 | `AGENT_GUARDS_STARTUP_KEYS=off` |
| `onepassword.sh` | 1Password | シェルの命令の前 | `AGENT_GUARDS_ONEPASSWORD=off` |
| `outbound.sh` | 外へ送る文 | シェルの命令の前 | `AGENT_GUARDS_OUTBOUND=off` |
| `outbound.sh` | チェーン | シェルの命令の前 | `AGENT_GUARDS_CHAIN=off` |
| `outbound.sh` | 他人のリポジトリ | シェルの命令の前 | `AGENT_GUARDS_OTHER_REPOS=off` |
| `git.sh` | git | シェルの命令の前 | `AGENT_GUARDS_GIT=off` |
| `delete.sh` | 削除 | シェルの命令の前 | `AGENT_GUARDS_DELETE=off` |
| `delete.sh` | システム | シェルの命令の前 | `AGENT_GUARDS_SYSTEM=off` |

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

## ハードリンク

1つのファイルは、`ln`で作る別名 (ハードリンク) を持てます。
1つの名前から書くと全ての名前のファイルが変わるので、`notes.txt`のような害の無い名前から`.env`を上書きでき、名前だけでは中身が分かりません。
検査は、名前を2つ以上持つ普通のファイルへの書き込みを断ります。

| 所 | 見る物 |
|---|---|
| シェルの命令 | `>`、`>>`などの書き先のファイルと、名前の先のファイルへ書く`tee`、`cp`、`scp`、`truncate`、`dd`の`of=`が書くファイル |
| Write、Edit、MultiEdit、NotebookEditのtool | `file_path`と`notebook_path` |
| Codexの`apply_patch` | パッチが足すか変えるファイル |

`mv`、`ln`、`install`、`rsync`、`sed -i`、`perl -i`は名前を新しいファイルに置き換え、ほかの名前を元のまま残すので通します。
まだ無いファイルと、名前の数を読めないファイルは通し、シンボリックリンクは指す先のファイルで判断します。
断る時は、`cp`で名前が1つのファイルへ写し、そちらへ書くように言います。
Linuxのpnpmのように`node_modules`のファイルを共有の置き場へリンクする道具では、そこでの書き換えも断ります。

## 起動ファイルの鍵

検査は、シェルの起動ファイルへ書く中身を読み、鍵を断ります。

| 起動ファイル | 例 |
|---|---|
| 名前で決まるzshとbashの起動ファイル。置き場は問わない | ホームのフォルダかdotfilesのフォルダの`.zshrc`、`.zprofile`、`.zshenv`、`.zlogin`、`.bashrc`、`.bash_profile`、`.bash_login`、`.profile` |
| fishの設定 | `fish`という名前のフォルダの`config.fish` |
| chezmoiの元の名前で置いた同じファイル | `dot_zshrc`、`private_dot_zshrc.tmpl`、`dot_config/fish/config.fish` |

| 所 | 読む物 |
|---|---|
| Write tool | `content` |
| Edit toolとMultiEditの各編集 | `new_string` |
| Codexの`apply_patch` | パッチがファイルへ足す行 |
| 起動ファイルへ書くシェルの命令 | `echo 'export FOO_TOKEN=abc' >> ~/.zshrc`のような命令の全体 |

| 断る物 | 通す物 |
|---|---|
| 名前が`_KEY`、`_TOKEN`、`_SECRET`、`_PASSWORD`で終わり、値をそのまま書いた、zshとbashの`export NAME=value`と、fishの`set -x NAME value`か`set -gx NAME value` | `"$(security find-generic-password -s NAME -w)"`、`$OTHER`、`${OTHER}`のように起動の時に読む値、空の値、`REPLACE_ME`、`CHANGEME`、`TODO`、`xxx`のような置き換え用の値、コメントにした行 |
| 外へ送る文の検査が知るGitHubやAWSの鍵などの形。どの行に在っても断る | 鍵の形を持たない行 |

断る時はファイルと、変数か鍵の種類を出し、値は出しません。
値はmacOSのキーチェーンや1Passwordのような秘密の置き場に控え、起動の時に読むように言います。
このマーケットプレイスのsecure-dotfileのプラグインは、そうした値を移します。

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

## チェーン

検査は、署名した取引をこのPCの外のチェーンへ送る命令を断ります。
送った取引は取り消せないためです。

| 送る命令 | 例 |
|---|---|
| `cast send`と`cast publish`。`cast s`と`cast p`も同じ | `cast send 0xabc "f()" --rpc-url https://rpc.example.org` |
| `cast rpc`で送る`eth_sendRawTransaction`と`eth_sendTransaction` | `cast rpc eth_sendRawTransaction 0x02f8 --rpc-url https://rpc.example.org` |
| `cast erc20-token`の`transfer`、`approve`、`mint`、`burn` | `cast erc20-token transfer 0xabc 0xdef 1 --rpc-url https://rpc.example.org` |
| `--broadcast`付きの`forge script`と、`forge create` | `forge script script/Deploy.s.sol --broadcast --rpc-url https://rpc.example.org` |
| `hardhat ignition deploy`。`npx`、`pnpm`、`yarn`、`bunx`、`npm exec`を通しても同じ | `npx hardhat ignition deploy ignition/modules/A.ts --network sepolia` |

送り先は、castの`--rpc-url`と`-r`、forgeの`--rpc-url`と`--fork-url`と`-f`、命令の前に書いた`ETH_RPC_URL=`から読みます。
URLが`http`、`https`、`ws`、`wss`を使い、ユーザー名とパスワードを持たず、ホストが`127.0.0.1`、`localhost`、`::1`の時に通します。
送り先の無い命令、変数で渡した送り先、`--rpc-url sepolia`のような`foundry.toml`の名前、`--flashbots`付きの`cast`は、このPCの中に留まるかを確かめられないので断ります。
Hardhatの配備は、`hardhat`と`localhost`のネットワークと`--network`の無い時は通し、`--network`か`HARDHAT_NETWORK=`がほかのネットワークを名指す時は断ります。
`cast call`、`cast mktx`、`cast wallet sign`、`--broadcast`の無い`forge script`のように、読むだけの命令と送らない署名は通します。
RPCのURLのpathはAPIの鍵を持つことがあるので、断る時はホストだけを出してURLの全体は出さず、先頭に`!`を付けた同じ命令で終えます。

## 他人のリポジトリ

検査は、自分の物でない持ち主のリポジトリへの送信を断ります。
送った物はすぐに公開され、取り消せないためです。
自分の物であるGitHubのユーザーと組織を`~/.config/agent-guards/own-owners`から1行に1つずつ読み、大文字と小文字を区別せずに比べます。
ファイルが無いか持ち主が1つも無い時は、どれが自分のリポジトリか分からないので、何も断りません。

| 送信 | 持ち主を読む所 |
|---|---|
| `gh issue create`、`gh pr create`、`gh issue comment`、`gh pr comment`、`gh pr review` | `-R`か`--repo`、`GH_REPO`、引数に渡したissueかpull requestのURL |
| 題か本文か添付を変える`gh issue edit`と`gh pr edit`と、コメントを付けた`gh issue close`と`gh pr close` | 同上 |
| `repos/<owner>/<name>/...`へのPOST、PATCH、PUT、DELETEか、指定の無いままフィールドを持つ`gh api` | エンドポイント |
| `git push` | 送る先のリモートのURL。名指したリモート、`--repo`、ブランチのpushのリモートの順に読み、無ければ`origin` |

| 持ち主を問わず断る物 | 理由 |
|---|---|
| `gh api graphql`のmutationと、検査が読めないquery | 送り先をIDで名指す |
| 変数で渡したリポジトリ、エンドポイント、リモート | 誰のリポジトリか分からない |

`-R`の無い`gh`の送信は、ghがクローンのリモートから選ぶリポジトリへ届き、フォークでは上流になります。
`gh repo set-default`で選んだリモートか、選んでいない時はどれかのリモートが一覧の外の持ち主を名指す時は断り、`-R`でリポジトリを名指すように言います。
読むだけの命令、ラベルと担当の変更、コメントの無いcloseは通します。
リモートを読むため、クローンの中で`git config`、`git symbolic-ref`、`git remote get-url`を走らせます。
断る時は、先頭に`!`を付けた同じ命令で終えます。

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
| `protected-paths`の一覧の置き場かその中への上書き。そこを書き先にする`cp`、`install`、`ln`、`rsync`、`scp`、`mv` (`-t`か`--target-directory`で書き先を渡す形も含む)、`tee`、`dd of=`、`sed -i`、`truncate`と、リダイレクトの`>`、`>>`、`&>`。置き場から外へのコピーと、エージェントのWriteとEditの道具は通す | `cp build/claude ~/.local/bin/claude`、`echo x > ~/work/keep/a.txt` |
| `protected-paths`の一覧の置き場かその中に対する`git rm`。`-r`、`--cached`、`git -C <folder>`の形も含む | `git rm -r ~/work/keep` |
| それらの置き場か`protected-paths`の一覧の置き場に対する、`-R`か`--recursive`付きの`chmod`、`chown`、`chgrp`。木の全体から権限を外すと、消した時と同じく入れなくなるため。最初の語は権限か持ち主で、`-w`のような権限も権限として読む | `chmod -R 000 ~`、`chown -R nobody ~` |

## システム

検査は、PC全体を変え、戻しにくい命令を断ります。

| 断る物 | 理由 |
|---|---|
| `mount`と`umount` | PCにマウントする物を変える |
| `chroot` | 別のルートのフォルダの中で命令を走らせる |
| `pfctl` | macOSのファイアウォールであるパケットフィルタを変える |
| `mkfs`と`mkfs.*` | ディスクを初期化し、中身を消す |
| `do shell script ... with administrator privileges`を持つ`osascript` | `sudo`と同じく、管理者としてシェルのスクリプトを走らせる |

命令の読み方の節のとおり、`sudo`、`env`、`/sbin/mount`のような絶対パス、`bash -c`の後ろでも読みます。
`grep mount notes.txt`のように引数に在るだけの名前と、管理者の権限を使わない`osascript`は通します。
断る時は、先頭に`!`を付けた同じ命令で終えます。

## 判断できない時

出来事を読めないか判断の途中で失敗したフックは、黙って通さずに、呼び出しを断ってそう伝えます。
Python 3が無いと、各フックは毎回断り、Python 3を入れるか検査を外すように言います。
各検査は、冒頭の表のとおり、自分の変数を`off`にすると外れ、検査が全て外れたフックはすぐに終わります。

## 限界

- フックが見るのは、エージェントが送る命令の文だけです。命令が動かすスクリプトのファイルは読まないので、`bash cleanup.sh`の中身は調べません
- ランダムなパスワードのように決まった前置きを持たない鍵の形は見つけません
- `printf`の出力を`sh`に渡すように、動かす時に作る命令は読みません
- 書く先が変数から来る書き込みは断りません。`python3 -c "open('.env', 'w')"`のように、プログラム自身のコードが書く物も読みません
- `cp`でほかのファイルを上書きして書いた起動ファイルは、命令の文だけを読むので、鍵を調べません
- `hardhat run`やスクリプトが走らせる配備と、設定の`defaultNetwork`で選んだHardhatのネットワークは読みません
- `curl`でGitHubのAPIへ送るように、プログラム自身のコードがGitHubへ送る物は読みません
