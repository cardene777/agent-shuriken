# EVM Dev

ERCが確定したか、EIPがEthereumのメインネットで動いているか、コントラクトとウォレットで何ができるようになるかを、エージェントの記憶ではなく、公式の文書で確かめた項目から答えます。

[English](README.md) · 日本語

エージェントの知識は学習の時点で止まりますが、規格はその後も動きます。
EIPがネットワークの更新で入り、提案が更新から外れ、広く呼ばれている「ERC」が実はどこにも取り込まれていなかった、ということが起きます。
このプラグインは、ERCと、コントラクトとウォレットとdAppでできることを変えるEIPについて、41の項目を持ちます。
各項目は、公式の文書で確かめた日と、もとにした文書の名前を持ちます。
エージェントは項目から答え、状態ごとの日数より古い項目は、公式の文書で確かめ直してから答えます。

```
List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
 (script)           (agent)                       (agent, when needed)     (agent)
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
```

`SKILL.md`を読むほかのエージェントでは、各リリースに付いているスキルのzipをエージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

規格の状態を尋ねると始まります。
例えば「EIP-7702はメインネットで動いている?」や「ERC-7281を確定した規格として書いてよい?」と尋ねます。
呼び出すこともできます。
Claude Codeでは`/evm-dev:evm-standards`を実行し、Codexでは`$`を入力して**EVM Standards**を選びます。
GitHub Copilot CLIでは依頼の文に`/evm-standards`と書き、Gemini CLIでは作業を説明します。

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

## 扱う範囲

| 扱う | 扱わない |
|---|---|
| ERC。例えばERC-20、ERC-1271、ERC-4337、ERC-6551、ERC-7683 | L2のネットワークの状態。専門に追う頁があります |
| コントラクトとウォレットでできることを変えるEIP。命令、プリコンパイル、ガス代、取引の種類、EIP-7702、プロトコルの中のアカウント抽象 | コンセンサスだけを変えるEIP。例えばバリデータの決まり |
| EIPがネットワークの更新に入るまでの段階(EIP-7723) | コントラクトを書くことと、dAppを設計すること |

## 必要な物

| 道具 | 要る時 |
|---|---|
| `bash` | いつも |
| エージェントのWebへの接続 | 古い項目を確かめ直す時。無い時は、項目から答えて確かめられなかったと伝えます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、項目と状態と、項目を古いと見る時期を書いています。
要点は次のとおりです。

- プラグインに同梱した項目を読みます
- `evm-standards.sh list`を動かし、項目を読んで1件1行で出します
- 古い項目を確かめ直す時は、規格の番号か名前だけでWebを検索し、公式の文書を開きます
- 項目を書き換えず、何も残しません

## ライセンス

[MIT](LICENSE)
