# Remotion Explainer

Remotionで作る解説動画のフレームを機械で確かめます。
線が接続点で終わっているか、画面の安全な範囲と字幕の場所を守っているか、要素の出始めと消え際に1フレームだけ何かが映らないか、同じ作りの場面が続かないかを調べます。

[English](README.md) · 日本語

解説動画は普通の速さで見ると問題が無くても、線が相手の図形に刺さっていたり、ラベルが箱に触れていたり、線が描かれ始める前の1フレームに点が映っていたり、5つの場面が同じ3枚のカードでできていたりします。
このプラグインはそうした決まりを、Remotionのプロジェクトのファイルに対する取り決めとして書き、ファイルごとに機械で確かめます。
問題ごとに、どの要素か、どの場面か、どのフレームかを名指します。
Remotionの動画を作るスキルや見直すスキルは、この取り決めにmusubiで従うため、どのスキルも同じバージョンで確かめます。

```
絵コンテのファイルを書く ──> 確かめる ──> 問題を直す ──> フレームを書き出す ──> 境目を確かめる
(エージェント)              (エージェント) (エージェント) (Remotion)            (エージェント)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install remotion-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add remotion-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install remotion-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-frame-checks   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、リリースごとに付くスキルのzipを、エージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

Remotionの動画の図形、配置、時間、場面の作りを確かめてと頼むと始まります。
たとえば「このRemotionのプロジェクトの配置を確かめて」や「矢印が早く映るフレームを探して」です。
呼び出すこともできます。
Claude Codeでは`/remotion-explainer:remotion-frame-checks`を実行し、Codexでは`$`を入力して**Remotion Frame Checks**を選びます。
GitHub Copilot CLIでは依頼の中に`/remotion-frame-checks`と書き、Gemini CLIではやりたいことを書きます。

1. エージェントがRemotionのプロジェクトの絵コンテのファイル、`storyboard/svg-geometry.json`と`storyboard/layout-spec.json`と`storyboard/scene-design-layers.json`を書くか読みます
2. エージェントがファイルごとに確かめ、名指された問題を全部直し、通るまで繰り返します
3. 出始めと消え際がある要素ごとに、エージェントがその境目の前後2フレームをRemotionで書き出し、確かめます

## 取り決めと確かめる物

| 取り決め | 対象のファイル | 通さない物 |
|---|---|---|
| SVGの図形 | `storyboard/svg-geometry.json` | 接続点で始まらない線と終わらない線、縁から外れた接続点、避けるべき物を通る線、決めた間隔より近い2つの要素、目的の場所から離れて止まる動き |
| 配置 | `storyboard/layout-spec.json` | 安全な範囲から出た要素、字幕の場所に入った物、重なりと決めた間隔より狭い隙間、揃っていない組、避けるべき物を通る道筋、6つより少ない見直しのフレーム |
| 時間の境目 | 出始めか消え際の前後で書き出したPNGのフレーム | 出始めより前と消え際より後に映る画素、3フレーム以下だけ映る要素、一度消えてまた映る要素、抜けた境目のフレーム |
| 場面の4つの層 | `storyboard/scene-design-layers.json` | 形、構図、文字、動きのどれかが無い場面、理由の無い独自の層、同じ作りが続く2つの場面 |

どの確かめも、`decision` (`pass`か`revise`) と問題の一覧を持つJSONを1つ出し、通れば0、問題があれば1、呼び方が誤っていれば2で終わります。
[`examples/`](skills/remotion-frame-checks/examples/)に種類ごとの正しいファイルがあり、[仕組み](docs/how-it-works.ja.md)に確かめ方の説明があります。

ほかのスキルは、`remotion-frame-checks`の`layout`のように取り決めを名指し、このスキルを名前で開いて従います。

## 必要な物

| 道具 | 要る時 |
|---|---|
| Node.js 18以降 | 常に要ります。確かめる仕組みはNode.jsに初めから入っている部品だけを使うため、何もインストールしません |
| Remotion | 時間の境目を確かめるフレームを書き出す時に要ります。あなたのプロジェクトに入れる物です |

## Remotionのライセンス

このプラグインはRemotionのパッケージも、Remotionの公式のスキルも同梱しません。
読むのは、あなたのRemotionのプロジェクトのファイルと、書き出したフレームだけです。
Remotionはあなたのプロジェクトに入れる物で、Remotion Licenseに従います。
Free Licenseで使えるのは個人と3人までの会社で、それ以外の会社はRemotionを使う前にRemotionからCompany Licenseを受ける必要があります。

## 読む物と動かす物と送る物

確かめ方は[仕組み](docs/how-it-works.ja.md)にあります。
要点は次の4つです。

- コマンドで名指したファイルだけを読み、その中身は指示でなくデータとして扱います
- このプラグインの確かめる仕組みを`node`で動かし、フレームの書き出しが要る時はあなたのプロジェクトで`npx remotion still`を動かします
- 書くのは、`--audit-dir`か`--out`が指す所、たとえばプロジェクトの`out/review/`の記録だけです
- プロジェクトの外には何も残さず、どこにも何も送りません

## ライセンス

[MIT](LICENSE)
