# EVM Dev

ERCが確定したか、EIPがEthereumのメインネットで動いているか、L2のネットワークとEthereumのL1の今後がどうなっているかを答え、プロジェクトが使う版に合わせてSolidityとそのテストを書き、鍵を手元に置いたままコントラクトを配り、出す前に配ってある版と出す先のチェーンに照らして確かめ、コントラクトと、ウォレットと署名と、複数のチェーンにまたがるアプリと、dAppの部品の組み方と、ISO 20022やFIXなどの金融の規格を使うアプリを設計します。どれも、エージェントの記憶ではなく、公式の文書で確かめた項目に基づきます。

[English](README.md) · 日本語

エージェントの知識は学習の時点で止まりますが、規格と道具はその後も動きます。
EIPがネットワークの更新で入り、L2が状態を証明する仕組みを替え、広く呼ばれている「ERC」が実はどこにも取り込まれておらず、ライブラリが読み込むファイルの名前を変え、フレームワークがスクリプトの呼ぶ関数を非推奨にし、取引の中継や自動実行のサービスが終わり、決済の規格の改版が延期されます。
このプラグインは、そのどれについても、公式の文書で確かめた日と、もとにした文書の名前を持つ項目を持ちます。
`contract-deploy`は、本番のチェーンへの配布にはLedgerかTrezorのハードウェアウォレットでだけ署名させ、テストのチェーンへの配布には暗号化したキーストアを使います。

| スキル | すること |
|---|---|
| `evm-standards` | ERCが確定したか、EIPが動いているか、コントラクトとウォレットで何ができるようになるかを、ERCとEIPの42の項目から答えます。できることから規格を探し、あなたが記事の一覧を名指した時は、答えに出す規格の記事のリンクを添えます |
| `ethereum-knowledge` | L2のネットワークとロールアップの枠組みの仕組みと今の状態、EthereumのL1の今後の作り替え、コンセンサスだけを変えるEIPが動いているかを、53の項目から答えます。ERCと、コントラクトとウォレットでできることを変えるEIPは`evm-standards`に任せます |
| `solidity-code` | FoundryとHardhatのプロジェクトで、プロジェクトが使うsolcとOpenZeppelinとforge-stdとFoundryとHardhatの版に合わせてコントラクトを書き、古い書き方を探してからビルドとテストを回します |
| `contract-tests` | FoundryかHardhatのプロジェクトで、コントラクトごとに確かめる点を挙げてから、単体とfuzzとinvariantのテストを書きます。kiwaが入っていればkiwaに書かせます。どのテストも触れていない点を名指し、テストを回します |
| `contract-deploy` | 鍵に触れないFoundryとHardhat Ignitionの配る命令を書き、プロジェクトが鍵を危なく扱う所を全て名指し、本番のチェーンはハードウェアの財布、テストのチェーンは暗号化した鍵の保管で署名する命令を渡し、配った後にチェーンごとの出したアドレスを記録して確かめます |
| `release-check` | 出す前にコントラクトを確かめます。保存の配置とABIを配ってある版と比べ、出す先のチェーンのEVMが動かせないオペコードを名指し、プロジェクトにOpenZeppelinの更新の検査が在れば回し、ガス代と大きさを比べます |
| `contract-design` | 書く前にコントラクトを設計します。決めることを1つずつ尋ね、コントラクトの分け方、トークンの規格、不変条件、役割、更新の方式、価格、取引の順、乱数、外への呼び出しを1つの設計書に書き、節を確かめてから確かめの表で見直します |
| `wallet-design` | ウォレットと署名を設計します。決めることを1つずつ尋ね、鍵の持ち方と取り戻し方、ERC-4337とEIP-7702のアカウント、署名による許可、承認、ガス代を誰が払うか、AIエージェントの支払いを1つの設計書に書き、節を確かめてから確かめの表で見直します |
| `multichain-design` | 複数のチェーンにまたがるアプリを設計します。決めることを1つずつ尋ね、同じアドレスでの展開、チェーンの間の資産の移し方、チェーンをまたぐメッセージの検証、片側だけ終わった時の扱いを1つの設計書に書き、節を確かめてから確かめの表で見直します |
| `dapp-architecture` | dAppの部品の組み方を設計します。決めることを1つずつ尋ね、取引を誰が送りガス代を誰が払うか、チェーンの読み取り、データの置き場所、環境、管理の鍵、監視を1つの設計書に書き、節を確かめてから確かめの表で見直します |
| `financial-standards` | ISO 20022、FIX、FpML、CDM、LEI、XBRLを使い、オンチェーンとオフチェーンの部分を持つアプリを設計します。決めることを1つずつ尋ね、雛形から1つの設計書を書き、節を確かめてから確かめの表で見直します |

