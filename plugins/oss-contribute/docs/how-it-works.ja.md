# OSS Contributeの仕組み

[English](how-it-works.md) · 日本語

このページでは、各コマンド、プラグインが読む物、動かす物、つなぐ先、残す物、下書きの指紋の作り方、送る直前に確かめることを説明します。
ここに書いたことは全部`skills/oss-contribute/scripts/oss_contribute.py`が行い、Pythonの標準ライブラリ、`git`、`gh`、`docker`だけを使います。

## コマンド

| コマンド | すること | つなぐ先 |
|---|---|---|
| `start --repo <owner/name> [--branch <branch>]` | プロジェクトをクローンし、クローンが既にある時は取得し直して、ブランチを作るか切り替えます | 公開のプロジェクトを`git clone`と`git fetch`で取るためのGitHub |
| `rules --repo <owner/name> [--json]` | プロジェクトの決まりが書かれたファイルと、大事な行を並べます | なし |
| `security --repo <owner/name>` | クローンにあるセキュリティの方針のファイルを示し、非公開の脆弱性報告が有効かを示します | `gh api repos/<owner>/<name>/private-vulnerability-reporting`でつなぐGitHub |
| `check --repo <owner/name> --image <image> [--deps <command>] --test <command>` | プロジェクトの命令をDockerのコンテナの中で動かします | Docker。イメージが無ければDockerがダウンロードし、依存の段ではネットワークを使うことがあります |
| `draft --repo <owner/name> --kind issue\|pr\|comment\|push ...` | 下書きを記録して表示します | コメントの時だけ、`gh api repos/<owner>/<name>/issues/<number>`でつなぐGitHub |
| `show <draft>` | 下書きを今の状態で表示します | なし |
| `approve <draft> --fingerprint <code> [--accept-findings]` | 今の状態の下書きへの承認を記録します | なし |
| `send <draft>` | 送り先をもう一度確かめ、承認した下書きを送ります | `gh api`と`git push`でつなぐGitHub |
| `list` | 下書きと、それぞれを送ったかを並べます | なし |
| `clean --repo <owner/name> [--force]` | プロジェクトのクローン、下書き、Dockerのキャッシュのボリュームを消します | Docker |

## プロジェクトの取り方

`start`は`https://github.com/<owner>/<name>.git`を`git clone --origin upstream`でクローンします。プロジェクトのリモートの名前は`upstream`になり、プルリクエストを送るまでほかのリモートはありません。
クローンはプラグインのフォルダの中の`clones/<owner>/<name>`に、名前を小文字にして置きます。
どのコマンドも、シンボリックリンクになっているか、プラグインのフォルダの外を指すクローンのフォルダを断ります。`start`は、`upstream`が別の場所を指している既存のクローンも断ります。
新しいブランチは`upstream/<既定のブランチ>`から、追跡を設定せずに作ります。

## プロジェクトの決まりの読み方

`rules`は、プロジェクトの直下、`.github/`、`docs/`、`.github/ISSUE_TEMPLATE/`、`.github/PULL_REQUEST_TEMPLATE/`、`.github/workflows/`、`.circleci/`のファイルを見ます。
シンボリックリンクのファイルと、クローンの外を指すファイルは読まず、読まなかった物として並べます。
各ファイルは最大1 MBまで読み、行は端末の制御文字を除き、160文字で切って表示します。

| 項目 | 見つけ方 |
|---|---|
| 貢献の手引き、セキュリティの方針、行動規範、雛形 | ファイル名で探します。大文字小文字は問わず、拡張子が無いか、`.md`、`.rst`、`.txt`、`.adoc`、`.markdown`の物です。`.github/ISSUE_TEMPLATE/`と`.github/PULL_REQUEST_TEMPLATE/`の中のファイルは全部雛形として数えます |
| エージェント向けの手引き | `AGENTS.md`、`CLAUDE.md`、`copilot-instructions.md`。並べるだけです |
| 署名(sign-off) | `DCO`、`DCO.md`、`DCO.txt`、`.github/dco.yml`のファイルか、貢献の手引きかプルリクエストの雛形の中の、`Signed-off-by`、`Developer Certificate of Origin`、`DCO`、`git commit -s`、`--signoff`を含む行です |
| CLA | 同じファイルの中の、`CLA`、`Contributor License Agreement`、`cla-assistant`を含む行か、`cla`の名前を持つワークフローです |
| AIの方針 | 貢献の手引き、行動規範、雛形、AIの方針のファイルの中で、`AI`、`LLM`、`ChatGPT`、`Copilot`、`Claude`、`Gemini`を単語として含むか、`generative`、`machine-generated`、`large language model`、`artificial intelligence`、`vibe coding`を含む行を、最大20行です |
| 検査の命令 | ワークフローなどのYAMLの検査のファイルの`run:`の行(複数行のブロックを含む)と、`node-version`のような版の指定、`package.json`の`scripts`、`Makefile`、`GNUmakefile`、`justfile`の`test`、`check`、`lint`、`fmt`、`format`、`ci`、`build`、`typecheck`のターゲットです |

