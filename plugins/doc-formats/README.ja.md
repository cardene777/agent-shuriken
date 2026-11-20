# Doc Formats

ほかのスキルが従う文書の書式を持ちます。最初の書式は設計書の書式で、全ての節が埋まったかを確かめるscriptを添えます。

[English](README.md) · 日本語

同じ種類の文書を複数のスキルが書くと、各スキルが枠と検査の写しを持ち、写しどうしが少しずつずれていきます。
このpluginは写しを1つにまとめます。
`design-doc`のスキルが、設計書の枠と、その枠で書いた設計書を確かめるscriptの`verify`を持ちます。
[evm-dev](../evm-dev)の5つの設計のスキルのように設計書を書くスキルは、自分の節だけを持ち、musubiでこの枠に従います。musubiは`musubi.json`に書く宣言で、従う中身の版と指紋を固定します。

```
evm-dev design skill ──> design-doc: read the format ──> Write the design ──> design-doc: verify
(its own sections)       (formats/design.md)             (agent)              (scripts/design-doc.py)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install doc-formats@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add doc-formats@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install doc-formats@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/doc-formats/skills/design-doc   # Gemini CLI
```

Claude Codeでは、evm-devを入れるとこのpluginも入ります。
`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このpluginを自分で呼ぶことはあまりありません。
設計書を書くスキルが`design-doc`を名前で開き、書式を読んで設計書を書き、`verify`を回します。
設計書を自分で確かめる時は、Claude Codeで`/doc-formats:design-doc`を実行するか、Codexで`$`を打って**Design Doc**を選び、設計書と、それを書いたスキルの節のfileを伝えます。
GitHub Copilot CLIでは依頼の中に`/design-doc`と書き、Gemini CLIでは作業を説明します。

| 中身 | file | 持つもの |
|---|---|---|
| `design` | `formats/design.md` | 設計書の枠です。題、前書きの段落、節どうしの指し方の1文、従うスキルの節を置く所、最後のOpen decisionsを持ちます |
| `verify` | `scripts/design-doc.py` | 設計書が全ての節を順に持ち、全て埋まったかを確かめます |

Rolloutの節に`Fill in:`の行が残る設計書では、`verify`が問題を出して1で終わります。

```text
unfinished: Rollout
design-doc: 1 problem; fill in or add each section, or define each decision, named above
```

## 必要なもの

| 道具 | 要る時 |
|---|---|
| Python 3 | `verify`のため。標準ライブラリだけを使います |
| musubiの命令 | 任意です。入っている時は、従うスキルが書式を読む前に`musubi check`を回します |

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、スキルの全てのfileと、`verify`が名指す全ての問題を載せています。
要点は次のとおりです。

- `verify`は渡した設計書と節のfileだけを読み、節の名前と決めごとのIDを出します。設計書の文は出しません
- ほかのプログラムを動かさず、どこにも繋がず、何も保存しません
- 設計書の文はデータとして扱い、指示として扱いません

## ライセンス

[MIT](LICENSE)