```
evm-standards:  List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
ethereum-knowledge:  List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
solidity-code:  Read the project's versions ──> Read the items for them ──> Write ──> Scan, build, and test
contract-tests:  Read the versions and items ──> List what needs a test ──> Write the tests, or have kiwa write them ──> Name what no test covers ──> Run the tests
contract-deploy:  Read the versions and items ──> Write the deploy script ──> Check the key handling ──> Simulate, then the user broadcasts ──> Record and verify
release-check:  Read the versions and items ──> Build the deployed version ──> Compare layouts and ABIs ──> Find opcodes the chains lack ──> Report and clean up
contract-design:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
wallet-design:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
multichain-design:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
dapp-architecture:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
financial-standards:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install evm-dev@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add evm-dev@agent-shuriken
codex plugin add doc-formats@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install evm-dev@agent-shuriken
copilot plugin install doc-formats@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/evm-standards   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/ethereum-knowledge
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/solidity-code
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/contract-tests
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/contract-deploy
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/release-check
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/contract-design
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/wallet-design
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/multichain-design
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/dapp-architecture
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/financial-standards
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/doc-formats/skills/design-doc
```

5つの設計のスキルは、[doc-formats](../doc-formats)のpluginの`design-doc`のスキルが持つ設計書の書式で書きます。
Claude Codeはevm-devと一緒にdoc-formatsを入れます。Codex、GitHub Copilot CLI、Gemini CLIでは、上の行のうちdoc-formatsを名指す行で入れます。
`SKILL.md`を読むほかのエージェントでは、各リリースに付いているスキルのzipをエージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

`evm-standards`は、規格の状態を尋ねると始まります。
例えば「EIP-7702はメインネットで動いている?」や「ERC-7281を確定した規格として書いてよい?」と尋ねます。
「パスキーの署名をコントラクトで検証できる規格は?」のように、できることから規格を尋ねても始まります。
`ethereum-knowledge`は、L2かEthereumのL1の今後がどうなっているか、コンセンサスだけを変えるEIPが動いているかを尋ねると始まります。
例えば「PeerDASはメインネットで動いている?」や「OP Stackは今どうやって引き出しを証明している?」と尋ねます。
`solidity-code`は、コントラクトを書くか変えるよう頼むと始まります。
例えば「このFoundryのプロジェクトに、止められるERC-20のトークンを足して」と頼みます。
`contract-tests`は、コントラクトのテストを頼むと始まります。
例えば「src/Vault.solのテストを足して」と頼みます。
`contract-deploy`は、コントラクトを配るか、配った物の記録を頼むと始まります。
例えば「src/Vault.solをSepoliaに配ってからBaseに配って」や「前に回したforge scriptで出した物を書き留めて」と頼みます。
`release-check`は、コントラクトを出してよいか、更新が安全かを尋ねると始まります。
例えば「Vaultをsrc/のcodeへ更新して安全か」や「このビルドはまだShanghaiのチェーンで動くか」と尋ねます。
`contract-design`は、書く前にコントラクトの設計を頼むと始まります。
例えば「このトークンの販売のコントラクトを設計して。役割と更新の方式と価格の読み方も」と頼みます。
`wallet-design`は、アプリのウォレットか署名の設計を頼むと始まります。
例えば「利用者にERC-4337のスマートアカウントを持たせるか、EIP-7702を使うか決めて。ガス代を誰が払うかも」と頼みます。
`multichain-design`は、複数のチェーンにまたがるアプリの設計を頼むと始まります。
例えば「このトークンをEthereumとBaseの間で動かす方法を設計して」と頼みます。
`dapp-architecture`は、dAppをどう組むかを頼むと始まります。
例えば「このマーケットの構成を設計して。ガス代を誰が払うか、チェーンをどう読むか、管理の鍵を誰が持つか」と頼みます。
`financial-standards`は、金融の規格を使う設計を頼むと始まります。
例えば「ISO 20022の支払いのmessageを決済のコントラクトにどう対応させるかを設計して」と頼みます。
呼び出すこともできます。
Claude Codeでは`/evm-dev:evm-standards`か`/evm-dev:ethereum-knowledge`か`/evm-dev:solidity-code`か`/evm-dev:contract-tests`か`/evm-dev:contract-deploy`か`/evm-dev:release-check`か`/evm-dev:contract-design`か`/evm-dev:wallet-design`か`/evm-dev:multichain-design`か`/evm-dev:dapp-architecture`か`/evm-dev:financial-standards`を実行し、Codexでは`$`を入力して**EVM Standards**か**Ethereum Knowledge**か**Solidity Code**か**Contract Tests**か**Contract Deploy**か**Release Check**か**Contract Design**か**Wallet Design**か**Multichain Design**か**dApp Architecture**か**Financial Standards**を選びます。
GitHub Copilot CLIでは依頼の文に`/evm-standards`か`/ethereum-knowledge`か`/solidity-code`か`/contract-tests`か`/contract-deploy`か`/release-check`か`/contract-design`か`/wallet-design`か`/multichain-design`か`/dapp-architecture`か`/financial-standards`と書き、Gemini CLIでは作業を説明します。

### 規格を確かめる