スクリプトはこれらの行を見つけるだけです。
決まりが何を求めているかは、エージェントがファイルを読んで判断します。

## 検査の動かし方

`check`は、指定したイメージから最大2つのコンテナを順に動かします。

| 設定 | 値 |
|---|---|
| ネットワーク | 依存の段は`bridge`、検査の段は`none`です |
| クローン | `/src`に読み取り専用でつなぎ、`/work`の作業用ボリュームに写してから、そこで命令を動かします |
| キャッシュ | `oss-contribute-cache-<owner>-<name>`という名前のボリュームを`/cache`につなぎ、同じプロジェクトの次の実行のために残します |
| 環境変数 | キャッシュの置き場所だけです。`XDG_CACHE_HOME`、`npm_config_cache`、`npm_config_store_dir`、`YARN_CACHE_FOLDER`、`PIP_CACHE_DIR`、`UV_CACHE_DIR`、`GOMODCACHE`、`GOCACHE`、`CARGO_HOME`です |
| 権限 | `--security-opt no-new-privileges`を付け、入口を`/bin/sh`にし、`--rm`で動かします |
| 渡さない物 | あなたの環境変数、SSHのエージェント、`gh`のサインイン、ホームフォルダ、Dockerのソケット |

作業用ボリュームは実行のたびに作り、段が失敗した時も含めて実行の終わりに消します。
依存の段が失敗した時は、検査の段を動かしません。
イメージの名前は英字か数字で始まり、英字、数字、`._/:@-`だけを含む物に限ります。Dockerのオプションとして読まれることはありません。
`docker info`が失敗した時は何も動かさず、終了コード3で終わります。

## 下書き

下書きは1つずつ`drafts/<owner>-<name>-<kind>-<n>/`のフォルダになり、次のファイルを持ちます。

| ファイル | 持つ物 |
|---|---|
| `draft.json` | リポジトリ、種類、ブランチと送り先のブランチ、Issueの番号、下書きを作った時の指紋 |
| `title.txt`、`body.md` | 送る物 |
| `translation.md` | あなた向けの訳。送らず、指紋にも含めません |
| `diff.patch` | 読むための差分で、`show`が書き直します。指紋はこのファイルではなくコミットから作ります |
| `approval.json` | 承認した指紋と、それを作った部品 |
| `sent.json` | 送った物のリンクと送った時刻 |

題は256文字までの1行、本文はGitHubの上限の65,536文字までです。

| 種類 | 下書きが持つ物 |
|---|---|
| `issue` | 題と本文 |
| `pr` | 題、本文と、クローンの今のブランチが`upstream/<送り先のブランチ>`から分かれた所から最後のコミットまでのコミット。追跡しているファイルにコミットしていない変更が無く、送り先のブランチの上にいないことが条件です |
| `comment` | 本文と、Issueかプルリクエストの番号。下書きの時に`gh`でIssueを読み、ロックされた物を断り、状態を記録します |
| `push` | 最後にフォークへpushした後に足したコミット。ブランチを書き換えた時は、ブランチを置き換えると示し、差分は`upstream/<送り先のブランチ>`から取ります |

## 見つけた物

下書きは、題、本文、差分が足す行、コミットのメッセージから次の物を探します。

| 見つけた物 | 探す物 |
|---|---|
| 秘密の値 | GitHubのトークン、AWSのアクセスキー、秘密鍵、OpenAIとAnthropicのキー、Slackのトークン、GoogleのAPIキー、Stripeの本番用キー、npmのトークンの形 |
| ホームフォルダのパス | `/Users/<name>/`、`/home/<name>/`、`C:\Users\<name>`。ただし`runner`や`user`のようなよく使われる仮の名前は除きます |
| メールアドレス | `example.com`、`example.org`、`example.net`、`users.noreply.github.com`以外のアドレス。コミットのメッセージでは探しません。署名の行がアドレスを持つためです |
| `Co-authored-by`の行 | コミットのメッセージの中。CLAの検査が共同著者全員に署名を求めるためです |
| 署名の欠け | プロジェクトが署名を求める時に、`Signed-off-by`の行が無いコミット |

見つけた物は場所と種類だけを示し、値は示しません。
秘密の値の形をした物は、表示する題、本文、コミット、差分の中で`[hidden: <kind>]`に置き換えます。
見つけた物がある下書きは、`--accept-findings`を付けない限り`approve`が断ります。

## 指紋

指紋は、次の部品を持つJSONのSHA-256です。形式の版、小文字にしたリポジトリ、種類、Issueの番号、送り先のブランチ、ブランチ、最後のコミット、変更が始まるコミット、最後にフォークへpushしたコミット、ブランチを置き換えるか、題のSHA-256、本文のSHA-256、バイナリの差分のSHA-256です。
指紋は下書きのファイルとクローンのgitの情報から作り、`diff.patch`からは作りません。
あなたに見せるコードは、指紋の先頭の16進数12文字です。

