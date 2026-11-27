# EVM Devの仕組み

[English](how-it-works.md) · 日本語

このプラグインは11のスキルを持ちます。
`evm-standards`は同梱の項目からERCとEIPについての質問に答え、`ethereum-knowledge`は自分の項目からL2のネットワークとEthereumのL1の今後とコンセンサスだけを変えるEIPについての質問に答え、`solidity-code`は道具についての項目から、プロジェクトが使う版に合わせてSolidityを書き、`contract-tests`はテストの道具についての項目から、プロジェクトのコントラクトのテストを書き、`contract-deploy`は鍵の保管とハードウェアの財布と配った記録と検証についての項目から、配る命令を書き、プロジェクトの鍵の扱いを確かめ、出した物を記録し、`release-check`はEVMの版と取引のガスの上限と保存の配置と道具についての項目から、出す前のコントラクトを配ってある版と出す先のチェーンに照らして確かめ、`contract-design`は頼るライブラリとサービスについての項目から、コントラクトの設計書を書き、`wallet-design`はアカウントと許可と承認とガス代の肩代わりと支払いについての項目から、アプリのウォレットと署名の設計書を書き、`multichain-design`は展開の道具とブリッジとメッセージのプロトコルとトークンの規格についての項目から、複数のチェーンにまたがるアプリの設計書を書き、`dapp-architecture`は使うかもしれないサービスについての項目から、dAppの部品の組み方の設計書を書き、`financial-standards`は金融の規格の版についての項目から、その規格を使うアプリの設計書を書きます。
この頁は、スキルの項目と、項目を古いと見る時期と、スクリプトと、エージェントが項目をどう扱うかを書きます。

## ERCとEIPの項目

項目は`skills/evm-standards/references/items/`の下に1件1ファイルのMarkdownで置きます。
ファイル名は規格の名前で、例えば`eip-7702-set-code-for-eoas.md`や`erc-4337-account-abstraction.md`です。
先頭の欄に次の4つを持ちます。

| 欄 | 持つ物 |
|---|---|
| `status` | `announced`、`specified`、`live`、`stopped`のどれか |
| `checked` | 公式の文書で状態を確かめた日。`YYYY-MM-DD`の形 |
| `source` | もとにした組織と文書の名前。項目はURLを持ちません |
| `can` | その規格でコントラクトとウォレットとdAppに何ができるようになるかを書いた1文。`find`が探します |

本文には、その規格が何か、コントラクトとウォレットとdAppで何ができるようになるか、今の状態、まだ出ていない物を書きます。
扱うのは、ERCと、コントラクトとウォレットでできることを変えるEIPです。
L2のネットワークの状態と、コンセンサスだけを変えるEIPは、`ethereum-knowledge`の項目が持ちます。

## 状態

| 状態 | 意味 | 古いと見るまでの日数 |
|---|---|---|
| `announced` | 出すと発表されたが、仕様も実装も確かめていない | 30日 |
| `specified` | 仕様か実装が出たが、動いているとは確かめていない。`Stagnant`の文書は作者が再び動かせるのでここに置く | 90日 |
| `live` | メインネットで動いているか、使われていると確かめた | 180日 |
| `stopped` | 取り下げられたか、作者が開発を止めた | 180日 |

ちょうどその日数の項目は古いと見ず、次の日から`list`が`stale`の印を付けます。
日数はUTCで数えるので、夏時間の切り替えで1日が短くなることはありません。

## evm-standardsのスクリプト

`skills/evm-standards/scripts/evm-standards.sh`は、macOSに入っているBashで動き、項目だけを読みます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が3つの欄と、決まった状態と、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに、`ok`か`stale`、状態、確かめた日、名前を1行で出し、最後に件数を出します |

`--dir`でどちらの命令にも別の項目のフォルダを渡せ、`list --today`で数える日を差し替えられます。
プラグインの検査は両方を使います。

`find`と`article`は`skills/evm-standards/scripts/standards.py`を動かします。Pythonの標準ライブラリだけを使います。

| 命令 | すること |
|---|---|
| `find <語>...` | 名前、見出し、`can`の欄、本文に語のどれかを持つ項目と、題か説明に語のどれかを持つ、名指した一覧の記事を、当たった語の多い順に出します。項目の行には状態と確かめた日を、記事の行にはリンクを添えます |
| `article <番号>` | 題が`[ERC<番号>]`か`[EIP<番号>]`で始まる、名指した一覧の記事を出します。`[ACP209]`のような別の題と、題の途中に番号が出るだけの記事は出しません |

記事の一覧は、利用者が名指した一覧です。
`EVM_DEV_INDEX_URL`か、無ければ`~/.evm-dev/article-index`の1行目に、URLかfileのpathで名指します。
どちらも無い時は、スクリプトは一覧を読まずに`articles: no article index is named`と出し、エージェントは記事を添えません。
一覧はllms.txtの箇条書きの形で、`- [\[EIP7951\] title](https://example.com/articles/eip-7951.md): description`のように書き、`.md`で終わるリンクはそれを外して出します。
URLで名指した一覧は、そのURLへの素のGETで取るため、質問の語は送りません。
取った一覧は、本人だけが読めるフォルダの`~/.local/share/evm-dev/`(`EVM_DEV_HOME`で替えられます)にURLごとに1つのfileとして1日の間残し、それを過ぎると取り直します。
pathで名指した一覧は毎回そのfileから読み、写しを作りません。
一覧を読めない時は残した写しを使ってそう伝え、写しも無い時は`find`が項目の結果だけを出して、記事の一覧を読めなかったと伝えます。
出すのは題と説明とhttpsのリンクだけで、httpかhttpsのURLから読んだ一覧からは、一覧と同じhostのリンクだけを出します。エージェントはそれを指示ではなくデータとして読みます。
プラグインの検査は、`file://`のURLとpathで一覧を名指します。

## 規格についてのエージェントの答え方

