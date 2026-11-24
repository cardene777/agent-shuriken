# Remotion Explainer

題材そのものを絵にしたRemotionの解説動画を、あなたが承認する関門を通して作ります。
1つの主役を場面から場面へ受け渡し、どの動きも実際に見た動画を根拠にして動きを計画し、独自のPNGの原画と描き込まれる輪郭を作り、利用を許すライセンスのRemotionの作例のカタログから作例を探します。
フレームは機械で確かめ、線が接続点で終わるか、画面の安全な範囲と字幕の場所を守るか、要素の出始めと消え際に何かが一瞬映らないかを調べます。

[English](README.md) · 日本語

解説動画は普通の速さで見ると問題が無くても、線が相手の図形に刺さっていたり、ラベルが箱に触れていたり、線が描かれ始める前の1フレームに点が映っていたり、5つの場面が同じ3枚のカードでできていたりします。
場面ごとに画面を消す小さなデモの並びになり、最初から全部の要素が出たまま漂って時間を埋めることもあります。
このプラグインはそうした決まりを、Remotionのプロジェクトのファイルに対する取り決めとして書き、ファイルごとに機械で確かめます。
問題ごとに、どの要素か、どの場面か、どのフレームか、根拠の一覧のどの項目かを名指します。
入口は`remotion`で、題材のアートディレクションと短い基準の場面から、全ての区切りをつないだ音の無いラフ、静止したボード、仕上げまでを進め、関門ごとにあなたが承認するまで止まります。
ほかの7つのスキルはそれぞれ1つの部分を受け持ち、どのスキルも互いの取り決めにmusubiで従うため、全てのスキルが同じバージョンで確かめます。

```
アートディレクション ──> 基準の場面 ──> 全区切りのラフ ──> 静止したボード ──> 仕上げ ──> 独立した見直し
(あなたが承認)          (あなたが承認) (あなたが承認)    (あなたが承認)     (エージェント) (エージェント。問題が無くなるまで)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install remotion-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add remotion-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install remotion-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-explainer-production
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-explainer-review
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/png-asset-production
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/png-outline-tracing
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-frame-checks
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-motion-plan
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-catalog
```

`SKILL.md`を読むほかのエージェントでは、リリースごとに付くスキルのzipを、エージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。どのスキルもほかのスキルを名前で開くため、プラグインの全てのスキルを入れます。
`remotion-best-practices`などRemotionの公式のスキルはこのプラグインに含みません。あなたのRemotionのプロジェクトで`npx remotion skills add`を実行すると入り、無い時はエージェントがRemotionの公式のドキュメントを代わりに読みます。

## 使い方

このプラグインには8つのスキルがあり、それぞれ自分の仕事を頼むと始まります。
動画を作る時は`remotion`を呼び出します。表で`remotion`の下にある4つのスキルは`remotion`が呼び出すため、自分で呼ぶのは1つの部分だけをやり直す時です。

| スキル | たとえばこう頼むと始まります | 呼び出し方 |
|---|---|---|
| `remotion` | 「荷物が仕分けられる流れの解説動画を作って」 | Claude Codeでは`/remotion-explainer:remotion`を実行し、Codexでは`$`を入力して**Remotion**を選びます |
| `remotion-explainer-production` | 「この解説動画の承認済みの場面を組み立てて」 | Claude Codeでは`/remotion-explainer:remotion-explainer-production`を実行し、Codexでは`$`を入力して**Remotion Explainer Production**を選びます |
| `remotion-explainer-review` | 「この解説動画の今の組み立てを実際のフレームで見直して」 | Claude Codeでは`/remotion-explainer:remotion-explainer-review`を実行し、Codexでは`$`を入力して**Remotion Explainer Review**を選びます |
| `png-asset-production` | 「荷物と仕分け機のPNGの原画を作って」 | Claude Codeでは`/remotion-explainer:png-asset-production`を実行し、Codexでは`$`を入力して**PNG Asset Production**を選びます |
| `png-outline-tracing` | 「承認した荷物のPNGの輪郭をなぞって」 | Claude Codeでは`/remotion-explainer:png-outline-tracing`を実行し、Codexでは`$`を入力して**PNG Outline Tracing**を選びます |
| `remotion-motion-plan` | 「この解説動画の場面の動きを計画して」 | Claude Codeでは`/remotion-explainer:remotion-motion-plan`を実行し、Codexでは`$`を入力して**Remotion Motion Plan**を選びます |
| `remotion-frame-checks` | 「このRemotionのプロジェクトの配置を確かめて」や「矢印が早く映るフレームを探して」 | Claude Codeでは`/remotion-explainer:remotion-frame-checks`を実行し、Codexでは`$`を入力して**Remotion Frame Checks**を選びます |
| `remotion-catalog` | 「2つの道筋を比べる場面の構図を探して」や「Remotionで作った題名の出し方を探して」 | Claude Codeでは`/remotion-explainer:remotion-catalog`を実行し、Codexでは`$`を入力して**Remotion Catalog**を選びます |