1. エージェントが項目を確かめた日付きで並べ、古い項目に印を付けます
2. エージェントが質問に要る項目を読みます
3. 古い項目は、エージェントが公式のERCかEIPの文書で確かめ直します。確かめられない時はそう伝えます
4. エージェントが状態と確かめた日と出どころを添えて答えます

一覧は次のように出ます。

```text
ok     specified  2026-11-10 eip-7692-eof
ok     live       2026-11-09 eip-7702-set-code-for-eoas
ok     live       2026-11-11 eip-7951-secp256r1-precompile
ok     announced  2026-11-10 erc-7281-xerc20
41 items, 0 stale as of 2026-11-16
```

答えは次のようになります。

```text
Yes. EIP-7951 adds a P256VERIFY precompile at 0x100 that costs 6900 gas.
It went live on mainnet with the Fusaka upgrade on 2025-12-03.
Status: live, checked 2026-11-11, source: the EIP-7951 document and EIP-7607 (the Fusaka meta EIP).
```

### できることから規格を探す

1. エージェントが、したいことを表す語を英語とあなたの言語で並べ、項目と、名指した記事の一覧から探します
2. エージェントが、当たった規格を、項目か公式の文書で確かめた状態を添えて答えます
3. 記事の一覧を名指した時は、答えに出す規格の記事が在れば、エージェントがその題とリンクを添えます

探した結果は次のように出ます。
記事の一覧を名指していない時は、記事の行を出しません。

```text
item eip-7951-secp256r1-precompile live 2026-11-11 3 Contracts can cheaply verify P-256 (secp256r1) signatures, such as passkey, WebAuthn, Secure Enclave, and Android Keystore signatures, with P256VERIFY at 0x100.
items: 1 matched
articles: no article index is named
```

記事を添えさせるには、一覧のURLかfileのpathを`~/.evm-dev/article-index`に書くか、`EVM_DEV_INDEX_URL`に書きます。
両方在る時は`EVM_DEV_INDEX_URL`を使います。
一覧はllms.txtの箇条書きの形で1行に1つの記事を書き、題は`[ERC<番号>]`か`[EIP<番号>]`で始めます。

```text
- [\[EIP7951\] パスキーの署名を確かめる](https://example.com/articles/eip-7951.md): コントラクトがP-256の署名を確かめる仕組みです。
```

### L2とL1の今後を確かめる

1. エージェントが項目を確かめた日付きで並べ、古い項目に印を付けます
2. エージェントが質問に要る項目を読みます
3. 古い項目は、エージェントがネットワークか枠組みかEIPの公式の文書で確かめ直します。確かめられない時はそう伝えます
4. エージェントが状態と確かめた日と出どころを添えて答えます

ERCと、コントラクトとウォレットでできることを変えるEIPの質問は、`evm-standards`が答えます。
一覧は次のように出ます。

```text
ok     live       2026-11-11 eip-7594-peerdas
ok     specified  2026-11-16 eip-7805-focil
ok     live       2026-11-11 l2beat-stages
ok     live       2026-11-16 op-stack-fault-proofs
51 items, 0 stale as of 2026-11-22
```

答えは次のようになります。

```text
Yes. PeerDAS (EIP-7594) has each node receive only part of the blob data and sample columns from other nodes to check that the whole was published.
It went live on mainnet with the Fusaka upgrade on 2025-12-03.
Status: live, checked 2026-11-11, source: the EIP-7594 document and EIP-7607 (the Fusaka meta EIP).
```

### コントラクトを書く

1. エージェントがプロジェクトのフレームワークと版を読み、プロジェクトの書き方に合わせます
2. エージェントがその版の項目を読み、古い項目は確かめ直します
3. エージェントがプロジェクトのライブラリ(OpenZeppelinか、既に使っている別のライブラリ)でコントラクトを書きます
4. エージェントが書いた物から、プロジェクトの版で変わった書き方を探し、ビルドとテストを回します。回せない時はそう伝えます

プロジェクトの版は次のように出ます。

```text
framework     foundry
solc          0.8.34
openzeppelin  5.7.0
forge-std     1.17.0
foundry       1.9.0
hardhat       none
pragma        ^0.8.24
```

探した結果は、ファイルと行と項目を出し、行の中身は出しません。

```text
src/UserOpInspector.sol:4 openzeppelin-5.7-erc4337-drops-draft
src/Pass.sol:16 ethereum-eip-7702-eoa-checks
scan: 2 matches; 0 items not judged
```

### コントラクトをテストする

1. エージェントがプロジェクトの版と、テストの道具の項目を読み、古い項目は確かめ直します
2. エージェントが、コントラクトごとにテストで確かめる点を挙げます。外から呼べる関数、独自のerror、event、呼べる人を限る決まり、数を受ける関数、合計が合うはずの残高です
3. kiwaのプラグインのスキルが入っている時は、エージェントがその一覧をkiwaに渡し、kiwaにテストを書かせます。入っていない時は、forgeか、プロジェクトが使うHardhatのテストの道具で、単体とfuzzとinvariantのテストを書きます
4. エージェントが、どのテストも触れていない点を名指してテストを足し、テストを回します。回せない時はそう伝えます。テストが不具合を示した時は、コントラクトを変えずに不具合を伝えます