1. `list`を動かし、質問に要る項目を読みます
2. 項目が`stale`の時は、答える前に公式のERCかEIPの文書で確かめ直し、変わった所を伝えます
3. 文書を開けない時は、項目から答え、確かめた日を添えて確かめられなかったと伝えます
4. 質問に当たる項目が無い時はそう伝え、公式の文書から答えるか、確かめられなかったと伝えます
5. どの規格でできるかを尋ねられた時は、英語と利用者の言語の語で`find`を動かし、各規格の状態は記事からではなく、項目か公式の文書から取ります
6. 答えに出す規格ごとに`article`を動かし、記事の題とリンクを添えます

## L2とL1の項目

`ethereum-knowledge`は自分の項目を`skills/ethereum-knowledge/references/items/`の下に、ネットワークか枠組みかEIPごとに1件1ファイルのMarkdownで置きます。
例えば`op-stack-fault-proofs.md`や`eip-7594-peerdas.md`です。
先頭の欄に次の3つを持ちます。

| 欄 | 持つ物 |
|---|---|
| `status` | `announced`、`specified`、`live`、`stopped`のどれか |
| `checked` | 公式の文書で状態を確かめた日。`YYYY-MM-DD`の形 |
| `source` | もとにした組織と文書の名前。項目はURLを持ちません |

本文には、そのネットワークか枠組みかEIPの仕組み、今の状態、まだ出ていない物を書きます。
状態と、古いと見るまでの日数は、ERCとEIPの項目と同じです。
公開された設計は仕様と同じに数え、`stopped`はネットワークかその開発が止まった時にも使います。
`erc-20-token.md`のようにERCの名前を持つ項目は、`evm-standards`の物です。

## ethereum-knowledgeのスクリプト

`skills/ethereum-knowledge/scripts/ethereum-knowledge.sh`は、macOSに入っているBashで動き、項目だけを読みます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が3つの欄と、決まった状態と、実在する日付を持ち、ERCの名前を持たないかを確かめます。満たさない項目を名指して1で終わります |
| `list` | 項目ごとに、`ok`か`stale`、状態、確かめた日、名前を1行で出し、最後に件数を出します |

`--dir`でどちらの命令にも別の項目のフォルダを渡せ、`list --today`で数える日を差し替えられます。
プラグインの検査は両方を使います。

## L2とL1の今後についてのエージェントの答え方

1. `list`を動かし、質問に要る項目を読みます
2. 項目が`stale`の時は、答える前にネットワークか枠組みかEIPの公式の文書で確かめ直し、変わった所を伝えます
3. 文書を開けない時は、項目から答え、確かめた日を添えて確かめられなかったと伝えます
4. 質問に当たる項目が無い時はそう伝え、公式の文書から答えるか、確かめられなかったと伝えます
5. ERCか、コントラクトとウォレットでできることを変えるEIPの質問は、`evm-standards`で答えます

## 道具の項目

`solidity-code`は自分の項目を`skills/solidity-code/references/items/`の下に置き、道具についての事実1つを1つのMarkdownのファイルにします。
例えば`openzeppelin-5.7-erc4337-drops-draft.md`です。
先頭の欄に次を持ちます。

| 欄 | 持つ物 |
|---|---|
| `tool` | `solc`、`openzeppelin`、`forge-std`、`foundry`、`hardhat`、`ethereum`のどれか |
| `since` | その事実が始まる版。`ethereum`の項目は持たず、いつも当てます |
| `checked` | 公式の文書で事実を確かめた日。`YYYY-MM-DD`の形 |
| `source` | もとにした組織と文書の名前。項目はURLを持ちません |
| `detect` | 任意。古い書き方の行に当たる正規表現で、1行ずつ当てます |
| `files` | 任意。`detect`を当てるファイルの名前の型を空白で区切った物。書かない時は`*.sol` |

本文には、何がどの版から変わったかと、今の書き方を書きます。
道具は数週間ごとに版を出すので、道具の項目は確かめてから90日を過ぎると古いと見ます。

## solidity-codeのスクリプト

`skills/solidity-code/scripts/solidity-code.py`は、Python 3の標準ライブラリだけで動きます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が欄と、決まった道具と、`since`の版と、実在する日付と、正規表現として読める`detect`を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに、`ok`か`stale`、道具、版、確かめた日、名前を1行で出し、最後に件数を出します |
| `project <folder>` | フレームワークと、solcとOpenZeppelinとforge-stdとFoundryとHardhatの版を出します。版は`foundry.toml`、Hardhatの設定、`lib/`と`node_modules/`の下の`package.json`、`forge --version`から読みます。読めない版は`unknown`、プロジェクトが使わない道具は`none`と出します |
| `scan <folder>` | 道具の版が`since`以上の項目の`detect`を、プロジェクトのファイルの各行に当て、`file:line item`の形で出します。道具の版が`unknown`の項目は、当たらなかったと数えず`unknown`の下に出します |

`scan`は、何も当たらない時に0、当たった時に1、何も当たらないが判定できない項目が在る時に3で終わります。
行の中身を出さず、`lib/`、`node_modules/`、`out/`、`cache/`、隠しフォルダ、名前が`.env`で始まるファイルを読みません。

`contract-tests`と`contract-deploy`と`release-check`は、プロジェクトの版と項目を読むためにこのスクリプトを動かします。
`skills/solidity-code/musubi.json`はこのスクリプトをコンテンツ`commands`のバージョン1.0.0として宣言し、3つのスキルの`musubi.json`はそれぞれ`solidity-code/commands`に、版の範囲`^1.0.0`と、最後に確かめた時のスクリプトのフィンガープリントを持って従います。
任意の準拠ではないため、`solidity-code`が無い時、それらのスキルは始めずに入れ方を伝えて止まります。

## エージェントのコントラクトの書き方

1. `project`を動かし、変える所の近くのコードを読み、プロジェクトのpragmaと配置と名前と誤りの書き方とライブラリに合わせます
2. `list`を動かし、プロジェクトが使う道具の項目を読み、`stale`の印の項目は確かめ直します
3. プロジェクトのライブラリでコントラクトを書き、更新の方式が決まっていない時は利用者に尋ねます
4. `scan`を動かして名指された行を直し、ビルドとテストを回します。回せない時はそう伝えます

## テストの道具の項目

