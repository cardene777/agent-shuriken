# Blockchain Diagram

ブロックチェーンの仕組みを説明する動く図を、ReactとSVGで描いてGSAPかMotionで動かす形で設計し、見直します。

[English](README.md) · 日本語

ERC-20の送金のような仕組みの図は、2つの点で誤りやすくなります。
1つは、残高は契約の保存領域に在るのに、トークンが財布の間を飛ぶように描くなど、起きない所に物を置くことです。
もう1つは、全部の段を一度に出し、図の中に長い文を置くことです。
この技は、codeを書く前に場面の型を書かせ、動く段を1つに絞り、状態の変化を起きた所に札で出し、説明の文を図と別の欄に置かせます。
その後、PCとスマートフォンの画面の写しを、仕組みの構造、因果、状態、焦点、配置、スマートフォンでの見え方の関門で見直し、重い問題が無くなるまで直し続けます。
意匠のfileを置けば、図は色と書体と文字の大きさと角の丸みをそこから取ります。置かなければ、プロジェクトの今の見た目のままです。

```
Theme file ──> Scene model ──> Render ──> Lint, build, screenshots ──> Review gates ──> Hand off
 (script)       (agent)        (agent)     (your project's commands)     (agent)          (agent)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install chainome-diagram@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add chainome-diagram@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install chainome-diagram@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/chainome-diagram/skills/chainome-diagram   # Gemini CLI
```

`SKILL.md`を読むほかのagentでは、各リリースに添付したskillのzipをagentのskillのフォルダーへ展開します。手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

Claude Codeでは`/chainome-diagram:chainome-diagram`を実行し、Codexでは`$`を入力して**Blockchain Diagram**を選びます。
ブロックチェーンの仕組みの動く図を頼んでも始まります。

```
Design an animated diagram that explains an ERC-20 transfer, with the contract as the main boundary
```

説明する考え方や、仕組みをどこまで省くかが分からない時は、描く前にエージェントが会話で尋ねます。

## 自分の意匠

スキルは描く前に`diagram-theme.py`を動かし、次の2つのうち先に在るfileを読みます。
design-formatsの`page-design`スキルと同じ意匠のfileを使うので、図と頁が1つの見た目に揃います。

| 順 | file | 使い道 |
|---|---|---|
| 1 | repoの根の`.design-theme.json` | 1つのプロジェクトの見た目 |
| 2 | `~/.design-theme.json` | 自分が作る全ての物の見た目 |

全ての鍵を持つ意匠のfileは次の形です。
どの鍵も省けて、省いた鍵はプロジェクトの値のまま残ります。

```json
{
  "light": {
    "bg": "#fafaf7", "surface": "#ffffff", "ink": "#111111", "sub": "#444444", "line": "#dddddd",
    "accent": "#0b6e4f", "accent-ink": "#ffffff", "accent-soft": "#e3f2ec", "bar": "#eeeeee", "label": "#f2f2f2"
  },
  "dark": {
    "bg": "#101312", "surface": "#181c1a", "ink": "#eeeeee", "sub": "#b0b8b4", "line": "#2c3330",
    "accent": "#5fd0a5", "accent-ink": "#0b1410", "accent-soft": "#1b3a2f", "bar": "#232a27", "label": "#1f2523"
  },
  "font": { "sans": "\"Inter\", sans-serif", "mono": "\"JetBrains Mono\", monospace", "size": 16, "line-height": 1.75 },
  "space": { "page-width": 1100, "radius-small": 4, "radius": 6, "radius-large": 8 }
}
```

エージェントは値を図のCSSの変数に書きます。`accent`は動く道と動くトークン、`line`は止まっている道と枠、`mono`は関数の名前と保存領域の鍵、`radius-large`は契約の境の色や形を決めます。
全ての鍵と図の部分の対応は[仕組み](docs/how-it-works.ja.md#意匠のfile)にあります。
`light.bar`と`dark.bar`と`space.page-width`は頁のための鍵で、図には使いません。
意匠のfileが無ければ、図は今までどおりプロジェクトの見た目のままです。
知らない鍵か正しくない値を持つ意匠のfileは、鍵を名指して断り、エージェントが先に直すかを尋ねます。

## 必要なもの

- 図をSVGで描くReactのプロジェクトと、時間の流れを組むGSAPかMotion
- 見直しで読むPCとスマートフォンの画面の写しを撮る、プロジェクトのPlaywright
- 意匠のfileを読むスクリプトを動かすPython 3

## 読む物と動かす物と送る物

場面の型と見直しの関門は[仕組み](docs/how-it-works.ja.md)にあります。
要点は次のとおりです。

- プラグインはスクリプトを1つ、`diagram-theme.py`だけ持ちます。読むのは意匠のfileだけで、図が使う値を出します
- エージェントが読み書きするのは、あなたのプロジェクトのファイルだけです
- `pnpm lint`、`pnpm typecheck`、`pnpm build`、Playwrightの画面の写しなど、プロジェクトの命令を動かします
- 何も残さず、どこにも送りません

## ライセンス

[MIT](LICENSE)
