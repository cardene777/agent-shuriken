# Explaining

プロトコル、システム、処理がどう動くかを、1つの例を最後まで通して説明し、その分野を知らない読み手が初めから終わりまで追えるようにします。

[English](README.md) · 日本語

仕組みを説明してと頼むと、エージェントは部品を1つずつ並べ、節ごとに例を替え、動かない図を描きがちです。
このプラグインは、説明の組み立て方を1つ渡します。
1つの具体例を全ての節で使い、先に番号の付いた段の地図を出して、後の節で1段ずつ掘ります。
似た物は表で分け、取り違えやすい所はその場で否定の文で正し、条件の組ごとの結果を全て表にし、最後に役の表と持ち帰る1文で締めます。
順番、状態の変化、条件で結果が変わる所には、段を送る図、入力を取る図、状態の前と後の図を求めます。

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install explaining@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add explaining@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install explaining@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/explaining/skills/explaining   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに付けたスキルのzipをエージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

仕組みがどう動くかを文章で説明してと頼むと始まります。
たとえば「3台のサーバーにまたがる支払いがどう確定するかを説明して」「デプロイの流れを説明にまとめて」です。
呼び出すこともできます。
Claude Codeでは`/explaining:explaining`を実行し、Codexでは`$`を入力して**Explaining**を選びます。
GitHub Copilot CLIでは依頼の中に`/explaining`と書き、Gemini CLIでは作業を説明します。

| 説明の部分 | 中身 |
|---|---|
| 1つの例を通す | 名前と値の入った1つの事例。全ての節と図で使う |
| 段の地図 | 段の番号付きの一覧。段を送る図にして、後の節で1段ずつ掘る前に出す |
| 似た物を対で分ける | 似た2つに同じ問いを並べて比べる表 |
| 取り違えを正す | 役を読み過ぎやすい所に置く否定の文 |
| 条件の組を尽くす | 全ての組と結果の表。組が多い時は入力を取る図も置く |
| 締めの表と1文 | 例の中で各部品がしたことと、覚えておく1つのこと |

説明は、頼んだ形と言葉で書きます。
既定はMarkdownです。
`skills/explaining/examples/confirmation-protocol.md`が、この組み立て方で書いた説明の例です。

## ほかのスキルから使う

このスキルは、組み立て方を中身`structure`として[musubi](https://github.com/cardene777/musubi)で出します。
説明を書くスキルは、自分の`musubi.json`で`explaining/structure`に従い、説明を組む前に`references/structure.md`を読みます。
頁と図の形は自分の物を使います。

## 読む物と動かす物と送る物

このプラグインは指示のfileだけで、何も動かしません。
会話と、指したfileだけを読み、何も保存せず、どこにも送りません。

## ライセンス

[MIT](LICENSE)