一覧は次のように出ます。

```text
invariant Vault src/Vault.sol:6
error Vault.ZeroAmount src/Vault.sol:7
error Vault.InsufficientBalance src/Vault.sol:8
error Vault.NotOwner src/Vault.sol:9
error Vault.Paused src/Vault.sol:10
event Vault.Deposited src/Vault.sol:12
event Vault.Withdrawn src/Vault.sol:13
event Vault.PausedSet src/Vault.sol:14
function Vault.deposit src/Vault.sol:30
function Vault.withdraw src/Vault.sol:37
fuzz Vault.withdraw src/Vault.sol:37
function Vault.setPaused src/Vault.sol:48
access Vault.setPaused src/Vault.sol:48
points: 13 in 1 contract
```

確かめた結果は点を名指し、テストの中身は出しません。

```text
uncovered invariant Vault src/Vault.sol:6
uncovered access Vault.setPaused src/Vault.sol:48
uncovered: 2 of 13 points have no test
```

### コントラクトを配る

1. エージェントがプロジェクトの版と、鍵の保管とハードウェアの財布と配った記録と検証の項目を読み、古い項目は確かめ直します
2. エージェントが、署名する人を命令の引数に任せるFoundryのスクリプトか、鍵を`configVariable`の後ろに置くHardhat Ignitionのmoduleを書きます
3. エージェントが、プロジェクトが鍵を危なく扱う所を全て名指します。環境変数から読む鍵、`--private-key`か`--mnemonic`か`--password`を渡す命令、ファイルに書いた鍵(配るスクリプトが読むJSONの設定のファイルを含みます)、gitが追跡しているか無視していない`.env`のファイルです
4. エージェントが配る前に模擬実行し、チェーンごとの命令を渡します。本番のチェーンはハードウェアの財布と`--slow`、テストのチェーンは暗号化した鍵の保管です。命令はあなたが打ち、署名を承認します。エージェントは鍵を見ません
5. エージェントがチェーンごとのコントラクトを`deployments/<chain id>.json`に記録し、失敗した取引、受け取りの無い取引、作ったはずのコントラクトを受け取りが示さない取引を名指し、送る前に変えたファイルが記録のcommitと違う時はそう伝え、各アドレスにcodeが在るかを確かめ、あなたが同意すればソースを検証します

鍵の扱いの確かめは、種類とファイルと行だけを出し、行の中身は出しません。

```text
env-key Makefile:4
key-flag Makefile:4
keys: 2 findings in 6 files read; change each one to an encrypted keystore or a hardware wallet
```

記録は、チェーンに載った物と、見るべき取引を並べます。

```text
contract 11155111 Vault 0x234b5a9f35e11c182d81e4e30682b5febcdcc060 tx 0xf12dfc147716ec611d7e1fcc9b6946dfa39421b2af650bba90390d065ee98891 block 7100001 from 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf source foundry:DeployVault.s.sol
contract 8453 Vault 0x1534aac5b2be5f3ce3502106a257c8bc7c1ac23d tx 0xc7eee6b4d5440a8a2d8e6ae851040e23774b242ef147706c0d3b0a83cdb6a747 block 38200001 from 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf source foundry:DeployVault.s.sol
failed 11155111 FeeRouter tx 0xd38e9b9179d8361ea428c5f90b987a1c93fa41744591b611441104ef40fd91b8 source foundry:DeployVault.s.sol
pending 8453 Oracle tx 0xc716db5108b741d36dc98b163ef3864bab9ae80e0e6b33f4141ce4c7378dbbbe source foundry:DeployVault.s.sol
wrote deployments/8453.json
wrote deployments/11155111.json
record: 2 contracts on 2 chains, 2 transactions to look at
```

### リリースを確かめる

1. エージェントがプロジェクトの版と、チェーンごとのEVMの版と1つの取引のガスの上限と保存の配置と道具の項目を読み、古い項目は確かめ直します
2. 更新の時は、エージェントが配ってあるgitのtagかcommitを一時的なworktreeに取り出し、それと新しい版を同じソースのフォルダから、保存の配置と構文木(`--ast`)をビルドの出力に含めてビルドします
3. エージェントが2つの保存の配置を比べ、消えた変数、置き場所が動いた変数、型が変わった変数をstructの中とERC-7201の名前空間のstructの中まで名指し、終わりの位置が動いた`__gap`を名指します。名前空間の保存を比べられなかったコントラクトは名指し、通しません。ABIを比べ、消えたか形の変わった関数とeventとerrorを名指します
4. エージェントが、出す先のチェーンのEVMの版が持たないオペコードを、実行時のcodeとconstructorの両方で名指し、コンパイラの設定で直るか、codeを変える要があるかを伝えます
5. プロジェクトにOpenZeppelinの更新の検査が在れば、エージェントはそれも回して両方の結果を伝えます。ガス代を`forge snapshot --diff`で、大きさを`forge build --sizes`で比べ、配る取引ごとにチェーンのガスの上限と照らし、一時的なworktreeを消します

