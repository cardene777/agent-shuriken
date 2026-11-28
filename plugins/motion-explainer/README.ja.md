# Motion Explainer

仕組みを、1つの具体例を流す短い動画で見せ、細かい点は同じ物で描いた補足の図で答えます。

[English](README.md) · 日本語

仕組みを文で説明すると、読み手が出来事の順を自分で組み立てることになります。
図は部品を見せますが、1つの例が部品を通る間に何が起きるかは見せません。
このプラグインは、1つのリクエストや1つの荷物のような具体例を、始めから終わりまで短い動画で流します。
場面ごとに1つだけが変わり、登場人物がその変化を吹き出しで1文話し、変化の所に効果が出ます。
動画は、見た目を決めるテーマと、何が起きるかを書く台本の2つのファイルから組み立てます。
プラグインはドット絵のテーマを持ち、4体 (ロボ、アンドロイド、案内人、ドローン) がそれぞれ待つ、説明する、驚く、喜ぶの4つの表情を持ちます。
ほかのプラグインは、自分のテーマのフォルダーを渡せます。
題材ごとにエージェントが画面に出す物を独自のアートディレクションでSVGに描くので、2つの題材が同じ見た目になりません。
動画の下の補足の図は、同じ物で1つずつ問いに答えます。

```
構成を立てる ──> 台本を書く ──> 組み立てる ──> 撮って確かめる ──> 文言を確かめる ──> ページ
 (あなたとエージェント)  (エージェント)  (エージェント)  (エージェント)      (エージェント)      (あなた)
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

1. エージェントが示された資料を読み、仕組み全体を通る具体例を1つ選び、1つずつ変化する場面を工程にまとめ、あなたが同意するまで構成を直します
2. エージェントが画面に出す物を状態ごとに1つのSVGに描き、登場人物と場面と補足の図を台本に書きます
3. エージェントがページを組み立て、各場面の途中と終わりを撮り、ほかの物を覆う所と小さすぎて読めない所を直します
4. エージェントが全ての台詞と名前を確かめ、デスクトップの幅と電話の幅でページを見てからあなたに渡します

台本の場面は次の形です。

```json
{ "chapter": "Travel", "cast": ["bit"], "layout": [["browser"], ["cache"], ["origin"]],
  "beats": [
    { "do": "fly", "image": "letter-request", "width": 64, "from": "cache", "to": "origin" },
    { "do": "swap", "target": "origin", "state": "busy", "fx": { "word": "gogo", "dy": -110 } },
    { "do": "say", "who": "bit", "text": "So the request goes on to the origin server.", "face": "explain" }
  ] }
```

場面には、出る登場人物と、画面に出す物の列を書きます。
`beats`には起きることを順に書き、吹き出しの台詞、別の状態に変わる物、ある物から別の物へ飛ぶ絵、変化の所に出る効果を並べます。
エンジンは登場人物を両端に、画面に出す物をその間に収まる大きさで置くので、何も重なりません。
画面に出す物には、状態を持つ1枚の絵、線でつながる行の並び、レールに掛かる物やトレーに立つ物、1か所へ寄せる実際のページ、ボタンとチェックと枠と数で作る小さな画面があります。
`build.py`は、無い欄、無い登場人物や表情や物や状態、外から読み込むかスクリプトを動かす絵を断り、そのたびに欄の名前を示します。
[台本の形](skills/motion-explainer/references/script.md)と[テーマの形](skills/motion-explainer/references/theme.md)が全ての欄を挙げ、[`examples/`](examples/)に登場人物1人の英語の台本と、2人の日本語の台本が、それぞれの絵と一緒にあります。

## ページ

| 部分 | すること |
|---|---|
| 動画 | 場面を1回流します。台詞ごとに話し手がその表情になり、吹き出しで1文を話します。電話の幅では動画の下にも台詞を出します |
| 下のバー | 工程ごとに1つの区切りを持ち、流れるにつれて埋まります。区切りを押すと、その工程を頭から流します |
| 再生のボタン | 止めて、同じ所から流し直します |
| 効果 | `beats`が名指す衝撃、きらめき、煙、音の文字を、その`beats`を流す時だけ出します |
| 補足の図 | 動画の下に置きます。番号付きの名前を添えた1つの場面、状態の順、2つの場合の比べ、表のどれかで1つの問いに答えます |

ページはネットワークから何も読み込まないので、ネットにつながずに開け、1つのファイルとして渡せます。
動きを減らす設定にした読み手には、各場面を終わりの状態で、動きと効果なしで見せます。登場人物の表情は変わります。
電話の幅でも横にスクロールせずに使え、明るい表示と暗い表示で読めます。
色とフォントは共通のテーマのキーの名前を持つので、`page-design`を入れているとエージェントがあなたの見た目を動画の周りのページに当てられます。動画はそのテーマの色を保ちます。
`skills/motion-explainer/musubi.json`は、見た目を当てる`page-design`のスクリプト`page-design/verify`に従うことを任意のmusubiの従い先として宣言します。そのスクリプトが最後の確認の後に変わると、`musubi check`がスキルを断ります。

効果は、finktheartistのSakuga VFXの中核のファイルを、MITライセンスのまま改変せず`skills/motion-explainer/vendor/sakuga-vfx/`に同梱して使います。ライセンスと写した元のコミットも同じ場所に置きます。
`skills/motion-explainer/themes/pixel/faces/`の4体は、このプラグインのために画像のモデルで描いた物で、プラグインのライセンスで配ります。

## 必要な物

| ツール | 要る時 |
|---|---|
| Python 3 | 常に |
| `uv` | 組み立てる時と撮る時。`build.py`と`capture.py`は`uv run --with Pillow==13.0.0`で起動し直し、1回の実行の間だけPillowをuvのキャッシュに取ってきます。`uv`が無いと何も書かず、入れ方を示します |
| Chromium系のブラウザー | 撮る時。`capture.py`は、このPCに既にあるGoogle Chrome、Chromium、Microsoft Edge、Brave、Playwrightのヘッドレスのシェルのどれかを使います |

このPCのPythonには何もインストールしません。

## 読む物と動かす物と送る物

- 示された資料と、テーマのフォルダーと、台本と、それらが名指す絵と、スキルが持つエンジンと効果のファイルだけを読みます。資料は説明する対象として扱い、指示としては扱いません
- Pillowを1回の実行の間だけ取ってくるために`uv`を動かし、撮る時は使い捨てのプロファイルでヘッドレスのブラウザーを動かして、後でプロファイルを消します
- 台本と絵とページと撮った画像は、あなたが指定した場所か、資料の隣にだけ書きます
- ページはネットワークから何も読み込まず、明るい表示と暗い表示の選択だけをブラウザに保ちます
- `uv`がPillowを取ってくる以外は、どこにも何も送りません

## ライセンス

[MIT](LICENSE)