`contract-tests`は`skills/contract-tests/references/items/`に、テストの道具についての事実ごとに1つのMarkdownのファイルで項目を持ちます。
例えば`hardhat-3.0-network-helpers.md`です。
前付けは`tool`(`forge-std`、`foundry`、`hardhat`のどれか)と`since`と`checked`と`source`を持ち、意味は上の道具の項目と同じで、`detect`は持ちません。
Foundry 1.0が`testFail`を外したことのような、Solidityの書き方についての事実は`solidity-code`の項目に残し、`contract-tests`はそのスキルを通して読みます。
テストの道具の項目は、確かめた日から90日で古いと見ます。

## contract-testsのスクリプト

`skills/contract-tests/scripts/contract-tests.py`は、Python 3の標準ライブラリだけで動きます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が4つの欄と、知っている道具と、`since`の版と、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに1行で、`ok`か`stale`と、道具と、版と、確かめた日と、名前を出し、最後に件数を出します |
| `points <folder>` | `foundry.toml`の`src`(既定は`src`)と、Hardhatのプロジェクトの`contracts`の下のコントラクトを読みます。interfaceと、`.t.sol`と`.s.sol`のファイルは除きます。点ごとに1行で、種類と名前と`file:line`を出します |
| `uncovered <folder>` | テストの置き場の下のテストと、全ての`.t.sol`のファイルを読み、どのテストも触れていない点を出します。残る点がある時は1で、全ての点にテストがある時は0で終わります |

| 種類 | 点 | テストが触れたと数える時 |
|---|---|---|
| `function` | 外から呼べる関数 | `.<名前>`を呼ぶ時 |
| `error` | 独自のerror | errorの名前を書く時 |
| `event` | event | eventの名前を書く時 |
| `access` | 名前が`only`で始まる修飾子、`restricted`(OpenZeppelinの`AccessManaged`)、`msg.sender`との比べのどれかで守った関数 | その関数を呼ぶ所で、守りが投げるエラーを待つ時。Solidityでは、`vm.`の命令でない最初の呼び出しの前の`expectRevert`がそのエラーを名指すか、その文字列を持つかを見ます。TypeScriptでは、呼び出しとrevertの確かめの文を見ます。エラーは`onlyOwner`が`OwnableUnauthorizedAccount`、`onlyRole`が`AccessControlUnauthorizedAccount`、`restricted`が`AccessManagedUnauthorized`で、プロジェクトが書いた守りはその独自のエラーか`require`の文字列です。読めない時は、何かエラーを名指すテストだけを数えます |
| `fuzz` | 状態を変え、整数を受ける関数 | 引数を受けるSolidityのテストの関数(名前が`test`で始まる関数)か、fast-checkの性質がその関数を呼ぶ時。引数を受ける補助の関数は数えません |
| `invariant` | 符号なし整数への`mapping`と、状態を変える関数を持つコントラクト。`mapping`の鍵と値に名前が付いていても、コントラクトが宣言したstruct(ERC-7201の名前空間のstructなど)の中に在っても数えます | コントラクトの名前を書いたSolidityのテストのファイルが、名前が`invariant`で始まる関数を持つ時か、fast-checkの`fc.commands`のテストがその名前を書く時 |

コメントの中の名前は数えません。
どちらの命令も種類と名前と`file:line`だけを出し、コントラクトとテストの中身は出しません。
`lib/`、`node_modules/`、`out/`、`cache/`、`artifacts/`、隠したフォルダ、名前が`.env`で始まるファイルは読みません。

## エージェントのテストの書き方

1. `solidity-code`のスキルで版とSolidityの項目を読み、`list`でテストの道具の項目を読み、`stale`の印の項目は確かめ直します。プロジェクトの今のテストの書き方に合わせます
2. `points`を動かし、コメントや利用者が述べた上限のような、スクリプトが見えない決まりを足します
3. kiwa-designとkiwa-forge(Hardhatではkiwa-hardhat)のスキルが使える時は、点をkiwa-designに渡してkiwaにテストを書かせ、自分ではテストのファイルを書きません。使えない時は、forgeか、プロジェクトが使うHardhatのテストの道具で、単体とfuzzとinvariantのテストを書きます
4. `uncovered`を動かし、残る点が無くなるまでテストを足します。残す点がある時は、どれをなぜ残すかを利用者に伝えます
5. プロジェクトのテストと`solidity-code`の探しを動かし、テストを回せない時はそう伝えます。テストが不具合を示した時は、コントラクトを変えずに不具合を伝えます

## 配ることの項目

`contract-deploy`は`skills/contract-deploy/references/items/`に、道具かファイルの形かサービスごとに1つのMarkdownのファイルで項目を持ちます。
例えば`foundry-keystore.md`や`foundry-broadcast.md`です。
前書きは、dAppのサービスの項目と同じ4つの欄を持ち、話題は次のどれかです。

| 欄 | 持つ物 |
|---|---|
| `topic` | `keys`、`records`、`verification`のどれか |
| `subject` | 項目が扱う道具かファイルの形かサービス。例えば`Foundry encrypted keystores (cast wallet import and --account)` |
| `checked` | 公式の情報で確かめた日。`YYYY-MM-DD`で書きます |
| `source` | 項目のもとにした組織と文書の名前。項目はURLを持ちません |

本文は、確かめた時に道具やファイルやサービスがどう動いたかと、配る時に守ることを書きます。
配ることの項目は、確かめてから90日を過ぎると古いと見ます。

## contract-deployのスクリプト

`skills/contract-deploy/scripts/contract-deploy.py`は、Python 3の標準ライブラリだけで動き、プロジェクトがgitのリポジトリの時は、`.env`のファイルと、記録のcommitと違うファイルについて`git`に尋ねます。

| 命令 | すること |
|---|---|
| `check` | どの項目も4つの欄と、知っている話題と、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに1行を出します。`ok`か`stale`、話題、確かめた日、名前、扱う物の順で、最後に数を出します |
| `keys <folder>` | プロジェクトが鍵を危なく扱う所を、種類と`file:line`で1件1行で名指し、1件でもあれば1で終わります |
| `record <folder>` | Foundryのbroadcastのファイルと、Hardhat Ignitionのjournalから、配ったコントラクトと見るべき取引を出します。`--write`を付けると`deployments/<chain id>.json`も書きます。見るべき取引か記録のcommitがあれば1で終わります |