`approve`は指紋を作り直し、コードが合わなければ断ります。承認は必ず、あなたが見た状態の下書きに対する物になります。
`send`も指紋を作り直し、承認した指紋と違えば、題、本文、コミット、差分、送り先のブランチのように、何が変わったかを示して断ります。
承認は「はい」と答えたのが誰かを区別できません。スキルは、あなたの答えを受けてから承認するようエージェントに指示しています。

## 送る直前に確かめること

| 種類 | `send`が先に確かめること |
|---|---|
| 全種類 | 下書きが承認済みでまだ送っていないこと、指紋が合うこと、プロジェクトをGitHubで同じ名前のまま読めて、アーカイブされていないこと |
| `issue` | プロジェクトのIssueが有効で、そこで開いているあなたのIssueの最初の100件に、同じ題の物が無いこと |
| `pr` | `upstream`に送り先のブランチがまだあること(`git ls-remote`)、`<あなたのログイン名>:<branch>`からのプルリクエストが開いていないこと、開いているプルリクエストの最初の100件に、同じ題のあなたの物が無いこと。フォークを見つけるか作った後に、フォークにその名前で別のコミットを持つブランチが無いことも確かめます |
| `comment` | Issueかプルリクエストがあってロックされておらず、開いているか閉じているかが下書きの時と同じこと |
| `push` | そのブランチからのプルリクエストがまだ開いていて、フォークのブランチが、下書きが起点にしたコミットのままであること |

確かめに失敗した時は何も送らず、理由を表示します。

## 送る時にすること

| 種類 | 動かす物 |
|---|---|
| `issue` | 題と本文を付けた`gh api -X POST repos/<owner>/<name>/issues` |
| `pr` | 既存のフォークを返すか新しく作る`gh api -X POST repos/<owner>/<name>/forks`、フォークのSSHかHTTPSのアドレスを選ぶ`gh config get git_protocol`、`git remote add fork`(または`set-url`)、フォークが`git ls-remote`に答えるまで最大30秒ほどの待ち、`git push fork <commit>:refs/heads/<branch>`、題、本文、`<フォークの持ち主>:<branch>`、送り先のブランチ、trueにした`maintainer_can_modify`を付けた`gh api -X POST repos/<owner>/<name>/pulls` |
| `comment` | 本文を付けた`gh api -X POST repos/<owner>/<name>/issues/<number>/comments` |
| `push` | `git push fork <commit>:refs/heads/<branch>`。ブランチを置き換える時は、最後にpushしたコミットに対する`--force-with-lease`を付けます |

pushするのは、ブランチが今指している物ではなく、承認したコミットそのものです。
送った後は`sent.json`にリンクを記録し、その下書きを二度と送りません。
ブランチをpushした後にGitHubがプルリクエストを開かなかった時は、もう一度`send`を動かすと、pushを飛ばしてプルリクエストを開きます。

## 残す物

| 何を | どこに | いつまで |
|---|---|---|
| クローン | `~/.local/share/oss-contribute/clones/<owner>/<name>`。`OSS_CONTRIBUTE_HOME`があればその下 | そのプロジェクトで`clean`を動かすまで |
| 下書き、承認、送った物のリンク | `~/.local/share/oss-contribute/drafts/<id>/` | そのプロジェクトで`clean`を動かすまで |
| 依存のキャッシュ | Dockerのボリューム`oss-contribute-cache-<owner>-<name>` | そのプロジェクトで`clean`を動かすまで |

プラグインのフォルダはモード700、ファイルはモード600で作り、あなただけが読めるようにします。
`clean`は、クローンにコミットしていない変更か追跡していないファイル、またはどのリモートにも無いコミットがある時は断り、それを並べます。`--force`を付けると、それでもクローンを消します。
GitHubのあなたのフォークには触れません。

## しないこと

- プロジェクトのコードをコンテナの外で動かすこと
- あなたが承認する前に送ること、承認の後に変わった下書きを送ること、同じ下書きを2回送ること
- セキュリティの報告を送ること、脆弱性を公開のIssue、プルリクエスト、フォークに載せること
- クローンの外へ出るシンボリックリンクを通してファイルを読むこと
- あなたの環境変数、SSHのエージェント、`gh`のサインイン、ホームフォルダ、Dockerのソケットをコンテナに渡すこと
- あなたのフォークを消すこと、Issueやプルリクエストを閉じたり書き換えたりすること、レビューに答えること

## 環境変数

| 変数 | 用途 |
|---|---|
| `OSS_CONTRIBUTE_HOME` | クローンと下書きを置く場所 |
| `OSS_CONTRIBUTE_GH` | 検査で`gh`の代わりに使う命令 |
| `OSS_CONTRIBUTE_DOCKER` | 検査で`docker`の代わりに使う命令 |
| `OSS_CONTRIBUTE_GIT_BASE` | 検査でクローンに`https://github.com`の代わりに使うアドレス |

## 終了コード

| コード | 意味 |
|---|---|
| 0 | 終わりました |
| 1 | 断ったか失敗しました。理由を表示します |
| 2 | 引数の誤り、知らない下書き、クローンが無い |
| 3 | Dockerが動いていないため、`check`は何も動かしていません |
