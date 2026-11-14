# Secure Dotfileの仕組み

[English](how-it-works.md) · 日本語

このページには、プラグインが調べるファイル、秘密の値とみなす条件、移す時の各段、決してしないことを載せています。
ここに書いたことはすべて`skills/secure-dotfile/scripts/secure_dotfile.py`が行い、使うのはPythonの標準ライブラリだけです。

## 調べるファイル

| シェルや道具 | ファイル |
|---|---|
| zsh | `~/.zshenv`、`~/.zprofile`、`~/.zshrc`、`~/.zlogin`と、`$ZDOTDIR`にある同じ名前のファイル |
| bash | `~/.bash_profile`、`~/.bash_login`、`~/.profile`、`~/.bashrc` |
| fish | `~/.config/fish/config.fish`と`~/.config/fish/conf.d/*.fish` |
| direnv | `~/.envrc`と`~/.config/*/env.d/*` |
| 読み込まれるファイル | 上のファイルが`source FILE`か`. FILE`で読み込むファイル。パスが決まっている物だけで(`~`、`$HOME`、`$ZDOTDIR`は展開します)、5段までたどります |
| chezmoi | 調べたファイルのうちchezmoiが作るファイルの、chezmoiの元のファイル |
| 指定したファイル | `--file`で渡したファイル |

## 秘密の値とみなす条件

書き出す変数に値をそのまま書いた行(`export NAME=value`、fishでは`set -x NAME value`)のうち、次のどちらかに当たる物を並べます。

| 条件 | 例 |
|---|---|
| 名前が`_API_KEY`、`_ACCESS_KEY`、`_SECRET_KEY`、`_PRIVATE_KEY`、`_KEY`、`_TOKEN`、`_SECRET`、`_PASSWORD`、`_PASSWD`、`_PASS`、`_PWD`、`_PIN`、`_PAT`で終わるか、`_`の無い`PASSWORD`か`PASSWD`で終わる | `GH_TOKEN`、`DB_PASSWORD`、`PGPASSWORD`、`MYSQL_PWD` |
| 値が知られたキーの形をしている | GitHub、GitLab、OpenAI、Anthropic、Slack、AWSのアクセスキーID、GoogleのAPIキー、npm、Hugging Face、Stripe、SendGrid、DigitalOcean、xAI、Groq、Perplexity |

次の行は並べません。

- シェルが動く時に読む値。`$(...)`、バッククォート、二重引用符の中か引用符の無い`$VAR`
- `REPLACE_ME`、`changeme`、`your_api_key`のような仮の値と、同じ1文字を繰り返した値
- `/`、`~`、`./`、`../`で始まるパス
- 8文字より短い値。ただし`PASSWORD`、`PASSWD`、`_PASS`、`_PWD`、`_PIN`で終わるパスワードの名前は長さを問わず並べ、8文字より短い値は種類を`short password`にします
- `export NAME= value`。これは`NAME`を空の値にする書き方です

## 値をエージェントから遠ざける方法

エージェントはスクリプトを動かして出力を読みますが、出力には値の一部も入りません。
秘密の値ごとに出すのは、名前、ファイルと行、種類、長さ、値がgitの履歴にあるかだけです。
予期しないエラーで止まった時も、出すのはエラーの種類とスクリプトの行番号だけです。エラーの文がファイルの行を引用することがあるためです。
値を保存する時は、macOSでは`security`コマンドへの指示を標準入力で渡し(`security -i`)、Linuxでは値そのものを`secret-tool store`へ、`pass`では`pass insert -e`へ、1Passwordでは値を入れた項目のJSONのテンプレートを`op item create -`へ標準入力で渡します。値はほかのプロセスから読めるコマンドラインには載りません。
書き換えたファイルの文法は、中身を標準入力でシェルに渡して確かめるので、ファイルの写しをほかの場所に書きません。

## 値の置き場

| システム | 置き場 | コマンド |
|---|---|---|
| macOS | 既定のキーチェーン | `security` |
| Linux | Secret Serviceの既定のコレクション。GNOME Keyring、KWallet、Secret Serviceを有効にしたKeePassXCが、ログインしたセッションのD-Busで受け持ちます | libsecretの`secret-tool`。DebianとUbuntuでは`libsecret-tools`パッケージに入っています |
| どのシステムでも、`--store pass`の時 | `pass`の置き場。`~/.password-store`か、`PASSWORD_STORE_DIR`のフォルダで、項目ごとにあなたのGPGの鍵で暗号化します | `pass`とGnuPG |
| どのシステムでも、`--store 1password`の時 | `op`が新しい項目を入れる1Passwordの保管庫。アカウントの種類によってPrivate、Personal、Employeeのどれかの名前で、題が`NAME`のLoginの項目として入れます | 1PasswordのCLIの`op`。サインインしているか、1Passwordのアプリと連携している物 |