`keys`は4つの種類を出します。

| 種類 | 意味 |
|---|---|
| `env-key` | 環境変数から読む秘密鍵かニーモニック(`vm.envUint`などの`vm.env`の呼び出し、`process.env`、shellとMakeの`$NAME`)、またはHardhat 2の設定の変数から読む物。Hardhat 2の設定の変数は暗号化されずに保存されます |
| `key-flag` | `--private-key`、`--private-keys`、`--mnemonic`、`--mnemonics`、`--password`を渡す命令 |
| `key-literal` | 鍵、ニーモニック、種、アカウント、取引の送信について書いた行にある、64桁の16進か、引用符で囲んだ12語から24語の小文字の語の並び。JSONのファイルでは、鍵、ニーモニック、種、署名する人、アカウントを表す名前の欄の値なら、`accounts`の配列の中の値のように別の行に在っても名指します |
| `env-file` | 名前が`.env`で始まるファイルのうち、gitが追跡しているか無視していない物。`.env.example`と`.env.sample`と`.env.template`は除きます |

`keys`は、Solidity、JavaScript、TypeScript、shellのスクリプト、Makefile、justfile、JSONとTOMLとYAMLのファイル(配るスクリプトが読むチェーンごとの設定を含みます)を読み、コメントを除いて調べます。
ただし`key-literal`はコメントも調べます。コメントに書いた鍵もファイルの中に在るからです。
名前が`.env`で始まるファイルは開かず、依存、ビルドの出力、`broadcast/`、`deployments/`、Foundryの`cache/`、隠しフォルダは読みません。

`record`は、`dry-run/`のフォルダを除いた`broadcast/<script>/<chain id>/run-latest.json`と、`ignition/deployments/<deployment id>/journal.jsonl`を読みます。
出す行は次のとおりです。

| 行 | 意味 |
|---|---|
| `contract` | チェーンに載ったコントラクト。チェーン、名前、アドレス、取引、ブロック、送った口座、出どころ(`foundry:<script>`か`ignition:<deployment id>`)を出します |
| `failed` | 受け取りが失敗を示す取引 |
| `pending` | 送ったが受け取りの無い取引 |
| `mismatch` | コントラクトを作ったと記録されているのに、受け取りがそのコントラクトを作ったことを示さない取引 |
| `commit-differs` | 記録のcommitが、配ったcodeと違うかもしれない記録。そのcommitと中身が違い、Foundryが記録を書く前に最後に変えたファイルが在ります。チェーン、commit、出どころ、ファイルを出します |

記録のファイルは、`format`(1)、`chainId`、`contracts`(name、address、tx、block、deployer、source、commit)、`problems`(kind、name、tx、source、`commit-differs`ではcommitとファイル)を持ちます。
毎回ファイルから作り直し、commitはFoundryの記録から取り、無い時は`null`にします。

`commit-differs`のために、`record`はプロジェクトで`git diff --name-only <commit>`と`git ls-files --others`を動かし、出たファイルごとに最後に変えた時刻を読みます。
数えるのは、`test/`と`tests/`の外の`.sol`のファイル(`.t.sol`で終わる物を除きます)と、`foundry.toml`と`remappings.txt`で、記録の`timestamp`より前に最後に変えた物だけです。配った後にcodeを進めても数えません。
プロジェクトがgitのリポジトリでない時と、commitがリポジトリに無い時は、commitを確かめなかったと標準エラーに出します。

## エージェントの配り方

1. `solidity-code`でプロジェクトの版を読み、`list`を動かし、`stale`の印の項目を確かめ直します。コントラクトが頼るERCやEIPの状態は`evm-standards`で確かめます
2. どのチェーンに配るか、そのうちどれが本番のチェーンか、各コントラクトの持ち主を誰にするかを尋ねます
3. `vm.startBroadcast()`を引数なしで呼ぶFoundryのスクリプトか、全ての鍵を`configVariable`の後ろに置くIgnitionのmoduleを書き、`keys`を動かして、書いた物の指摘を直し、ほかの指摘は本人に名指します
4. 配る前に模擬実行し、チェーンごとの命令を本人に渡します。本番のチェーンは`--ledger`か`--trezor`と`--slow`、テストのチェーンは暗号化した鍵の保管(`cast wallet import`と`--account`、またはHardhat 3のkeystore)です。命令は本人が打ちます
5. `record --write`を動かし、`failed`と`pending`と`mismatch`の行を1つずつ調べ、`commit-differs`の行のファイルを本人に伝え、各アドレスを`cast code`で確かめ、本人が同意すれば`forge verify-contract`か`ignition verify`でソースを検証します

## リリースの項目

`release-check`は`skills/release-check/references/items/`に、扱う物ごとに1つのMarkdownのファイルで項目を持ちます。
例えば`chain-evm-support.md`や`openzeppelin-upgrades-validate.md`です。
前書きは、配ることの項目と同じ4つの欄を持ち、話題は次のどれかです。

| 欄 | 持つ物 |
|---|---|
| `topic` | `layout`、`evm`、`tools`のどれか |
| `subject` | 項目が扱う物。例えば`The EVM version each major chain runs` |
| `checked` | 公式の情報で確かめた日。`YYYY-MM-DD`で書きます |
| `source` | 項目のもとにした組織と文書の名前。項目はURLを持ちません |

本文は、確かめた時に成り立っていたことと、リリースで守ることを書きます。
リリースの項目は、確かめてから90日を過ぎると古いと見ます。

## release-checkのスクリプト

`skills/release-check/scripts/release-check.py`は、Python 3の標準ライブラリだけで動き、渡されたJSONのファイルか、ビルドのフォルダの中で見つけたJSONのファイルだけを読みます。`forge build --ast`が各artifactに書く構文木も、その中に在ります。