GitHub Copilot CLIでは依頼の中に`/remotion`のようにスラッシュを付けたスキルの名前を書き、Gemini CLIではやりたいことを書きます。

1. あなたとエージェントで題材、見る人、長さ、声の有無を決め、エージェントがアートディレクションを`production.json`に書きます。動画を何の絵として見せるか、どんな物が出るか、それぞれの動き、章ごとに初めて見せる物を決めます
2. エージェントが`remotion-motion-plan`で場面ごとの動きを計画し、どの動きもあなたの動きの根拠の一覧にある動画を根拠にします。場面ごとの形、構図、文字、動きはカタログから探します
3. エージェントが動画全体を1つの状態の移り変わりとして表す`beat-dossier.json`を書き、確かめます
4. エージェントが一番難しい因果を見せる12秒から15秒の基準の場面を作り、あなたが絵柄と密度を承認します
5. エージェントが仮の形で全ての区切りをつないだ音の無いラフを作り、あなたが説明の順と続き方と各場面の見せ方を承認します
6. `png-asset-production`が物と状態ごとに透過のPNGを1枚ずつ、初めはフェルトアップリケの素材で作り、描き込む物は`png-outline-tracing`が輪郭をなぞります。エージェントに画像を作る道具が無い時は、作る絵とその指示文の一覧を渡し、あなたが用意したPNGを確かめます
7. エージェントが静止したボードを1枚ずつ作り、動きを付ける前にあなたが1枚ずつ承認します
8. `remotion-explainer-production`が動画の全体を組み立て、`remotion-explainer-review`が実際のフレームで見直し、問題が無くなるまで差し戻します

## 取り決めと確かめる物

| 取り決め | 対象のファイル | 通さない物 |
|---|---|---|
| 区切りの記録 | `beat-dossier.json` | 問い、証拠、操作、読ませる間、受け渡しのどれかが無い区切り、見せ方を表す言葉だけの操作、主役にした題名やカード、後に続かない区切りへの受け渡し |
| 区切りの見直し | `out/review/beat-review.json` | 区切りの記録と組み立てのハッシュが無い見直し、4枚の実際のフレームが無い区切り、4より低い点 |
| 紙のボード | 紙に描く見せ方の動画の`paperboard.json` | 骨組み、描く順、注目の移り、読ませる間のどれかが無い区切り、対象の無い骨組み、終わらない最後の区切り |
| 舞台のテーマ | 舞台のテーマを選んだ`production.json` | 原画の素材、使える部品、方針のどれかが無いテーマ、テーマと違う素材の原画 |
| 図形の標本 | `out/review/geometry-samples.json` | 安全な範囲から出た物、許していない重なり、縁と縁で合わない接続、止まっているはずなのに揺れる物 |
| 続き方の標本 | `out/review/continuity-samples.json` | 物を運ばず何も受け渡さない場面の境目、カメラや運ぶ物の飛び |
| 原画の記録 | PNGごとの`asset-manifest.json` | 足りない欄、6つにない素材、まとめての移動、拡大と縮小、薄れ、切り抜きを超える動き、無いPNG、大きさの違うPNG、透過の無いPNG |
| 振り付け | `storyboard/choreography-plan.json` | 最初から全部の物が出ている場面、どの物の状態も変わらない場面、2種類より少ない動き、前の場面と同じ見せ方の型、仕上げと動きが違う下書き |
| 続いた振り付け | `storyboard/continuous-choreography-plan.json` | 前の場面が渡していない主役から始まる場面、動画を通して追う主役が半分より少ない場面にしか出ないこと、同じ向きに動く2つの続いた場面、新しい記号を足すまとめ |
| 動きの言葉 | `storyboard/motion-language-plan.json` | その動きを見せる、見た動画を根拠に持たない場面、前の場面と同じ主な動き、6種類より少ない主な動きの長い動画 |
| 動きの根拠 | あなたの一覧、`~/.local/share/remotion-explainer/motion-evidence-library.json` | 時間の範囲の無い確かめ済みの項目、同じIDの2つの項目、アドレスの無い出所 |
| SVGの図形 | `storyboard/svg-geometry.json` | 接続点で始まらない線と終わらない線、縁から外れた接続点、避けるべき物を通る線、決めた間隔より近い2つの要素、目的の場所から離れて止まる動き |
| 配置 | `storyboard/layout-spec.json` | 安全な範囲から出た要素、字幕の場所に入った物、重なりと決めた間隔より狭い隙間、揃っていない組、避けるべき物を通る道筋、6つより少ない見直しのフレーム |
| 時間の境目 | 出始めか消え際の前後で書き出したPNGのフレーム | 出始めより前と消え際より後に映る画素、3フレーム以下だけ映る要素、一度消えてまた映る要素、抜けた境目のフレーム |
| 場面の4つの層 | `storyboard/scene-design-layers.json` | 形、構図、文字、動きのどれかが無い場面、理由の無い独自の層、同じ作りが続く2つの場面 |

