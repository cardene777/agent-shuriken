# EVM Dev

ERCが確定したか、EIPがEthereumのメインネットで動いているかを答え、プロジェクトが使う版に合わせてSolidityとそのテストを書き、ISO 20022やFIXなどの金融の規格を使うアプリを設計します。どれも、エージェントの記憶ではなく、公式の文書で確かめた項目に基づきます。

[English](README.md) · 日本語

エージェントの知識は学習の時点で止まりますが、規格と道具はその後も動きます。
EIPがネットワークの更新で入り、広く呼ばれている「ERC」が実はどこにも取り込まれておらず、ライブラリが読み込むファイルの名前を変え、フレームワークがスクリプトの呼ぶ関数を非推奨にし、決済の規格の改版が延期されます。
このプラグインは、その3つについて、公式の文書で確かめた日と、もとにした文書の名前を持つ項目を持ちます。

| スキル | すること |
|---|---|
| `evm-standards` | ERCが確定したか、EIPが動いているか、コントラクトとウォレットで何ができるようになるかを、ERCとEIPの41の項目から答えます |
| `solidity-code` | FoundryとHardhatのプロジェクトで、プロジェクトが使うsolcとOpenZeppelinとforge-stdとFoundryとHardhatの版に合わせてコントラクトを書き、古い書き方を探してからビルドとテストを回します |
| `contract-tests` | FoundryかHardhatのプロジェクトで、コントラクトごとに確かめる点を挙げてから、単体とfuzzとinvariantのテストを書きます。kiwaが入っていればkiwaに書かせます。どのテストも触れていない点を名指し、テストを回します |
| `financial-standards` | ISO 20022、FIX、FpML、CDM、LEI、XBRLを使い、オンチェーンとオフチェーンの部分を持つアプリを設計します。決めることを1つずつ尋ね、雛形から1つの設計書を書き、節を確かめてから確かめの表で見直します |

```
evm-standards:  List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
solidity-code:  Read the project's versions ──> Read the items for them ──> Write ──> Scan, build, and test
contract-tests:  Read the versions and items ──> List what needs a test ──> Write the tests, or have kiwa write them ──> Name what no test covers ──> Run the tests
financial-standards:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install evm-dev@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add evm-dev@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install evm-dev@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/evm-standards   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/solidity-code
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/contract-tests
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/financial-standards
```

`SKILL.md`を読むほかのエージェントでは、各リリースに付いているスキルのzipをエージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

`evm-standards`は、規格の状態を尋ねると始まります。
例えば「EIP-7702はメインネットで動いている?」や「ERC-7281を確定した規格として書いてよい?」と尋ねます。
`solidity-code`は、コントラクトを書くか変えるよう頼むと始まります。
例えば「このFoundryのプロジェクトに、止められるERC-20のトークンを足して」と頼みます。
`contract-tests`は、コントラクトのテストを頼むと始まります。
例えば「src/Vault.solのテストを足して」と頼みます。
`financial-standards`は、金融の規格を使う設計を頼むと始まります。
例えば「ISO 20022の支払いのmessageを決済のコントラクトにどう対応させるかを設計して」と頼みます。
呼び出すこともできます。
Claude Codeでは`/evm-dev:evm-standards`か`/evm-dev:solidity-code`か`/evm-dev:contract-tests`か`/evm-dev:financial-standards`を実行し、Codexでは`$`を入力して**EVM Standards**か**Solidity Code**か**Contract Tests**か**Financial Standards**を選びます。
GitHub Copilot CLIでは依頼の文に`/evm-standards`か`/solidity-code`か`/contract-tests`か`/financial-standards`と書き、Gemini CLIでは作業を説明します。

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

### 金融の規格で設計する

1. エージェントが規格の版の項目を並べ、古い項目は確かめ直します
2. エージェントが決めることを1つずつ、勧める案を添えて尋ねます。規格とprofile、業務の流れ、チェーン、チェーンに置く物と署名する人、法的な最終性の置き場、資産をトークンにするかを尋ねます。尋ねられない時は勧める案を採り、仮定として書きます
3. エージェントが雛形をプロジェクトに写し(既定は`docs/design/<topic>.md`)、9つの節を埋めます。節は規格と業務、アプリ、データと保存、オンチェーン、オフチェーン、接続、安全と運用、確かめと導入、未決です
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
| ERC。例えばERC-20、ERC-1271、ERC-4337、ERC-6551、ERC-7683 | L2のネットワークの状態。専門に追う頁があります |
| コントラクトとウォレットでできることを変えるEIP。命令、プリコンパイル、ガス代、取引の種類、EIP-7702、プロトコルの中のアカウント抽象 | コンセンサスだけを変えるEIP。例えばバリデータの決まり |
| EIPがネットワークの更新に入るまでの段階(EIP-7723) | コントラクトの更新の方式を選ぶこと。後のコントラクトの設計のスキルが扱います |
| プロジェクトが使うsolcとOpenZeppelinとforge-stdとFoundryとHardhatの版に合わせてSolidityを書くこと | デプロイ、出す前の保存の配置とABIの比べ |
| FoundryかHardhatで、プロジェクトのコントラクトの単体とfuzzとinvariantのテストを書くこと、またはkiwaに書かせること | 変異試験、カバレッジの目標、dAppの画面のテスト。画面のテストはkiwaが扱います |
| ISO 20022、FIX、FpML、CDM、LEI、XBRLを使うアプリの設計。原文と個人の情報はチェーンの外に置き、署名した証跡をチェーンに置きます | 設計のコントラクトとschemaとAPIの定義を書くこと、EVMのチェーン以外の台帳、法と規制の助言 |

## 必要な物

| 道具 | 要る時 |
|---|---|
| `bash` | いつも |
| `python3` | `solidity-code`と`contract-tests`と`financial-standards`を使う時 |
| Foundry(`forge`)かHardhat | `solidity-code`と`contract-tests`が書いた物をビルドしテストする時。無い時は、ビルドしていないと伝えます |
| kiwaのプラグイン | 無くても動きます。スキルが入っている時は、`contract-tests`がkiwaにテストを書かせます |
| エージェントのWebへの接続 | 古い項目を確かめ直す時。無い時は、項目から答えて確かめられなかったと伝えます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、項目と状態と、探し方と、項目を古いと見る時期を書いています。
要点は次のとおりです。

- プラグインに同梱した項目を読みます
- `evm-standards`は`evm-standards.sh list`を動かし、項目を読んで1件1行で出します
- `solidity-code`は`solidity-code.py`を動かし、プロジェクトの設定のファイルとライブラリの`package.json`から版を読み、探す時はプロジェクトのソースのファイルを読みます。`.env`のファイルと依存とビルドの出力は読まず、行の中身を出しません
- `solidity-code`は頼まれたコントラクトだけを書き、プロジェクトのビルドとテストを動かします
- `contract-tests`は`contract-tests.py`を動かし、プロジェクトの設定のファイルとコントラクトとテストを読みます。出すのは種類と名前と`file:line`だけで、コントラクトとテストの中身は出しません。書くのはテストのファイルだけで、コントラクトは変えず、`.env`のファイルと依存とビルドの出力は読みません
- `financial-standards`は`financial-standards.py`を動かし、項目と、書いた設計書を読みます。設計書を確かめる時は節の名前だけを出します。書くのは設計書だけで、`.env`のファイルと鍵は読みません
- 古い項目を確かめ直す時は、規格の番号か名前、または道具の名前と版だけでWebを検索し、公式の文書を開きます
- 項目を書き換えず、何も残しません

## ライセンス

[MIT](LICENSE)