| 命令 | すること |
|---|---|
| `check` | どの項目も4つの欄と、知っている話題と、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに1行を出します。`ok`か`stale`、話題、確かめた日、名前、扱う物の順で、最後に数を出します |
| `layout <old> <new>` | `forge inspect <Contract> storageLayout --json`の出力か、`--extra-output storageLayout`を付けてビルドしたartifactか、2つの`out/`のフォルダを契約ごとに使い、2つの保存の配置を比べます。問題を見つけると1で終わります |
| `abi <old> <new>` | `forge inspect <Contract> abi --json`の出力か、artifactか、2つの`out/`のフォルダを使い、2つのABIを比べます。関数かeventかerrorが消えたか変わった時は1で終わります |
| `opcodes <build> --evm <version>` | 実行時のcodeとconstructorの中で、そのEVMの版が持たないオペコードを名指し、1つでもあれば1で終わります |

`layout`は次の行を出します。

| 行 | 意味 |
|---|---|
| `removed` | 配ってある版の変数が消え、同じ型の変数がその場所を継いでいません |
| `moved` | 変数が別のslotかoffsetに動きました |
| `retyped` | 変数の型が変わりました。structの中か、mappingの値か、配列の要素の中の変化は`changed inside`と出します |
| `gap` | `__gap`の配列が前と同じslotで終わらず、その後ろの変数が動きました |
| `renamed` | 前の変数の場所に、同じ型の変数が新しい名前で在ります。問題には数えません |
| `slot` | ERC-7201の名前空間のstructが新しい版で別のslotに在ります。前と後のslotを出します。新しい版は、前の版が書いた場所から欄を読みません |
| `not-compared` | その契約のERC-7201の名前空間の保存を比べませんでした。名前空間(ビルドがどれを持つか分からない時は`namespaces`)と理由を出します。この時`layout`は`compatible`を出さず、1で終わります |

変数は名前で突き合わせ、合わなければ場所で突き合わせます。
structとenumの名前は宣言した契約の名前を除いて比べるため、契約の名前を変えても変化に数えません。
フォルダでは、テストとスクリプトのartifact(`*.t.sol/`、`*.s.sol/`)、`build-info/`、Hardhatの`*.dbg.json`のファイルを除き、`--contract`と`--new-contract`で名前の違う2つの契約を比べます。
ERC-7201の名前空間の保存の変数(`@custom:storage-location erc7201:<id>`を付けたstruct)は、solcの保存の配置の出力に在りません。
`layout`は、そのstructを各artifactの構文木から、契約と、契約が継ぐ全ての契約について読み、solcがstructを並べるのと同じ規則で欄を並べ、名前空間ごとに同じ行で比べます。行の名前は`erc7201:<id>.<欄>`で、slotは名前空間のslotから数えます。
名前空間のslotは、契約か継ぐ契約がinline assemblyで`<ポインタ>.slot`に入れる値で、数か定数です。式で書いた定数は計算せず、式どうしで比べます。
artifactが構文木を持たない時(`forge inspect`の出力か、`--ast`無しのビルド)、継ぐ契約がどのartifactにも無い時、ビルドがコンパイラの別々の実行を混ぜた時、欄の型を並べられない時、ビルドが名前空間のslotを入れないか、2つの違う値を入れるか、数でも定数でもない値を入れる時は`not-compared`を出します。

`abi`は`removed-function`、`changed-function`(出力か状態の変更の可否)、`removed-event`、`changed-event`(どの引数がindexedか、anonymousか)、`removed-error`を出します。
足した物は互換で、出しません。`receive`と`fallback`は関数に数えます。

`opcodes`はFoundryとHardhatのartifactを読み、codeの末尾のsolcのmetadataを除き、各`PUSH`の引数を飛ばし、ライブラリの置き場所の印を0のbyteとして数えます。
デプロイ時のcodeは、実行時のcodeより前の、constructorを動かす部分だけを読みます。
EVMの版は`homestead`から`osaka`までで、知らない版は2で終わります。

## エージェントのリリースの確かめ方

1. `solidity-code`でプロジェクトの版を読み、`list`を動かし、`stale`の印の項目を確かめ直します。ERCやEIPの状態は`evm-standards`で確かめます
2. どのチェーンに出すかと、更新の時は配ってあるgitのtagかcommitを尋ねます
3. その版を`git worktree add`で一時的なフォルダに取り出し、2つの版をソースのフォルダから空のフォルダへ、`--extra-output storageLayout`と`--ast`を付けてビルドします。2つのビルドは同じコントラクトを持ちます
4. 2つの版で`layout`と`abi`を動かし、出す先のチェーンごとのEVMの版で`opcodes`を動かし、プロジェクトに在れば`npx @openzeppelin/upgrades-core validate`も動かします
5. ガス代を`forge snapshot --diff`で、大きさを`forge build --sizes`で比べ、配る取引ごとにチェーンの1つの取引のガスの上限(EIP-7825)と照らし、見つけた物ごとにすることを伝え、一時的なworktreeを`git worktree remove --force`で消します。submoduleを持つworktreeは`--force`が要ります

design-formatsのプラグインの`page-design`のスキルが入っていれば、エージェントは手順5の報告を`page-design`の`structure`の書式の順で書きます。結果を先に書き、次に確かめた物と飛ばした物を理由とともに書き、測れなかった値は測れなかったと書き、あなたが行う手順を最後に書きます。
この書式はコンテンツ`page-design/structure`で、`skills/release-check/musubi.json`が任意の準拠で従います。版の範囲`^1.0.0`と、最後に確かめた時の書式のフィンガープリントと、`"optional": true`を持ちます。
`musubi`のコマンドが入っていれば、エージェントは書式を読む前に`musubi check`を回し、失敗したら止まります。design-formatsが入っていない時、`musubi check`は警告を出してこの準拠を飛ばし、エージェントは自分の順で報告します。
書式が変わると、フィンガープリントを確かめ直すまで`musubi check`は`release-check`を拒否します。
`release-check`はほかのプラグインからこれ以外を読みません。

## コントラクトの設計の項目

