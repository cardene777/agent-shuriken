# Motion Explainer

仕組みを、1つの具体例を流す短い動画で見せ、細かい点は同じ絵で描いた補足の図で答えます。

[English](README.md) · 日本語

仕組みを文で説明すると、読み手が出来事の順を自分で組み立てることになります。
図は部品を見せますが、1つの例が部品を通る間に何が起きるかは見せません。
このプラグインは、1つのリクエストや1つの荷物のような具体例を、始めから終わりまで短い動画で流します。
場面ごとに1つだけが変わり、語り手がその変化を1文で話し、変わった部品だけに印が付きます。
題材ごとにエージェントがアートディレクションを書き、語り手と舞台の物をSVGで描くので、2つの題材が同じ見た目になりません。
動画の下の補足の図は、同じ絵で1つずつ問いに答えます。

```
具体例を決める ──> アートディレクション ──> 絵を描く ──> 仕様を書く ──> 確かめる ──> ページ
 (エージェント)     (あなたとエージェント)     (エージェント)  (エージェント)  (エージェント)  (あなた)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install motion-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add motion-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install motion-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/motion-explainer/skills/motion-explainer   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)のとおりエージェントのスキルのフォルダに展開します。

## 使い方

仕組みを短い動画で説明してと頼むと始まります。
たとえば「キャッシュがリクエストに答える流れを短い動画で説明して」や「荷物が再配達される流れを説明動画にして」です。
Claude Codeでは`/motion-explainer:motion-explainer`を実行し、Codexでは`$`を入力して**Motion Explainer**を選んでも呼べます。
GitHub Copilot CLIでは依頼文に`/motion-explainer`と書き、Gemini CLIでは作業を説明します。

1. エージェントが示された資料を読み、仕組み全体を通る具体例を1つ選び、1つずつ変化する場面に分けます
2. エージェントが場面とアートディレクションを見せ、あなたが同意するまで直します
3. エージェントが語り手と各部品を、その方向に沿ってSVGで描きます。1つの絵のファイルに全ての状態を描きます
4. エージェントが補足の図を含む仕様を書き、確かめてページを作り、デスクトップの幅と電話の幅で見てからあなたに渡します

仕様の場面は次の形です。

```json
{ "id": "travel", "chapter": "Travel", "line": "So the request travels on to the origin server.",
  "narrator": "calm", "set": { "cache": "empty", "origin": "busy" }, "move": { "letter": [78, 0] } }
```

部品は前の場面の状態と場所を保つので、場面には変わる物だけを書きます。
`check`は、無い部品や状態を名指す場面、何も変えない場面、上限を超える文、外から読み込むかスクリプトを動かす絵を断り、そのたびに欄の名前を示します。
[仕様の形](skills/motion-explainer/references/spec-format.md)が全ての欄を挙げ、[`examples/`](examples/)に英語と日本語の仕様が1つずつ、それぞれの絵と一緒にあります。

## ページ

| 部分 | すること |
|---|---|
| プレーヤー | 場面を1回流し、再生と停止と最初からのボタンを持ちます。語り手は場面が名指す状態になり、その場面の1文を話します |
| 章 | 場面ごとに1つのボタンです。押すとその場面を終わりの状態で開き、止まります |
| 印 | 場面で変わった部品だけを、変わった時に囲んで名前を出します |
| 補足の図 | プレーヤーの下に置きます。場面の終わりの舞台、状態の順、2つの場合の比べ、表のどれかで1つの問いに答えます |

ページはネットワークから何も読み込まないので、ネットにつながずに開け、1つのファイルとして渡せます。
動きを減らす設定にした読み手には、各場面を終わりの状態で動かさずに見せます。
電話の幅でも横にスクロールせずに使え、明るい表示と暗い表示で読めます。
色とフォントは共通のテーマのキーの名前を持つので、`page-design`を入れているとエージェントがあなたの見た目を当てられます。舞台はアートディレクションの色を保ちます。
`skills/motion-explainer/musubi.json`は、見た目を当てる`page-design`のスクリプト`page-design/verify`に従うことを任意のmusubiの従い先として宣言します。そのスクリプトが最後の確認の後に変わると、`musubi check`がスキルを断ります。

## 必要な物

| ツール | 要る時 |
|---|---|
| Python 3 | 常に。`check`と`render`は標準ライブラリだけを使います |

何もインストールしません。

## 読む物と動かす物と送る物

- 示された資料と、仕様と、仕様が名指す絵だけを読みます。資料は説明する対象として扱い、指示としては扱いません
- 仕様と絵とページは、あなたが指定した場所か、資料の隣にだけ書きます
- ページはネットワークから何も読み込まず、選んだテーマだけをブラウザに保ちます
- どこにも何も送りません

## ライセンス

[MIT](LICENSE)
