# Excalidraw Diagram

アーキテクチャ図、フロー図、シーケンス図、ER図を、スクリプトが配置して見せる前に確かめたExcalidrawのファイルとして描きます。SVGとPNGの写しも作ります。

[English](README.md) · 日本語

エージェントが目分量で置いた図は、箱どうしが触れる、ラベルが線に重なる、矢印がほかの箱を突き抜ける、図形を動かすと矢印が外れる、といった崩れが起きがちです。
このプラグインは作業を分けます。エージェントは図が伝える中身を決めて小さなJSONの仕様に書き、Pythonのスクリプトがすべての座標を計算し、矢印の道筋を決め、何かを書く前に配置の決まりで結果を確かめます。
出力はExcalidrawのエディタで開いて編集を続けられる`.excalidraw`のファイルと、文書やプルリクエストに貼るSVGとPNGです。
何もダウンロードせず、ネットワークも使いません。
このプラグインはExcalidrawの公開されたファイル形式を扱うもので、Excalidrawのプロジェクトが作った物でも、関係のある物でもありません。

```
中身を決める ──> 仕様を書く ──> 配置して確かめる ──> 結果を見る ──> Excalidrawで開く
 (エージェント)   (エージェント)  (スクリプト)          (エージェント)  (あなた)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install excalidraw-diagram@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add excalidraw-diagram@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install excalidraw-diagram@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/excalidraw-diagram/skills/excalidraw-diagram   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「このサービスのアーキテクチャ図を描いて」「サインインのシーケンス図を作って」「このMermaidのフローチャートをExcalidrawのファイルにして」のように、図を頼むと始まります。
呼び出して始めることもできます。Claude Codeでは`/excalidraw-diagram:excalidraw-diagram`を実行し、Codexでは`$`を入力して**Excalidraw Diagram**を選びます。
GitHub Copilot CLIでは依頼の中に`/excalidraw-diagram`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントが、依頼、Mermaidの図、指したコードから部品とつながりを読み取り、はっきりしない時は尋ねます
2. エージェントが`docs/images/checkout.diagram.json`のような仕様を書きます。各箱には、項目、プロトコル、ポートのような具体的な中身を入れます
3. スクリプトが図を配置して確かめ、ラベルが収まらない時は間隔を広げ、`checkout.excalidraw`、`checkout.svg`、`checkout.png`を書きます。確かめに通らない時は理由を示して止まり、何も書きません
4. エージェントは画像を見られる時にPNGを見て、読み違えやすい所を直し、ファイルの場所を伝えます

組み立ては次のようになります。

```text
Checked 8 shapes, 5 arrows, 0 lines, and 12 texts.
No problems found.
Wrote docs/images/checkout.excalidraw
Wrote docs/images/checkout.svg (558x868)
Wrote docs/images/checkout.png (1116x1736) with chrome-headless-shell
```

Chrome、Chromium、Edgeのどれも無い時は、最後の行の代わりに、PNGを作らなかったことと理由を示す行が出ます。SVGに同じ図が入っています。

エディタで誰かが箱を動かした後のファイルを確かめると、次のようになります。

```text
Checked 8 shapes, 5 arrows, 0 lines, and 12 texts.
2 problems:
  spacing: "Order service" and "Payment service" are 24 px apart; keep at least 40 px between shapes
  font-size: text "HTTPS" is 12px; use at least 16 px
```

交わるか触れている矢印は、`Warning: crossing:`で始まる行で示します。交わりを避けられない図もあるため組み立ては失敗にせず、エージェントが一度取り除こうとし、残った物をあなたに伝えます。

## 描ける図

| 種類 | 配置の仕方 |
|---|---|
| アーキテクチャ図とフローチャート | ノードを下向きか右向きに流れる段に並べ、各段を同じ線の上で中央に揃え、交わる矢印が減る順にします。箱、楕円、ひし形を使って名前を太字にし、グループは破線の囲みで包みます |
| ER図 | `table`のノードです。名前の下に項目の一覧を置き、テーブルどうしを矢印でつなぎます |
| シーケンス図 | 参加者を横一列に並べて破線の生存線を引き、メッセージを1行に1つずつ置きます。返信は破線で、自分へのメッセージは輪で描きます |

矢印はつないだ図形に結び付けるため、エディタで図形を動かすと矢印も付いてきます。
Mermaidのフローチャートやシーケンス図から始めることもできます。変換は文書にした範囲だけを読み、読めない所は行を示します。
`.excalidraw`のファイルは、`"style": "sketch"`にするとエディタの手描き風の見た目になります。SVGとPNGは常にすっきりした図形と、お使いのマシンのフォントで描きます。

## Excalidrawで編集する

`.excalidraw`のファイルをExcalidrawのエディタで開き、そこで編集します。例えばWebアプリのメニューから開くか、キャンバスにドラッグします。
その後にエージェントへ変更を頼んでも、編集したファイルは上書きしません。スクリプトは書いた後に変わったファイルの置き換えを断り、エージェントが先にあなたに尋ねます。
エージェントは、編集したファイルを同じ決まりで確かめることも、ファイルを変えずに新しいSVGとPNGを作ることもできます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に。標準ライブラリだけを使います |
| Google Chrome、Chromium、Microsoft Edge | PNGを作る時だけ、既に入っていれば使います。無い時は`.excalidraw`のファイルとSVGができます |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、仕様、配置の仕方、すべての確かめ、PNGの作り方を載せています。
要点は次のとおりです。

- エージェントが書く仕様、あなたが指したMermaidのファイル、確かめや書き出しを頼まれた`.excalidraw`のファイルを読みます。コードのファイルは、その図を頼まれた時だけエージェントが読みます
- 選んだフォルダに`<名前>.excalidraw`、`<名前>.svg`、`<名前>.png`を書きます。自分が書いていないファイルや、書いた後に変わったファイルは、あなたに尋ねずに置き換えません
- PNGを作る時は、マシンに既にあるブラウザを画面無しで動かします。使い捨てのプロファイルは後で削除し、ホスト名の名前解決はすべて止め、開くのは手元のSVGだけです
- どこにも何も送らず、頼まれたファイルのほかは何も残しません

## ライセンス

[MIT](LICENSE)