`contract-design`は`skills/contract-design/references/items/`に、ライブラリかサービスかやり方ごとに1つのMarkdownのファイルで項目を持ちます。
例えば`openzeppelin-5-proxies.md`や`chainlink-vrf.md`です。
前付けはdAppのサービスの項目と同じ4つの欄を持ち、topicは次のどれかです。

| 欄 | 持つ物 |
|---|---|
| `topic` | `upgrades`、`access`、`oracles`、`randomness`、`ordering`、`tokens`のどれか |
| `subject` | 項目が扱うライブラリかサービスかやり方。例えば`Chainlink VRF` |
| `checked` | 公式の出どころで項目を確かめた日。`YYYY-MM-DD`の形 |
| `source` | 項目のもとにした組織と文書の名前。項目はURLを持ちません |

本文には、確かめた時のライブラリかサービスの状態(止まった版など)と、コントラクトの設計が守ることを書きます。
コントラクトの設計の項目は、確かめた日から90日で古いと見ます。
定期の呼び出しを動かすサービスと、取引を中継するサービスと、コントラクトを見張るサービス(Chainlink AutomationやOpenZeppelin Defenderなど)は、dAppのサービスの項目が確かめた日つきで持ちます。
そのため`contract-design`は、それらのサービスについてはエージェントを`dapp-architecture`の項目へ送り、写しを持ちません。
その技が入っていない時は、エージェントがそれらのサービスを公式の文書で確かめます。

## contract-designのスクリプト

`skills/contract-design/scripts/contract-design.py`は、Python 3の標準ライブラリだけで動きます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が4つの欄と、知っているtopicと、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに1行で、`ok`か`stale`と、topicと、確かめた日と、名前と、subjectを出し、最後に件数を出します |

設計書は[doc-formats](../../doc-formats/docs/how-it-works.ja.md)の`design-doc`のスキルの`verify`が確かめます。`verify`は設計書とこのスキルの`templates/sections.md`だけを読み、Contractsの節に日付を求めます。

## エージェントのコントラクトの設計の仕方

1. `list`を動かし、設計が頼るかもしれない項目を読み、`stale`の印の項目は確かめ直します。ERC-4626のようなERCとEIPの状態は`evm-standards`で確かめます
2. 決めることを1つずつ、勧める案を添えて尋ね、依頼が既に答えている事は尋ねません。尋ねられない時は勧める案を採り、Open decisionsの節に仮定として書きます
3. `design-doc`の設計書の書式で、`docs/design/<topic>.md`か、利用者かプロジェクトが設計書を置く所へ設計書を書き、書式が示す所に`templates/sections.md`の節を置き、`Fill in:`の行を全て書き換え、Contractsの節にライブラリとコンパイラの版と、サービスごとに確かめた日を書きます
4. `templates/sections.md`を渡して`design-doc`の`verify`を動かし、名指された節を直し、`references/checklist.md`で設計を見直し、破った決まりを全て直します
5. 判断できなかった決まりと未決を利用者に伝えます

確かめの表は、設計が破ってはならない決まりを持ちます。
状態を変える関数ごとに呼べる者を決めること、テストで確かめられる不変条件、桁と丸めの明示、初期化を閉じること、更新に耐える保存の配置、価格とsequencerの確かめ、誰も選べない乱数、slippageの上限と期限、reentrancyを防ぐこと、送りが失敗しうる所での引き出し式の支払い、SafeERC20と手数料を取るトークン、2段の持ち主の移し替えと止める役で1つの鍵に全権を持たせないこと、timelockで変更を遅らせること、1つの自動実行に頼らないこと、上限のある繰り返しです。

## ウォレットの設計の項目

`wallet-design`は`skills/wallet-design/references/items/`に、コントラクトか規格かサービスかやり方ごとに1つのMarkdownのファイルで項目を持ちます。
例えば`entrypoint-versions.md`や`permit2-approvals.md`です。
前付けはdAppのサービスの項目と同じ4つの欄を持ち、topicは次のどれかです。

| 欄 | 持つ物 |
|---|---|
| `topic` | `accounts`、`signatures`、`approvals`、`gas`、`payments`のどれか |
| `subject` | 項目が扱うコントラクトか規格かサービスかやり方。例えば`x402 payments over HTTP` |
| `checked` | 公式の出どころで項目を確かめた日。`YYYY-MM-DD`の形 |
| `source` | 項目のもとにした組織と文書の名前。項目はURLを持ちません |

本文には、確かめた時のコントラクトか規格かサービスの状態(bundlerが動かすEntryPointの版など)と、ウォレットの設計が守ることを書きます。
ウォレットの設計の項目は、確かめた日から90日で古いと見ます。
取引を中継するサービスと見張るサービスは、dAppのサービスの項目が確かめた日つきで持ちます。
そのため`wallet-design`は、それらのサービスについてはエージェントを`dapp-architecture`の項目へ送り、その技が入っていない時は公式の文書へ送ります。

## wallet-designのスクリプト

`skills/wallet-design/scripts/wallet-design.py`は、Python 3の標準ライブラリだけで動きます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が4つの欄と、知っているtopicと、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに1行で、`ok`か`stale`と、topicと、確かめた日と、名前と、subjectを出し、最後に件数を出します |

設計書は[doc-formats](../../doc-formats/docs/how-it-works.ja.md)の`design-doc`のスキルの`verify`が確かめます。`verify`は設計書とこのスキルの`templates/sections.md`だけを読み、Accountsの節に日付を求めます。

## エージェントのウォレットの設計の仕方

1. `list`を動かし、設計が頼るかもしれない項目を読み、`stale`の印の項目は確かめ直します。ERC-4337やEIP-7702のようなERCとEIPの状態は`evm-standards`で確かめます
2. 決めることを1つずつ、勧める案を添えて尋ね、依頼が既に答えている事は尋ねません。尋ねられない時は勧める案を採り、Open decisionsの節に仮定として書きます
3. `design-doc`の設計書の書式で、`docs/design/<topic>.md`か、利用者かプロジェクトが設計書を置く所へ設計書を書き、書式が示す所に`templates/sections.md`の節を置き、`Fill in:`の行を全て書き換え、Accountsの節にアカウントのコントラクトとEntryPointの版と、サービスごとに確かめた日を書きます
4. `templates/sections.md`を渡して`design-doc`の`verify`を動かし、名指された節を直し、`references/checklist.md`で設計を見直し、破った決まりを全て直します
5. 判断できなかった決まりと未決を利用者に伝えます

