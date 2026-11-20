# Diagram Composer

スライドの図の部分を、関係がひと目で読める形に設計します。図の見立てを1つに決め、線ごとに意味を持たせ、ラベルを線から離します。スライドを描く前に、scriptが配置を確かめます。

[English](README.md) · 日本語

AIがスライドに描く図は、出来上がって見えても読み違える形になることがよくあります。
ラベルが自分の名指す矢印の上に載り、高さの違う2本の線に意味が無く、箱がそれを囲むカードからはみ出し、新しいテーマでも前の形の色を替えただけになります。
このpluginでは、agentが描く前に図で何を示すかを決め、図の箱と線とラベルを小さな配置の記述 (geometry manifest) に書き、その記述をscriptで確かめます。
確かめた後に、agentがあなたのデックでスライド全体を描いて目で見ます。

```
見立て ──> 箱と線 ──> 配置の記述 ──> 確かめ ──> スライドを描く ──> 見て直す
(agent)    (agent)    (agent)        (script)   (デックの道具)    (agent)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install diagram-composer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add diagram-composer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install diagram-composer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/diagram-composer/skills/diagram-composer   # Gemini CLI
```

`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

スライドの図を頼むと始まります。例えば「4枚目にログインの流れの図を足して」「この図のラベルが矢印に重なっているので直して」「新しいテーマでこの図の方向を3つ見せて」と頼みます。
呼び出すこともできます。Claude Codeでは`/diagram-composer:diagram-composer`を実行し、Codexでは`$`を入力して**Diagram Composer**を選びます。
GitHub Copilot CLIでは依頼の中に`/diagram-composer`と書き、Gemini CLIでは作業を言葉で頼みます。

1. agentが図の見立てを1つと、読ませる関係を決めます。関係は境界、受け渡し、比較、階層、原因、循環、変化のどれかです
2. 箱の中の絵は、それで箱が何かを早く見分けられる時だけ置きます。線ごとに意味を1つ持たせ、横に流れる1本の流れは1つの中心線に揃えます
3. 囲みと要素と線とラベルを配置の記述に書き、関係のラベルはラベル専用の場所に置きます
4. `validate_diagram_geometry.py`が記述を確かめ、agentは名指された問題を全部直します
5. agentがあなたのデックでスライド全体を最終の大きさで描き、目で見た重なりを直します

| 頼むこと | agentがすること |
|---|---|
| 方向を決める前にテーマを比べる | テーマごとに、図の役割が違うスライドを3枚以上全体の大きさで描きます。あなたが1つを選ぶまで、どれもデックに足しません |
| 既に在る型を見る | デックが既に持つ図を、手を加えずに描きます。生成した絵や新しい描き方は足しません |
| 名指したデックに合わせる | そのデックを基準にし、箱の中の絵まで揃えます |

ラベルを自分の矢印の上に置いた時、確かめは問題を出して終わり方1で終わります。

```text
Diagram geometry rejected:
- slide 1: label request-label collides with connector request
```

## 必要なもの

| 道具 | 要る時 |
|---|---|
| Python 3 | `validate_diagram_geometry.py`のため。標準ライブラリだけを使います |
| デックの道具 | スライドを描くため。このpluginは描く道具を同梱しません |

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、技の全てのfileと、確かめが当てる全ての決まりを載せています。
要点は次のとおりです。

- agentは、あなたのデックと、あなたが指したスライドを読みます
- `validate_diagram_geometry.py`は、渡した配置の記述だけを読み、見つけた問題を出します
- どこにも何も送らず、pluginは何も保存しません。配置の記述は、あなたかagentが保存した場所に置かれます
- スライドとfileとページは描く材料として扱い、指示として扱いません

## ライセンス

[MIT](LICENSE)
