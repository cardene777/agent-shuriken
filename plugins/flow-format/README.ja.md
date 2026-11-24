# Flow Format

流れ、手順、ワークフローがどう進むかを、番号の付いた手順で説明します。
各手順は、1つの動作と短い詳しい段落でできています。

[English](README.md) · 日本語

物事がどう進むかを聞かれると、エージェントは太字の見出しと字下げした箇条書き、名前を矢印でつないだだけの列、端末では生の文字で出るMermaidの図で答えがちです。
このプラグインは、エージェントに答えの形を1つ渡します。
番号の付いた手順で、各手順は動詞で始まる動作の1文、空行、字下げしない1〜3文の段落でできています。
流れに分岐や戻りが在る時は、手順の後に文字で描いた図を足せます。

```text
1. Create a branch for the issue from the latest main branch.

The branch keeps the change apart from other work until it is reviewed.
Name it after the issue so that anyone can find it.
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install flow-format@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add flow-format@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install flow-format@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/flow-format/skills/flow-format   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに付けたスキルのzipを、エージェントのスキルのフォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

始めから終わりまでどう進むかを聞くと始まります。
たとえば「Issueから変更がmainに入るまでどう進む？」「リリースのスクリプトを回すと何が起きる？」「環境の準備を順に教えて」と聞きます。
Claude Codeでは`/flow-format:flow-format`を実行し、Codexでは`$`を入力して**Flow Format**を選ぶと、名指しで呼び出せます。
GitHub Copilot CLIでは依頼の文に`/flow-format`を書き、Gemini CLIでは作業を文で伝えます。

| 聞くこと | 答えに入るもの |
|---|---|
| 流れ、手順、段の連鎖、ワークフロー | 番号の付いた手順。各手順は動作の1文と1〜3文の段落 |
| 分岐や戻りの在る流れ | 同じ手順と、その後に箱と矢印を文字で描いた図 |
| 1つのファイルや1つの考え (関数が何を返すかなど) | ふだんの答え。このプラグインは始まりません |

答えは、聞いた人が書いた言語で書かれます。
Mermaidは、プルリクエストの説明文のように頼まれたファイルにだけ書き、チャットの答えには書きません。

## 読む物と動かす物と送る物

このプラグインは指示のファイル1つだけで、何も動かしません。
読むのは会話だけで、何も残さず、どこにも送りません。

## ライセンス

[MIT](LICENSE)