確かめの表は、設計が破ってはならない決まりを持ちます。
鍵を`.env`のファイルや環境変数やコードに置かないこと、取り戻し方と鍵の替え方、chain IDとnonceと期限を持つEIP-712の署名、スマートアカウントの署名のためのERC-1271とERC-6492、範囲と量と期限を限り利用者が取り消せる許可と承認、EntryPointの版を決めること、他の誰も初期化できず古い保存に罠を残さないEIP-7702の委任先、上限のある肩代わり、支払いの上限と払い先を限ったエージェント、利用者が読める署名の求めです。

## 複数のチェーンの設計の項目

`multichain-design`は`skills/multichain-design/references/items/`に、道具かプロトコルか規格かやり方ごとに1つのMarkdownのファイルで項目を持ちます。
例えば`circle-cctp-v2.md`や`layerzero-dvn-config.md`です。
前付けはdAppのサービスの項目と同じ4つの欄を持ち、topicは次のどれかです。

| 欄 | 持つ物 |
|---|---|
| `topic` | `deployment`、`bridges`、`messaging`、`tokens`のどれか |
| `subject` | 項目が扱う道具かプロトコルか規格かやり方。例えば`Circle CCTP V1 (Legacy) and V2` |
| `checked` | 公式の出どころで項目を確かめた日。`YYYY-MM-DD`の形 |
| `source` | 項目のもとにした組織と文書の名前。項目はURLを持ちません |

本文には、確かめた時の道具かプロトコルか規格の状態(終わる版や、勧め方を変えた事件など)と、複数のチェーンにまたがる設計が守ることを書きます。
複数のチェーンの設計の項目は、確かめた日から90日で古いと見ます。
取引を中継するサービスと見張るサービスは、dAppのサービスの項目が確かめた日つきで持ちます。
そのため`multichain-design`は、それらのサービスについてはエージェントを`dapp-architecture`の項目へ送り、その技が入っていない時は公式の文書へ送ります。

## multichain-designのスクリプト

`skills/multichain-design/scripts/multichain-design.py`は、Python 3の標準ライブラリだけで動きます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が4つの欄と、知っているtopicと、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに1行で、`ok`か`stale`と、topicと、確かめた日と、名前と、subjectを出し、最後に件数を出します |

設計書は[doc-formats](../../doc-formats/docs/how-it-works.ja.md)の`design-doc`のスキルの`verify`が確かめます。`verify`は設計書とこのスキルの`templates/sections.md`だけを読み、Messages and verificationの節に日付を求めます。

## エージェントの複数のチェーンの設計の仕方

1. `list`を動かし、設計が頼るかもしれない項目を読み、`stale`の印の項目は確かめ直します。ERC-7802やERC-7955のようなERCとEIPの状態は`evm-standards`で確かめます
2. 決めることを1つずつ、勧める案を添えて尋ね、依頼が既に答えている事は尋ねません。尋ねられない時は勧める案を採り、Open decisionsの節に仮定として書きます
3. `design-doc`の設計書の書式で、`docs/design/<topic>.md`か、利用者かプロジェクトが設計書を置く所へ設計書を書き、書式が示す所に`templates/sections.md`の節を置き、`Fill in:`の行を全て書き換え、Messages and verificationの節にプロトコルごとの版と確かめた日を書きます
4. `templates/sections.md`を渡して`design-doc`の`verify`を動かし、名指された節を直し、`references/checklist.md`で設計を見直し、破った決まりを全て直します
5. 判断できなかった決まりと未決を利用者に伝えます

確かめの表は、設計が破ってはならない決まりを持ちます。
同じアドレスに同じコードが在ること、チェーンと送り手とnonceに縛られ1度だけ処理されるメッセージ、欠けない供給量と1つの正規のトークン、finalityを待つこと、1つの検証者に頼らないこと、どの向きにもかかる上限、止まったメッセージと失敗したメッセージの取り戻し方、チェーンごとの停止、チェーンをまたいで共有しない管理の鍵、揃った桁、誰かが払う届け先のガス代です。

## dAppのサービスの項目

`dapp-architecture`は`skills/dapp-architecture/references/items/`に、サービスかネットワークか道具ごとに1つのMarkdownのファイルで項目を持ちます。
例えば`openzeppelin-defender-relayer.md`や`ethereum-testnets.md`です。
前付けは次の欄を持ちます。

| 欄 | 持つ物 |
|---|---|
| `topic` | `indexing`、`transactions`、`automation`、`monitoring`、`networks`、`admin`、`storage`のどれか |
| `subject` | 項目が扱うサービスかネットワークか道具。例えば`Chainlink Automation and Chainlink CRE` |
| `checked` | 公式の出どころで項目を確かめた日。`YYYY-MM-DD`の形 |
| `source` | 項目のもとにした組織と文書の名前。項目はURLを持ちません |

本文には、確かめた時のサービスの状態(終了や非推奨など)と、それを使う設計が守ることを書きます。
提供されるサービスは規格より頻繁に製品を変えるので、サービスの項目は確かめた日から90日で古いと見ます。

## dapp-architectureのスクリプト

`skills/dapp-architecture/scripts/dapp-architecture.py`は、Python 3の標準ライブラリだけで動きます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が4つの欄と、知っているtopicと、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに1行で、`ok`か`stale`と、topicと、確かめた日と、名前と、subjectを出し、最後に件数を出します |

設計書は[doc-formats](../../doc-formats/docs/how-it-works.ja.md)の`design-doc`のスキルの`verify`が確かめます。`verify`は設計書とこのスキルの`templates/sections.md`だけを読み、Componentsの節に日付を求めます。

## エージェントのdAppの構成の設計の仕方