どの確かめも、`decision` (`pass`か`revise`) と問題の一覧を持つJSONを1つ出し、通れば0、問題があれば1、呼び方が誤っていれば2で終わります。
確かめる仕組みを持つスキルの`examples/`に、倉庫から仕分け機を通って玄関へ運ばれる荷物を題材にした、種類ごとの正しいファイルがあり、[仕組み](docs/how-it-works.ja.md)に確かめ方の説明があります。
`png-outline-tracing`には輪郭をなぞる仕組みもあり、透過のPNGを1枚受け取り、PNGの色が出る前に描き込む輪郭の線を書き出します。

ほかのスキルは、`remotion-frame-checks`の`layout`のように取り決めを名指し、そのスキルを名前で開いて従います。
従う向きは一方通行です。フレームの確かめと動きの計画とカタログは何にも従わず、2つのPNGのスキルはフレームの確かめと、片方向に互いに従うだけで、`remotion`はそれらに従い、組み立てと見直しのスキルは`remotion`と残りに従います。

## カタログ

`remotion-catalog`は、`data/sources.json`に載った出所をあなたのデータのフォルダに取ってきて、その作例から1つのカタログを作ります。
探す時は、形、構図、文字、動きのうち1つの層ずつ探します。

| 出所 | 中身 | ライセンス |
|---|---|---|
| `reactvideoeditor/remotion-templates` | `templates/`の下に1つずつ`.tsx`のファイルで書かれたRemotionのテンプレート | MIT |
| `Vincentwei1021/video-shotcraft` | ショットの作り方を書いた`gallery/api/library.json`のショットカードと、`demos/`の下にあるRemotionのデモ | Apache-2.0 |

出所はどれも1つのコミットに固定します。
`sync`は、コミットが完全なハッシュでない出所と、利用を許すライセンスでない出所と、そのコミットにライセンスのファイルか節が無い出所を取ってきません。
出所のコードは動かさず、ファイルを読むだけです。
エージェントは仕組みを作る部分だけを、出所のライセンスの表示と一緒に写します。
`video-shotcraft`の音は取ってきません。その出所の注意書きに、一部の音は出所を確かめていないと書かれているためです。
出所ごとのコミットとライセンスの根拠は[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)にあります。

```
sync ──> build ──> search --layer composition compare two routes
(git)    (catalog.json)   (出所とコミットとライセンスとファイルを持つ項目)
```

## 必要な物

| 道具 | 要る時 |
|---|---|
| Node.js 18以降 | 常に要ります。確かめる仕組みと輪郭をなぞる仕組みとカタログはNode.jsに初めから入っている部品だけを使うため、何もインストールしません |
| Python 3 | 原画の記録を確かめる時に要ります。標準ライブラリだけを使います |
| `git` | カタログの出所を取ってくる時に要ります |
| Remotion | 動画と、確かめる仕組みが読むフレームを書き出す時に要ります。あなたのプロジェクトに入れる物です |
| 画像を作る道具 | 無くても使えます。無い時は、エージェントが渡す指示文からあなたがPNGを作ります |

## Remotionのライセンス

このプラグインはRemotionのパッケージも、Remotionの公式のスキルも同梱しません。
読むのは、あなたのRemotionのプロジェクトのファイルと、書き出したフレームだけです。
カタログが取ってくるのはRemotionのために書かれた作例で、Remotionそのものではありません。
Remotionはあなたのプロジェクトに入れる物で、Remotion Licenseに従います。
Free Licenseで使えるのは個人と3人までの会社で、それ以外の会社はRemotionを使う前にRemotionからCompany Licenseを受ける必要があります。

## 読む物と動かす物と送る物

確かめ方と、輪郭をなぞる仕組みと、カタログの仕組みは[仕組み](docs/how-it-works.ja.md)にあります。
要点は次の7つです。

- コマンドで名指したファイルだけを読み、その中身は指示でなくデータとして扱います
- このプラグインの確かめる仕組みと輪郭をなぞる仕組みとカタログを`node`で動かし、原画の記録の確かめを`python3`で動かし、カタログの出所を取ってくる時に`git`を動かし、動画とフレームの書き出しはあなたのプロジェクトでRemotionを動かします
- 計画は`storyboard/`に、`production.json`と`beat-dossier.json`とPNGの原画とその記録と動画の組み立ては、あなたのプロジェクトに書き、見直しの記録は`out/review/`に書きます
- 動きの根拠の一覧と、取ってきた出所と、カタログは、`~/.local/share/remotion-explainer/`か`REMOTION_EXPLAINER_HOME`が名指すフォルダに、あなただけが読めるように置き、あなたが消すまで残します
- PNGの原画の指示文は、エージェントに画像を作る道具がある時だけ、その道具にだけ渡します
- 一覧に合う動きが無い時、エージェントは動きの種類を表す一般的な言葉で動画を探し、名前やあなたのファイルの文では探しません。確かめる仕組みそのものはどこにも何も送りません
- `sync`は`data/sources.json`に載ったリポジトリだけをGitHubから取ってきて、ほかには何も送りません

## ライセンス

[MIT](LICENSE)
