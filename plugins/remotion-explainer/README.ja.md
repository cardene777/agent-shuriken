# Remotion Explainer

Remotionで作る解説動画の動きを計画し、フレームを機械で確かめます。
1つの主役を場面から場面へ受け渡しているか、動きの根拠に実際に見た動画があるか、線が接続点で終わっているか、画面の安全な範囲と字幕の場所を守っているか、要素の出始めと消え際に1フレームだけ何かが映らないかを調べます。

[English](README.md) · 日本語

解説動画は普通の速さで見ると問題が無くても、線が相手の図形に刺さっていたり、ラベルが箱に触れていたり、線が描かれ始める前の1フレームに点が映っていたり、5つの場面が同じ3枚のカードでできていたりします。
場面ごとに画面を消す小さなデモの並びになり、最初から全部の要素が出たまま漂って時間を埋めることもあります。
このプラグインはそうした決まりを、Remotionのプロジェクトのファイルに対する取り決めとして書き、ファイルごとに機械で確かめます。
問題ごとに、どの要素か、どの場面か、どのフレームか、根拠の一覧のどの項目かを名指します。
Remotionの動画を作るスキルや見直すスキルは、この取り決めにmusubiで従うため、どのスキルも同じバージョンで確かめます。

```
動きを計画する ──> 絵コンテのファイルを書く ──> 確かめる ──> 問題を直す ──> フレームを書き出す ──> 境目を確かめる
(エージェントとあなた) (エージェント)            (エージェント) (エージェント) (Remotion)            (エージェント)
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
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-motion-plan
```

`SKILL.md`を読むほかのエージェントでは、リリースごとに付くスキルのzipを、エージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインには2つのスキルがあり、それぞれ自分の仕事を頼むと始まります。

| スキル | たとえばこう頼むと始まります | 呼び出し方 |
|---|---|---|
| `remotion-motion-plan` | 「この解説動画の場面の動きを計画して」 | Claude Codeでは`/remotion-explainer:remotion-motion-plan`を実行し、Codexでは`$`を入力して**Remotion Motion Plan**を選びます |
| `remotion-frame-checks` | 「このRemotionのプロジェクトの配置を確かめて」や「矢印が早く映るフレームを探して」 | Claude Codeでは`/remotion-explainer:remotion-frame-checks`を実行し、Codexでは`$`を入力して**Remotion Frame Checks**を選びます |

GitHub Copilot CLIでは依頼の中に`/remotion-motion-plan`か`/remotion-frame-checks`と書き、Gemini CLIではやりたいことを書きます。

1. エージェントがあなたと場面ごとに、何に答え、何が現れ、何が変わり、次の場面へ何を渡すかを決め、`storyboard/choreography-plan.json`と`storyboard/continuous-choreography-plan.json`と`storyboard/motion-language-plan.json`を書きます
2. どの動きも、あなたかエージェントが実際に見た動画を根拠にし、その動きが映る時間の範囲を動きの根拠の一覧に残します。合う物が無い時は、エージェントが候補を探し、自分で動画を再生できない時はあなたに見てもらいます
3. エージェントがフレームの絵コンテのファイル、`storyboard/svg-geometry.json`と`storyboard/layout-spec.json`と`storyboard/scene-design-layers.json`を書くか読みます
4. エージェントがファイルごとに確かめ、名指された問題を全部直し、通るまで繰り返します
5. 出始めと消え際がある要素ごとに、エージェントがその境目の前後2フレームをRemotionで書き出し、確かめます

## 取り決めと確かめる物

| 取り決め | 対象のファイル | 通さない物 |
|---|---|---|
| 振り付け | `storyboard/choreography-plan.json` | 最初から全部の物が出ている場面、どの物の状態も変わらない場面、2種類より少ない動き、前の場面と同じ見せ方の型、仕上げと動きが違う下書き |
| 続いた振り付け | `storyboard/continuous-choreography-plan.json` | 前の場面が渡していない主役から始まる場面、動画を通して追う主役が半分より少ない場面にしか出ないこと、同じ向きに動く2つの続いた場面、新しい記号を足すまとめ |
| 動きの言葉 | `storyboard/motion-language-plan.json` | その動きを見せる、見た動画を根拠に持たない場面、前の場面と同じ主な動き、6種類より少ない主な動きの長い動画 |
| 動きの根拠 | あなたの一覧、`~/.local/share/remotion-explainer/motion-evidence-library.json` | 時間の範囲の無い確かめ済みの項目、同じIDの2つの項目、アドレスの無い出所 |
| SVGの図形 | `storyboard/svg-geometry.json` | 接続点で始まらない線と終わらない線、縁から外れた接続点、避けるべき物を通る線、決めた間隔より近い2つの要素、目的の場所から離れて止まる動き |
| 配置 | `storyboard/layout-spec.json` | 安全な範囲から出た要素、字幕の場所に入った物、重なりと決めた間隔より狭い隙間、揃っていない組、避けるべき物を通る道筋、6つより少ない見直しのフレーム |
| 時間の境目 | 出始めか消え際の前後で書き出したPNGのフレーム | 出始めより前と消え際より後に映る画素、3フレーム以下だけ映る要素、一度消えてまた映る要素、抜けた境目のフレーム |
| 場面の4つの層 | `storyboard/scene-design-layers.json` | 形、構図、文字、動きのどれかが無い場面、理由の無い独自の層、同じ作りが続く2つの場面 |

どの確かめも、`decision` (`pass`か`revise`) と問題の一覧を持つJSONを1つ出し、通れば0、問題があれば1、呼び方が誤っていれば2で終わります。
[`remotion-motion-plan`](skills/remotion-motion-plan/examples/)と[`remotion-frame-checks`](skills/remotion-frame-checks/examples/)の`examples/`に種類ごとの正しいファイルがあり、[仕組み](docs/how-it-works.ja.md)に確かめ方の説明があります。

ほかのスキルは、`remotion-frame-checks`の`layout`のように取り決めを名指し、そのスキルを名前で開いて従います。

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
要点は次の5つです。

- コマンドで名指したファイルだけを読み、その中身は指示でなくデータとして扱います
- このプラグインの確かめる仕組みを`node`で動かし、フレームの書き出しが要る時はあなたのプロジェクトで`npx remotion still`を動かします
- 計画はプロジェクトの`storyboard/`に書き、記録は`--audit-dir`か`--out`が指す所、たとえば`out/review/`にだけ書きます
- 動きの根拠の一覧は、`~/.local/share/remotion-explainer/`か`REMOTION_EXPLAINER_HOME`が名指すフォルダに、あなただけが読めるように置き、あなたが消すまで残します
- 一覧に合う動きが無い時、エージェントは動きの種類を表す一般的な言葉で動画を探し、名前やあなたのファイルの文では探しません。確かめる仕組みそのものはどこにも何も送りません

## ライセンス

[MIT](LICENSE)