保存の配置の比べは、更新した後に違う値を読む変数を名指します。

```text
retyped Vault positions mapping(address => struct Position) changed inside
gap Vault __gap ends at slot 51 instead of 50
moved Vault version 50:0 -> 51:0
moved Vault initialized 51:0 -> 52:0
layout: 4 problems in 1 contract compared (0 renamed)
```

オペコードの確かめは、古いEVMの版のチェーンが断る物を名指します。

```text
opcode Vault runtime MCOPY needs cancun
opcode Vault runtime TLOAD needs cancun
opcode Vault runtime TSTORE needs cancun
opcodes: 3 opcodes the shanghai EVM lacks in 1 contract
```

### コントラクトを設計する

1. エージェントがプロキシ、権限の管理、価格のフィード、乱数、非公開の中継、トークンの扱いの項目を並べ、古い項目は確かめ直します
2. エージェントが決めることを1つずつ、勧める案を添えて尋ねます。コントラクトがすることと守る上限、トークンとその規格、役割を誰が持つか、更新できるようにするか、価格と乱数をどこから取るかを尋ねます。尋ねられない時は勧める案を採り、仮定として書きます
3. エージェントが`design-doc`の設計書の書式でプロジェクトに設計書を書き(既定は`docs/design/<topic>.md`)、9つの節を埋めます。節は目的と範囲、コントラクト、トークンの規格、状態と不変条件、役割と統治、更新、価格と取引の順と乱数、外への呼び出しと失敗、未決です
4. エージェントが節を確かめ、確かめの表で設計を見直し、判断できなかった決まりと未決の事を伝えます

項目は次のように並びます。

```text
ok     oracles      2026-11-17 chainlink-data-feeds Chainlink Data Feeds
ok     randomness   2026-11-17 chainlink-vrf Chainlink VRF
ok     ordering     2026-11-17 flashbots-protect Flashbots Protect and private transaction relays
ok     upgrades     2026-11-17 openzeppelin-5-proxies OpenZeppelin Contracts 5.x proxies and upgradeable contracts
6 items, 0 stale as of 2026-11-17
```

確かめは節の名前を出し、設計書の中身は出しません。

```text
no checked date: Contracts
missing: Upgrades
contract-design: 2 problems; fill in or add each section named above
```

### ウォレットと署名を設計する

1. エージェントがEntryPointの版、EIP-7702の委任、ウォレットの権限、Permit2、paymasterのサービス、x402の項目を並べ、古い項目は確かめ直します
2. エージェントが決めることを1つずつ、勧める案を添えて尋ねます。ウォレットを使う人と守る上限、利用者とエージェントが持つアカウントの種類、鍵を誰が持ち失くした鍵をどう取り戻すか、利用者が何に署名し何を承認するか、ガス代を誰が払いAIエージェントがどう払うかを尋ねます。尋ねられない時は勧める案を採り、仮定として書きます
3. エージェントが`design-doc`の設計書の書式でプロジェクトに設計書を書き(既定は`docs/design/<topic>.md`)、9つの節を埋めます。節は目的と使う人、アカウント、鍵と取り戻し方、署名と許可、承認、ガス代と肩代わり、エージェントの支払い、チェーンと環境、未決です
4. エージェントが節を確かめ、確かめの表で設計を見直し、判断できなかった決まりと未決の事を伝えます

項目は次のように並びます。

```text
ok     accounts     2026-11-17 eip-7702-delegation EIP-7702 delegation and its initialization
ok     accounts     2026-11-17 entrypoint-versions ERC-4337 EntryPoint v0.8 and v0.9
ok     gas          2026-11-17 erc-7677-paymaster-service EIP-5792 wallet_sendCalls and the ERC-7677 paymaster service
ok     signatures   2026-11-17 erc-7715-advanced-permissions MetaMask Advanced Permissions (ERC-7715) and the Smart Accounts Kit
6 items, 0 stale as of 2026-11-17
```

確かめは節の名前を出し、設計書の中身は出しません。

```text
no checked date: Accounts
missing: Approvals
wallet-design: 2 problems; fill in or add each section named above
```

### 複数のチェーンにまたがるアプリを設計する

1. エージェントがCREATE2の工場、CircleのCCTP、LayerZeroの検証者の設定、ChainlinkのCross-Chain Tokenの規格、Superchainの連携の項目を並べ、古い項目は確かめ直します
2. エージェントが決めることを1つずつ、勧める案を添えて尋ねます。どのチェーンで何を動かすか、どのコントラクトに同じアドレスが要るか、各資産をどのチェーンが発行するか、どのプロトコルがメッセージを運び誰が検証するか、片側だけ終わった時にどうするかを尋ねます。尋ねられない時は勧める案を採り、仮定として書きます
3. エージェントが`design-doc`の設計書の書式でプロジェクトに設計書を書き(既定は`docs/design/<topic>.md`)、9つの節を埋めます。節は目的とチェーン、展開とアドレス、チェーンをまたぐ資産、メッセージと検証、片側だけ終わった時、役割と上限、手数料とガス代、監視と環境、未決です
4. エージェントが節を確かめ、確かめの表で設計を見直し、判断できなかった決まりと未決の事を伝えます

