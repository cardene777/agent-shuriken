# Motion Diagram

仕組みを1枚の動く絵で見せます。
カードが流れを1回通って実際の数で止まり、部品を押すとその中身が出ます。

[English](README.md) · 日本語

仕組みを長い文で説明されても追いにくく、止まった図では何がどこへ動き、どれだけ残るのかが見えません。
このプラグインは仕組みを部品と線で描き、カードを1回流します。
カードは入口を出て、絞り込みごとに数の割合で落ち、判断する人を待ち、行き先で止まります。
何も押す前のページには、最初の1文と部品の名前と数しか出ないため、説明を絵が担います。
エージェントは先にあなたと部品を決め、あなたが決めてから絵を書きます。

```
材料を読む ──> 部品を決める ──> 仕様を書く ──> 確かめる ──> ページ ──> 動画、GIF、画像
(エージェント)  (あなたと)       (エージェント)  (エージェント) (あなた)   (頼んだ時)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install motion-diagram@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add motion-diagram@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install motion-diagram@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/motion-diagram/skills/motion-diagram   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、リリースごとに付くスキルのzipを、エージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

仕組みを動く絵で見せてと頼むと始まります。
たとえば「このサービスで注文がどう動くかを動く図で見せて」や「レビューの流れで変更がどう落ちるかをGIFにして」です。
呼び出すこともできます。
Claude Codeでは`/motion-diagram:motion-diagram`を実行し、Codexでは`$`を入力して**Motion Diagram**を選びます。
GitHub Copilot CLIでは頼む文に`/motion-diagram`を書き、Gemini CLIでは作業を説明します。

1. エージェントが文書、課題、コードなどあなたが指した物を読み、物の出どころ、通る段、一部を落とす絞り込み、判断する人、行き先、決して届かない物を見つけます
2. エージェントが部品と数、部品の間の線、最初の1文を見せ、あなたが決めるまで直します
3. エージェントが仕様を書いて確かめ、開くページを書き出します
4. 絵をほかの場所で使いたい時は、エージェントが動画とGIFと画像を書き出します

仕様は次の形です。

```json
{
  "version": 1,
  "title": "Changes reach main only after tests and a review",
  "unit": "a week",
  "parts": [
    { "id": "people", "kind": "source", "name": "Contributors", "count": 40 },
    { "id": "tests", "kind": "check", "name": "Tests", "keep": 30, "details": "The suite runs on each change." },
    { "id": "back", "kind": "bin", "name": "Sent back" },
    { "id": "main", "kind": "end", "name": "main" }
  ],
  "lines": [
    { "from": "people", "to": "tests" },
    { "from": "tests", "to": "back", "drop": true },
    { "from": "tests", "to": "main" }
  ]
}
```

部品は入口、箱、絞り込み、人、落とした物の置き場、行き先、境界の外の物の7種類で、置く場所は線から決まります。
`check`は、受け取った数より多く残す絞り込みのように流れの崩れた仕様と、幅が24を超える部品の名前のように長すぎる文字を断り、その都度欄の名前を出します。
欄の全部は[仕様の形](skills/motion-diagram/references/spec-format.md)にあり、[`examples/`](examples/)に英語と日本語の仕様が1つずつあります。

## 絵

| ファイル | 中身 |
|---|---|
| `<name>.html` | ページです。ネットワークから何も読み込まないため、つながずに開け、1つのファイルのまま添付や共有ができます |
| `<name>.mp4` | 絵を1回流した動画で、`export`が書きます |
| `<name>.gif` | 同じ1回を幅960ピクセルのGIFにした物で、`export`が書きます |
| `<name>.png` | 流れ終えた絵の画像で、`export`が書きます |

ページは開くと1回流れて止まり、その後は何も動きません。
もう一度流すボタンで流し直せます。
動きを減らす設定にした人には、動かさずに最後の数を見せます。
部品を押すと中身が出て、仕様に例があれば例も出ます。
絵は左から右へ流れ、スマートフォンでは上から下へ流れます。
明るい表示と暗い表示があり、ボタンの言葉を英語と日本語で切り替えられます。
色とフォントは共通のテーマのキーの名前を持つため、`page-design`を入れていれば、エージェントがあなたの見た目を当てられます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| Python 3 | 常に要ります。`check`と`render`は標準ライブラリだけを使います |
| Chromium系のブラウザ | `export`で要ります。Google Chrome、Chromium、Microsoft Edge、Braveのどれかが入っていれば使い、無ければPlaywrightのヘッドレスブラウザを取得します |
| Node.js 20以降と`npm` | `export`でブラウザを動かすために要ります |
| ffmpeg | 無くても動きます。`PATH`にあれば、`export`は`ffmpeg-static`を取得せずにそれを使います |

グローバルにパッケージは入れません。
最初の`export`が、`playwright-core` 1.65.0と、ffmpegが無い時は`ffmpeg-static` 5.3.0を`~/.local/share/motion-diagram/node/`に入れます。

## 読む物と動かす物と送る物

[仕組み](docs/how-it-works.ja.md)に、配置、カードの流れ方、書き出しを書いています。
要点は次のとおりです。

- 読むのはあなたが指した材料と仕様だけで、材料は説明する対象として扱い、指示としては扱いません
- 仕様とページと書き出したファイルは、あなたが指定した場所か材料の隣にだけ書きます
- ページはネットワークから何も読み込まず、あなたが選んだテーマだけをブラウザに保ちます
- `export`はページをヘッドレスブラウザで開き、手元のファイル以外への通信を全て止めます
- 最初の`export`で`playwright-core`と、要る時は`ffmpeg-static`かPlaywrightのヘッドレスブラウザを1回取得し、ほかへは何も送りません

## ライセンス

[MIT](LICENSE)