1. `list`を動かし、設計で使うかもしれないサービスの項目を読み、`stale`の印の項目は確かめ直します。ERC-4337やEIP-7702のようなERCとEIPの状態は`evm-standards`で確かめます
2. 決めることを1つずつ、勧める案を添えて尋ね、依頼が既に答えている事は尋ねません。尋ねられない時は勧める案を採り、Open decisionsの節に仮定として書きます
3. `design-doc`の設計書の書式で、`docs/design/<topic>.md`か、利用者かプロジェクトが設計書を置く所へ設計書を書き、書式が示す所に`templates/sections.md`の節を置き、`Fill in:`の行を全て書き換え、Componentsの節に外のサービスごとに確かめた日を書きます
4. `templates/sections.md`を渡して`design-doc`の`verify`を動かし、名指された節を直し、`references/checklist.md`で設計を見直し、破った決まりを全て直します
5. 判断できなかった決まりと未決を利用者に伝えます

確かめの表は、設計が破ってはならない決まりを持ちます。
秘密と個人の情報をチェーンに置かないこと、書き込みの経路ごとに送り手とガス代を払う者を決めること、中継の鍵を管理の鍵と分けること、肩代わりする署名にchain IDとnonceと期限を束ねること、画面をインデクサかDBから読むこと、reorgに耐える読み取り、冪等で配った時のblockから作り直せる取り込み、1つの鍵に全権を持たせないこと、timelockで変更を遅らせること、止める役を分けること、環境ごとに鍵とaddressを分けることです。

## 金融の規格の項目

`financial-standards`は`skills/financial-standards/references/items/`に、規格ごとに1つのMarkdownのファイルで項目を持ちます。
例えば`iso-20022-cbpr-plus-release.md`や`fix-latest.md`です。
前付けは次の欄を持ちます。

| 欄 | 持つ物 |
|---|---|
| `standard` | `iso-20022`、`fix`、`fpml`、`cdm`、`lei`、`xbrl`のどれか |
| `version` | 項目を確かめた時に使われている版か改版かprofile。例えば`CBPR+ SR2025`や`FIX Latest EP312` |
| `checked` | 公式の出どころで版を確かめた日。`YYYY-MM-DD`の形 |
| `source` | 項目のもとにした組織と文書の名前。項目はURLを持ちません |

本文には、使われている版と、最近の変更と、その規格で設計する時に守ることを書きます。
これらの規格の改版は多くても年に数回なので、規格の項目は確かめた日から180日で古いと見ます。

## financial-standardsのスクリプト

`skills/financial-standards/scripts/financial-standards.py`は、Python 3の標準ライブラリだけで動きます。

| 命令 | すること |
|---|---|
| `check` | 全ての項目が4つの欄と、知っている規格と、実在する日付を持つかを確かめます。持たない項目を名指して1で終わります |
| `list` | 項目ごとに1行で、`ok`か`stale`と、規格と、版と、確かめた日と、名前を出し、最後に件数を出します |

設計書は[doc-formats](../../doc-formats/docs/how-it-works.ja.md)の`design-doc`のスキルの`verify`が確かめます。`verify`は設計書とこのスキルの`templates/sections.md`だけを読み、Standard and businessの節に日付を求めます。

## エージェントの設計書の書き方

1. `list`を動かし、依頼の規格の項目を読み、`stale`の印の項目は確かめ直します。ERC-3643のようなERCとEIPの状態は`evm-standards`で確かめます
2. 決めることを1つずつ、勧める案を添えて尋ね、依頼が既に答えている事は尋ねません。尋ねられない時は勧める案を採り、Open decisionsの節に仮定として書きます
3. `design-doc`の設計書の書式で、`docs/design/<topic>.md`か、利用者かプロジェクトが設計書を置く所へ設計書を書き、書式が示す所に`templates/sections.md`の節を置き、`Fill in:`の行を全て書き換えます
4. `templates/sections.md`を渡して`design-doc`の`verify`を動かし、名指された節を直し、`references/checklist.md`で設計を見直し、破った決まりを全て直します
5. 判断できなかった決まりと未決を利用者に伝えます

確かめの表は、設計が破ってはならない決まりを持ちます。
私的な情報をチェーンに置かないこと、ハッシュだけでなくdomainに束ねた塩つきのcommitmentを使うこと、コントラクトは署名した証跡だけを受けてXMLを解かないこと、内部の案件のIDで相関すること、報告を決済と見ないこと、台帳を法的な最終性と見ないこと、取り消せる権限、追記で行う訂正、版とprofileの固定、オフチェーンの責務の分離、再送できない証跡、冪等な書き込みです。

## しないこと

- 項目を書き換えません。新しい事実は答えに書き、プラグインのファイルには書きません
- 検索には規格の番号か名前、ネットワークか枠組みの名前、または道具かサービスの名前と版だけを使い、あなたのプロジェクトについては何も送りません
- 秘密鍵とニーモニックをファイルに書かず、鍵を渡す命令を断ります
- `contract-tests`はテストを通すためにコントラクトを変えず、書くのはテストのファイルだけです
- `contract-deploy`は鍵とニーモニックとpasswordを読まず、署名も取引の送信もせず、`--private-key`か`--mnemonic`か`--password`を渡す命令を断り、Foundryの`cache/`を読まず、本人が同意した時だけソースを検証します
- `release-check`は鍵とニーモニックを読まず、署名せず、鍵を渡す命令を断り、プロジェクトに何も書かず、作った一時的なworktreeを消します
- `contract-design`は鍵を読まず、署名せず、Solidityとテストと配る命令を書きません
- `wallet-design`は鍵を読まず、署名せず、鍵を渡す命令を断り、Solidityとウォレットのコードとテストと配る命令を書きません
- `multichain-design`は鍵を読まず、署名せず、鍵を渡す命令を断り、Solidityとブリッジのコードとテストと配る命令を書きません
- `dapp-architecture`は鍵を読まず、署名せず、コントラクトとABIとAPIの定義と画面のコードとテストとスクリプトを書きません
- `financial-standards`は鍵を読まず、署名せず、コントラクトとschemaとABIとAPIの定義とテストとスクリプトを書きません
- `.env`のファイルを読みません
- 答えた後に何も残しません