調べた結果には、移す時の置き場(`Moves into the secret service`など)と、ここで使えるほかの置き場(`Also available: pass (add --store pass)`など)が出ます。
`pass`が出るのは、`pass`コマンドがあり、`pass init`で置き場を用意してある時です。
1Passwordは、`op`コマンドがある時に、`op`を動かさずに出ます。
`--store`は、1回の調べる操作か移す操作の置き場を選びます。
`op`を動かすのは`--store 1password`を選んだ調べる操作と移す操作だけで、1Passwordのアプリが承認を求めることがあります。`op`には新しい項目を入れる保管庫を答えるコマンドが無いので、最初に`op vault list`を動かし、名前がPrivate、Personal、Employeeの保管庫を選びます。その名前の保管庫が無いか2つ以上ある時と、`op`がサインインしていない時は、調べた結果に移せない理由を書き、移す操作は何も変えずに終了コード3で止まります。
KDE Frameworks 6のKWalletは、切っていなければSecret Serviceを受け持つので、`secret-tool`で届きます。切ってある時は、`~/.config/kwalletrc`の`[org.freedesktop.secrets]`の組から`apiEnabled=false`を消すと元に戻ります。
`SECURE_DOTFILE_STORE`は、`--store`が無い時に、システムの既定の代わりの置き場を選びます。`SECURE_DOTFILE_KEYCHAIN`には、既定のキーチェーンの代わりに使うキーチェーンのファイルを入れます。
どちらも、使い捨ての置き場で試すテストのための物です。

## 移す時の各段

エージェントはあなたが選んだ物を渡し、スクリプトは1つずつ次の段を行います。

1. 行を読み直し、その変数に値をそのまま書いた行でなくなっていたら、その物を飛ばします
2. 置き場で変数の名前を引きます。別の値が入っていたら、その物を飛ばして何も保存しません。同じ値が入っていたら、それを使います。`secret-tool store`と`pass insert`は尋ねずに項目を置き換え、`op item create`は同じ名前の項目をもう1つ作るので、上書きと重複を防ぐのはこの引き直しです。`pass`では、項目のファイルが無ければ、何も復号せずに無いと分かります。1Passwordでは、`op item list`で保管庫の項目を並べ、秘密の参照と同じく大文字と小文字を区別せずに題を名前と比べます。その題の項目が2つ以上ある時は、その物を飛ばします
3. 値を保存し、読み戻して比べます。キーチェーンとSecret Serviceはサービス`NAME`、アカウント`$USER`で保存し、Secret Serviceでは項目の名札を`NAME (added by secure-dotfile)`にします。`pass`は`pass insert -e`で項目`NAME`に保存します。1Passwordは`op item create --vault VAULT -`で、題が`NAME`のLoginの項目を作り、値をパスワードの欄に、`added by secure-dotfile`をメモに入れ、`op read -n`で読み戻します
4. その行の値の部分だけを、macOSでは`"$(security find-generic-password -a "$USER" -s NAME -w 2>/dev/null)"`に、Linuxでは`"$(secret-tool lookup service NAME account "$USER" 2>/dev/null)"`に、`pass`では`"$(pass show NAME 2>/dev/null)"`に、1Passwordでは`"$(op read 'op://VAULT/NAME/password' 2>/dev/null)"`に置き換えます。行のほかの部分(コメントなど)は残します。fishでは、コマンドを`"$( )"`の代わりに`( )`で囲みます
5. ファイルごとに、同じフォルダの一時ファイルに書いてから元のファイルと入れ替え、一度に書き込みます。ファイルの権限を保ち、パスがシンボリックリンクの時はリンク先のファイルを書き換えます
6. 書き換えたファイルの文法をシェルで確かめます。zshのファイルは`zsh -n`、fishのファイルは`fish --no-execute`、それ以外は`bash -n`です。元のファイルが通り、書き換えた後に通らない時は、ファイルを元のとおりに書き戻します

`--dry-run`を付けると、保存も書き換えもせず、各物がどう変わるかだけを示します。

## 飛ばす時

| 理由 | なぜ |
|---|---|
| 行がその変数に値をそのまま書いた行でなくなった | 調べた後にファイルが変わったためです。もう一度調べてください |
| 同じ名前で別の値がすでに保存されている | 保存すると別の秘密の値を上書きするためです |
| 値にバックスラッシュがある | バックスラッシュの意味はシェルごとに違い、保存した値がシェルの使っていた値と一致しないことがあるためです |
| 値に`*`、`?`、`[`、`{`がある | シェルがこれらの文字を展開することがあるためです |
| 値に表示できるASCII以外の文字がある | `security`コマンドがそうした値を16進数で読み戻すため、変数の中身が変わってしまいます。Linuxでも同じ値は飛ばします |
| ファイルがchezmoiで作られている | `chezmoi apply`が古い行を書き戻すためです。代わりに元のファイルで移します |
| キーチェーンが応答しない | 鍵が掛かっているか、パスワードを待っています。鍵を開けて、もう一度移してください |
| Secret Serviceにつながらない | D-Busのセッションか鍵束が動いていないか、鍵束に鍵が掛かっています。理由の末尾に`secret-tool`自身の文を添えます。鍵束の鍵を開けるか起動して、もう一度移してください |
| `pass`が項目を読めない、または読み戻せない | GPGの鍵に鍵が掛かっていてパスフレーズを尋ねる画面を出せないか、鍵がありません。理由の末尾に`pass`が出した最初の行を添えます。`pass insert`は公開鍵で暗号化するので、値はもう保存されていることがあります。鍵を開けてもう一度移すと、同じ値を見つけて行を書き換えます |
| 1Passwordを読めない、またはその名前の項目が2つある | `op`がサインインしていないか、1Passwordのアプリが承認していません。理由の末尾に`op`が出した最初の行を添えます。または、保管庫にその名前を題に持つ項目が2つ以上あります。サインインするか承認するか、ほかの項目の名前を変えて、もう一度移してください |

