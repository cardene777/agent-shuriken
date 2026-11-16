# EVM Dev

ERCが確定したか、EIPがEthereumのメインネットで動いているかを答え、プロジェクトが使う版に合わせてSolidityを書きます。どちらも、エージェントの記憶ではなく、公式の文書で確かめた項目に基づきます。

[English](README.md) · 日本語

エージェントの知識は学習の時点で止まりますが、規格と道具はその後も動きます。
EIPがネットワークの更新で入り、広く呼ばれている「ERC」が実はどこにも取り込まれておらず、ライブラリが読み込むファイルの名前を変え、フレームワークがスクリプトの呼ぶ関数を非推奨にします。
このプラグインは、その両方について、公式の文書で確かめた日と、もとにした文書の名前を持つ項目を持ちます。

| スキル | すること |
|---|---|
| `evm-standards` | ERCが確定したか、EIPが動いているか、コントラクトとウォレットで何ができるようになるかを、ERCとEIPの41の項目から答えます |
| `solidity-code` | FoundryとHardhatのプロジェクトで、プロジェクトが使うsolcとOpenZeppelinとforge-stdとFoundryとHardhatの版に合わせてコントラクトを書き、古い書き方を探してからビルドとテストを回します |

```
evm-standards:  List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
solidity-code:  Read the project's versions ──> Read the items for them ──> Write ──> Scan, build, and test
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
```

`SKILL.md`を読むほかのエージェントでは、各リリースに付いているスキルのzipをエージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

`evm-standards`は、規格の状態を尋ねると始まります。
例えば「EIP-7702はメインネットで動いている?」や「ERC-7281を確定した規格として書いてよい?」と尋ねます。
`solidity-code`は、コントラクトを書くか変えるよう頼むと始まります。
例えば「このFoundryのプロジェクトに、止められるERC-20のトークンを足して」と頼みます。
呼び出すこともできます。
Claude Codeでは`/evm-dev:evm-standards`か`/evm-dev:solidity-code`を実行し、Codexでは`$`を入力して**EVM Standards**か**Solidity Code**を選びます。
GitHub Copilot CLIでは依頼の文に`/evm-standards`か`/solidity-code`と書き、Gemini CLIでは作業を説明します。

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

## 扱う範囲

| 扱う | 扱わない |
|---|---|
| ERC。例えばERC-20、ERC-1271、ERC-4337、ERC-6551、ERC-7683 | L2のネットワークの状態。専門に追う頁があります |
| コントラクトとウォレットでできることを変えるEIP。命令、プリコンパイル、ガス代、取引の種類、EIP-7702、プロトコルの中のアカウント抽象 | コンセンサスだけを変えるEIP。例えばバリデータの決まり |
| EIPがネットワークの更新に入るまでの段階(EIP-7723) | コントラクトの更新の方式を選ぶこと。後のコントラクトの設計のスキルが扱います |
| プロジェクトが使うsolcとOpenZeppelinとforge-stdとFoundryとHardhatの版に合わせてSolidityを書くこと | テストを書くこと、デプロイ、出す前の保存の配置とABIの比べ |

## 必要な物

| 道具 | 要る時 |
|---|---|
| `bash` | いつも |
| `python3` | `solidity-code`を使う時 |
| Foundry(`forge`)かHardhat | `solidity-code`が書いた物をビルドしテストする時。無い時は、ビルドしていないと伝えます |
| エージェントのWebへの接続 | 古い項目を確かめ直す時。無い時は、項目から答えて確かめられなかったと伝えます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、項目と状態と、探し方と、項目を古いと見る時期を書いています。
要点は次のとおりです。

- プラグインに同梱した項目を読みます
- `evm-standards`は`evm-standards.sh list`を動かし、項目を読んで1件1行で出します
- `solidity-code`は`solidity-code.py`を動かし、プロジェクトの設定のファイルとライブラリの`package.json`から版を読み、探す時はプロジェクトのソースのファイルを読みます。`.env`のファイルと依存とビルドの出力は読まず、行の中身を出しません
- `solidity-code`は頼まれたコントラクトだけを書き、プロジェクトのビルドとテストを動かします
- 古い項目を確かめ直す時は、規格の番号か名前、または道具の名前と版だけでWebを検索し、公式の文書を開きます
- 項目を書き換えず、何も残しません

## ライセンス

[MIT](LICENSE)