項目は次のように並びます。

```text
ok     tokens       2026-11-17 chainlink-ccip-cct Chainlink CCIP Cross-Chain Token (CCT) standard and token pool rate limits
ok     bridges      2026-11-17 circle-cctp-v2 Circle CCTP V1 (Legacy) and V2
ok     deployment   2026-11-17 create2-factories CREATE2 factories for the same address on every chain (ERC-7955, Safe Singleton Factory, CreateX)
ok     messaging    2026-11-17 layerzero-dvn-config LayerZero V2 verifier (DVN) configuration
5 items, 0 stale as of 2026-11-17
```

確かめは節の名前を出し、設計書の中身は出しません。

```text
no checked date: Messages and verification
missing: Partial failures
multichain-design: 2 problems; fill in or add each section named above
```

### dAppの構成を設計する

1. エージェントがインデクサ、取引の中継、自動実行、監視、テストネット、マルチシグ、保存の項目を並べ、古い項目は確かめ直します
2. エージェントが決めることを1つずつ、勧める案を添えて尋ねます。使う人とチェーン、取引を誰が送りガス代を誰が払うか、チェーンのデータをどう読むか、何をどこに置くか、管理の役割を誰が持つか、どのサービスを自分で動かすかを尋ねます。尋ねられない時は勧める案を採り、仮定として書きます
3. エージェントが`design-doc`の設計書の書式でプロジェクトに設計書を書き(既定は`docs/design/<topic>.md`)、9つの節を埋めます。節は目的と使う人、部品、取引とガス代、チェーンの読み取り、データの置き場所、環境、鍵と管理、監視と運用、未決です
4. エージェントが節を確かめ、確かめの表で設計を見直し、判断できなかった決まりと未決の事を伝えます

項目は次のように並びます。

```text
ok     automation   2026-11-17 chainlink-automation Chainlink Automation and Chainlink CRE
ok     networks     2026-11-17 ethereum-testnets Ethereum testnets (Sepolia, Hoodi, Holesky)
ok     storage      2026-11-17 ipfs-gateways-and-pinning IPFS public gateways and pinning services
ok     transactions 2026-11-17 openzeppelin-defender-relayer OpenZeppelin Defender and OpenZeppelin Relayer
ok     indexing     2026-11-17 the-graph-network The Graph Network and Subgraph Studio
9 items, 0 stale as of 2026-11-17
```

確かめは節の名前を出し、設計書の中身は出しません。

```text
no checked date: Components
missing: Keys and admin
dapp-architecture: 2 problems; fill in or add each section named above
```

### 金融の規格で設計する

1. エージェントが規格の版の項目を並べ、古い項目は確かめ直します
2. エージェントが決めることを1つずつ、勧める案を添えて尋ねます。規格とprofile、業務の流れ、チェーン、チェーンに置く物と署名する人、法的な最終性の置き場、資産をトークンにするかを尋ねます。尋ねられない時は勧める案を採り、仮定として書きます
3. エージェントが`design-doc`の設計書の書式でプロジェクトに設計書を書き(既定は`docs/design/<topic>.md`)、9つの節を埋めます。節は規格と業務、アプリ、データと保存、オンチェーン、オフチェーン、接続、安全と運用、確かめと導入、未決です
4. エージェントが節を確かめ、確かめの表で設計を見直し、判断できなかった決まりと未決を伝えます

項目は次のように出ます。

```text
ok     cdm        7.10.0 2026-11-16 cdm-release
ok     fix        FIX Latest EP312 2026-11-16 fix-latest
ok     fpml       5.14 2026-11-16 fpml-recommendation
ok     iso-20022  CBPR+ SR2025 2026-11-16 iso-20022-cbpr-plus-release
ok     lei        ISO 17442-1:2020 2026-11-16 lei-iso-17442
ok     xbrl       XBRL 2.1, Inline XBRL 1.1, OIM 1.0 2026-11-16 xbrl-specifications
6 items, 0 stale as of 2026-11-16
```

確かめた結果は節の名前を出し、設計書の文は出しません。

```text
no checked date: Standard and business
missing: Integration
financial-standards: 2 problems; fill in or add each section named above
```

## 扱う範囲