## chezmoi

`chezmoi`が入っていて、秘密の値があるファイルをchezmoiが作っている時は、そのファイルのchezmoiの元のファイルも調べます。
作られたファイルは並べますが移せず、元のファイルは移せます。
移した後に`chezmoi apply`を実行すると、新しい行が作られたファイルにも書き込まれます。
テンプレートの元のファイル(`.tmpl`)も同じように書き換えますが、文法は確かめません。

## gitの履歴

gitのリポジトリの中にある、秘密の値を持つファイルごとに、そのファイルの`git log --all -p`を読み、スクリプトの中で各値を探します。読むのは64MBまでです。
`yes`は、その値がいつかそのファイルにコミットされたことを表します。リモートにも上がっているかもしれないので、そのキーは作り直してください。
`no`は、そのファイルの履歴に値が無いことを表します。ほかのファイル、バックアップ、シェルの履歴には残っているかもしれません。

## 決してしないこと

- 値の一部でも表示、記録、送信すること
- キーチェーン、Secret Service、`pass`、1Passwordにすでにある値を上書きすること
- 移した値の行以外を書き換えること
- ファイルのバックアップを書くこと。バックアップに秘密の値が残るためです
- キーを作り直すことと、新しい値を尋ねること。新しい値は、あなたが自分のターミナルで、macOSでは`security add-generic-password -a "$USER" -s NAME -U -w`を、Linuxでは`secret-tool store --label=NAME service NAME account "$USER"`を、`pass`では`pass insert -f NAME`を実行して保存します。値を表示せずに尋ねます。1Passwordでは、1Passwordのアプリで項目を書き換えます
- 自分でネットワークにつなぐことと、自分用のファイルを残すこと。Linuxの`secret-tool`がSecret Serviceと話すのは、ログインしたセッションのD-Busの中だけです。`pass`の置き場がgitのリポジトリの時は、`pass`が新しい項目を暗号化したままコミットし、pushはしません。`--store 1password`の時は、`op`が1Passwordのアプリか1Passwordのサーバーと話し、あなたのアカウントの項目を読み書きします

## できないこと

- 移すには、macOSと`security`コマンドか、Linuxと`secret-tool`か、`--store pass`の時は`pass`コマンドと置き場か、`--store 1password`の時は`op`コマンドとサインインと、名前がPrivate、Personal、Employeeの保管庫1つが要ります。ほかのシステムか、そのコマンドが無い時は、調べることはでき、移す時は足りない物の名前を出して終了コード3で止まります
- 移した行はシェルの起動時に値を読むので、その時に置き場へつながる必要があります。Linuxでは、SSHで入って起動したシェルや、鍵束の鍵を開ける前に起動したシェルで、変数が空になることがあります。鍵の開いた鍵束につながらない時、`secret-tool`は何も出さないためです。`pass`を読む行はGPGの鍵で復号するので、gpg-agentが鍵のパスフレーズを覚えるまで、新しいシェルのたびにパスフレーズを尋ねます。尋ねる手段の無いシェルでは変数が空になります。`op read`を動かす行は、新しいターミナルを開いた時に1Passwordのアプリが承認を求めることがあり、`op`がサインインしていないシェルでは変数が空になります
- 1Passwordへ移す動きは、op 2.42のヘルプに沿った代わりの`op`で確かめた物で、実際の1Passwordのアカウントでは試していません
- Bitwardenは置き場にしません。`bw`コマンドは値を標準入力で受け取れますが、読めるのはセッションの鍵`BW_SESSION`が環境にある時だけです。新しいシェルでは変数が空になり、セッションの鍵を起動ファイルに書けば、そこにまた秘密の値を置くことになります。1回読むのにも約3秒かかります
- ほかの置き場には移せません
- 道具が自分で読むファイルは調べません。プロジェクトの`.env`、`~/.npmrc`、`~/.netrc`、`~/.aws/credentials`、SSHの鍵がこれに当たります
- `export`(fishでは`set -x`)の無い代入と、複数行にわたる値は見つけません
- シェルの履歴、バックアップ、Time Machineに残った古い値の写しはそのまま残ります。キーを作り直せば、それらの写しは使えなくなります
- 移した値も、シェルが起動するすべてのプログラムへ環境変数として渡ります。プロセスの環境を一覧にする道具でも見えます。強い権限のキーは、要るコマンドの時だけ読む方が安全です
- チームで共有するキーは、一人のキーチェーンや個人の保管庫ではなく、`op`で読む1Passwordの共有の保管庫のような、チームで共有する保管庫に置きます
