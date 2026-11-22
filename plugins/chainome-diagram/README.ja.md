# Chainome Diagram

ブロックチェーンの仕組みを説明する動く図を、ReactとSVGで描いてGSAPかMotionで動かす形で設計し、見直します。

[English](README.md) · 日本語

ERC-20の送金のような仕組みの図は、2つの点で誤りやすくなります。
1つは、残高は契約の保存領域に在るのに、トークンが財布の間を飛ぶように描くなど、起きない所に物を置くことです。
もう1つは、全部の段を一度に出し、図の中に長い文を置くことです。
この技は、codeを書く前に場面の型を書かせ、動く段を1つに絞り、状態の変化を起きた所に札で出し、説明の文を図と別の欄に置かせます。
その後、PCとスマートフォンの画面の写しを、仕組みの構造、因果、状態、焦点、配置、スマートフォンでの見え方の関門で見直し、重い問題が無くなるまで直し続けます。

```
Scene model ──> Render ──> Lint, build, screenshots ──> Review gates ──> Hand off
 (agent)        (agent)     (your project's commands)     (agent)          (agent)
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

Claude Codeでは`/chainome-diagram:chainome-diagram`を実行し、Codexでは`$`を入力して**Chainome Diagram**を選びます。
ブロックチェーンの仕組みの動く図を頼んでも始まります。

```
Design an animated diagram that explains an ERC-20 transfer, with the contract as the main boundary
```

説明する考え方や、仕組みをどこまで省くかが分からない時は、描く前にエージェントが会話で尋ねます。

## 必要なもの

- 図をSVGで描くReactのプロジェクトと、時間の流れを組むGSAPかMotion
- 見直しで読むPCとスマートフォンの画面の写しを撮る、プロジェクトのPlaywright

## 読む物と動かす物と送る物

場面の型と見直しの関門は[仕組み](docs/how-it-works.ja.md)にあります。
要点は次のとおりです。

- プラグインはスクリプトを持ちません。エージェントが読み書きするのは、あなたのプロジェクトのファイルだけです
- `pnpm lint`、`pnpm typecheck`、`pnpm build`、Playwrightの画面の写しなど、プロジェクトの命令を動かします
- 何も残さず、どこにも送りません

## ライセンス

[MIT](LICENSE)