| 扱う | 扱わない |
|---|---|
| ERC。例えばERC-20、ERC-1271、ERC-4337、ERC-6551、ERC-7683 | ネットワークの手数料や預けられた額のような今の数値。専門に追う頁があります |
| コントラクトとウォレットでできることを変えるEIP。命令、プリコンパイル、ガス代、取引の種類、EIP-7702、プロトコルの中のアカウント抽象 | バリデータやノードを動かすこと |
| L2のネットワークとロールアップの枠組みの仕組みと今の状態、EthereumのL1の今後の作り替え、コンセンサスだけを変えるEIP。例えばPeerDASとFOCIL | ERCと、コントラクトとウォレットでできることを変えるEIP。`evm-standards`が扱います |
| EIPがネットワークの更新に入るまでの段階(EIP-7723) | コントラクトの更新の方式を選ぶこと。`contract-design`が扱います |
| プロジェクトが使うsolcとOpenZeppelinとforge-stdとFoundryとHardhatの版に合わせてSolidityを書くこと | リリースの確かめ。`release-check`が扱います |
| FoundryかHardhatで、プロジェクトのコントラクトの単体とfuzzとinvariantのテストを書くこと、またはkiwaに書かせること | 変異試験、カバレッジの目標、dAppの画面のテスト。画面のテストはkiwaが扱います |
| FoundryとHardhat Ignitionの配る命令を書くこと、プロジェクトの鍵の扱いを確かめること、出した物を記録して検証すること | 署名して取引を送ること、鍵を持つこと、Safeのような複数の署名者の財布へ取引を提案すること |
| 出す前に、保存の配置とABIを配ってある版と比べること、出す先のチェーンが持たないオペコードを探すこと、ガス代と大きさを比べること | チェーンに配ってあるcodeを読みに行くこと、Hardhatのビルドと`--ast`無しのFoundryのビルドでERC-7201の名前空間の保存を比べること。その名前空間の保存はOpenZeppelinの検査か両方の版を読んで比べます |
| 書く前のコントラクトの設計。分け方、トークンの規格、不変条件、役割、更新の方式、価格、取引の順、乱数、外への呼び出しを決めます | コントラクトとそのテストと配る命令を書くこと。`solidity-code`と`contract-tests`と`contract-deploy`が扱います |
| ウォレットと署名の設計。鍵と取り戻し方、ERC-4337とEIP-7702のアカウント、署名による許可、承認、ガス代の肩代わり、AIエージェントの支払いを決めます | ウォレットのコードを書くこと、鍵を持つこと、署名すること。どの技もしません |
| 複数のチェーンにまたがるアプリの設計。同じアドレスでの展開、資産の移し方、メッセージの検証、片側だけ終わった時を決めます | ブリッジのコントラクトと配る命令を書くこと。コントラクトは`solidity-code`が、配る命令は`contract-deploy`が扱います |
| dAppの部品、取引を誰が送りガス代を誰が払うか、インデクサ、データの置き場所、環境、管理の鍵、監視の設計。名指すサービスの今の状態も確かめます | 事業者を選んで申し込むこと、鍵を作ること、コントラクトと画面と配る命令を書くこと |
| ISO 20022、FIX、FpML、CDM、LEI、XBRLを使うアプリの設計。原文と個人の情報はチェーンの外に置き、署名した証跡をチェーンに置きます | 設計のコントラクトとschemaとAPIの定義を書くこと、EVMのチェーン以外の台帳、法と規制の助言 |

## 必要な物

| 道具 | 要る時 |
|---|---|
| `bash` | いつも |
| `python3` | `solidity-code`と`contract-tests`と`contract-deploy`と`release-check`と`contract-design`と`wallet-design`と`multichain-design`と`dapp-architecture`と`financial-standards`を使う時 |
| Foundry(`forge`)かHardhat | `solidity-code`と`contract-tests`が書いた物をビルドしテストする時と、`contract-deploy`が配る物を模擬実行し、取引を調べ、検証する時と、`release-check`が2つの版をビルドする時。無い時は、ビルドしていないと伝えます |
| `git` | 無くても動きます。`contract-deploy`が、各`.env`のファイルが追跡されているか無視されているかを尋ねます。`release-check`はこれで配ってある版を取り出します。無い時は前の確かめを飛ばし、`release-check`は配ってある版の保存の配置とABIをあなたから受け取ります |
| Node.jsとプロジェクトの`@openzeppelin/upgrades-core` | 無くても動きます。両方が在る時は、`release-check`がOpenZeppelinの更新の検査も回します |
| kiwaのプラグイン | 無くても動きます。スキルが入っている時は、`contract-tests`がkiwaにテストを書かせます |
| エージェントのWebへの接続 | 古い項目を確かめ直す時。無い時は、項目から答えて確かめられなかったと伝えます |
| LedgerかTrezorのハードウェアウォレット | `contract-deploy`で本番のチェーンへ配る時の署名に使います。テストのチェーンには暗号化したキーストアを使います |
| 記事の一覧の置き場への接続 | `~/.evm-dev/article-index`か`EVM_DEV_INDEX_URL`がURLを名指す時だけ要ります。無い時は、`evm-standards`は項目だけから探し、記事の一覧を読めなかったと伝えます |
| `musubi`のコマンド | 無くても動きます。入っている時は、設計のスキルが`design-doc`の書式を読む前と、`release-check`が`page-design`の書式を読む前に、エージェントが`musubi check`を回します |

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、項目と状態と、探し方と、項目を古いと見る時期を書いています。
要点は次のとおりです。

- プラグインに同梱した項目を読みます
- `evm-standards`は`evm-standards.sh list`を動かし、項目を読んで1件1行で出します
- `ethereum-knowledge`は`ethereum-knowledge.sh list`を動かし、自分の項目を読んで1件1行で出します
- `evm-standards`は`find`と`article`で`standards.py`を動かし、項目と、`~/.evm-dev/article-index`か`EVM_DEV_INDEX_URL`で名指した記事の一覧を読みます。URLで名指した一覧はそのアドレスへの素の要求で取るため、質問の語は送りません。取った一覧は`~/.local/share/evm-dev/`(`EVM_DEV_HOME`で替えられます)に、あなただけが読める形でURLごとに1日の間残します。pathで名指した一覧はその場で読みます。出すのは記事の題と説明とhttpsのリンクだけで、URLの一覧からはそのURLと同じhostのリンクだけを出します
- `solidity-code`は`solidity-code.py`を動かし、プロジェクトの設定のファイルとライブラリの`package.json`から版を読み、探す時はプロジェクトのソースのファイルを読みます。`.env`のファイルと依存とビルドの出力は読まず、行の中身を出しません
- `solidity-code`は頼まれたコントラクトだけを書き、プロジェクトのビルドとテストを動かします
- `contract-tests`は`contract-tests.py`を動かし、プロジェクトの設定のファイルとコントラクトとテストを読みます。出すのは種類と名前と`file:line`だけで、コントラクトとテストの中身は出しません。書くのはテストのファイルだけで、コントラクトは変えず、`.env`のファイルと依存とビルドの出力は読みません
- `contract-deploy`は`contract-deploy.py`を動かし、鍵の危ない扱いを探すためにプロジェクトの配る命令と設定を読み、各`.env`のファイルを開かずに追跡されているか無視されているかを`git`に尋ね、記録を作るために`broadcast/`と`ignition/deployments/`を読みます。出すのは種類と`file:line`だけで、鍵も行の中身も出さず、書くのは`deployments/<chain id>.json`だけです。`.env`のファイルとFoundryの`cache/`は読まず、署名せず、鍵を渡す命令を断ります
- `contract-deploy`は配る命令を書いて模擬実行し、プロジェクトのRPCの接続先を通して取引とcodeを調べます。取引を送る命令はあなたが打ちます。検証はコントラクトのソースをSourcifyかEtherscanかBlockscoutに送って公開するため、エージェントは動かす前に尋ねます
- `release-check`は`release-check.py`を動かし、ビルドの出力と渡されたJSONのファイルの中の保存の配置とABIとbytecodeだけを読み、見つけた物を1件1行で出します。何も書かず、`.env`のファイルと鍵は読みません
- `release-check`は配ってある版を一時的なgitのworktreeに取り出し、プロジェクトの道具で2つの版をビルドしてテストを回し、終わったらworktreeを消します。プロジェクトにOpenZeppelinの検査が在る時、その検査は名前空間の保存を確かめるために、合うsolcをSolidityの配布元から取ってくることがあります
- `skills/release-check/musubi.json`は、`release-check`が報告の順の書式`page-design/structure`に、`"optional": true`の任意の準拠で従うことをmusubiで宣言します。エージェントは`page-design`が入っている時だけ書式を読み、入っていなければ自分の順で報告します。`release-check`はほかのプラグインからこれ以外を読みません
- `contract-design`は`contract-design.py`を動かし、項目と、書いた設計書を読みます。設計書を確かめる時は節の名前だけを出します。書くのは設計書だけで、`.env`のファイルと鍵は読みません
- `wallet-design`は`wallet-design.py`を動かし、項目と、書いた設計書を読みます。設計書を確かめる時は節の名前だけを出します。書くのは設計書だけで、`.env`のファイルと鍵は読まず、署名せず、鍵を渡す命令を断ります
- `multichain-design`は`multichain-design.py`を動かし、項目と、書いた設計書を読みます。設計書を確かめる時は節の名前だけを出します。書くのは設計書だけで、`.env`のファイルと鍵は読まず、署名せず、鍵を渡す命令を断ります
- `dapp-architecture`は`dapp-architecture.py`を動かし、項目と、書いた設計書を読みます。設計書を確かめる時は節の名前だけを出します。書くのは設計書だけで、`.env`のファイルと鍵は読みません
- `financial-standards`は`financial-standards.py`を動かし、項目と、書いた設計書を読みます。設計書を確かめる時は節の名前だけを出します。書くのは設計書だけで、`.env`のファイルと鍵は読みません
- 古い項目を確かめ直す時は、規格の番号か名前、ネットワークか枠組みの名前、または道具かサービスの名前と版だけでWebを検索し、公式の文書を開きます
- 項目を書き換えず、URLで名指した記事の一覧の写しのほかは何も残しません

## ライセンス

[MIT](LICENSE)
