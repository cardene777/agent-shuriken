# Learning to Skill

会話で得た学びを、エージェントが読む指示のファイルに短い決まり1行として書き、次の会話で同じ間違いを繰り返さないようにします。

[English](README.md) · 日本語

エージェントの間違いを直しても、その訂正はその会話の中にしか残らず、次の会話でまた同じ間違いが起きます。
手で書き残すには、どのエージェントがどのファイルを読むかを知っている必要があります。Codexは`AGENTS.md`、Claude Codeは`CLAUDE.md`、Gemini CLIは`GEMINI.md`、GitHub Copilot CLIは`.github/copilot-instructions.md`と`AGENTS.md`を読み、スキルはそれぞれの`SKILL.md`を持っています。
同じ決まりをそれぞれに写すと、ファイルが膨らみ、内容が少しずつずれていきます。
このプラグインは、ファイルどうしのリンクと`@`での読み込みもたどって、プロジェクトのエージェントが実際に読むファイルを見つけ、必要なエージェントに届くファイルを選び、同じ決まりがまだ無いことを確かめてから、変更を差分で見せます。
書くのはあなたが承認した差分だけで、コミットはしません。

```
決まりを書く ──> ファイルを探す ──> 重複を確かめる ──> 差分を見せる ──> 書き込む
 (エージェント)   (エージェント)     (エージェント)      (あなたが承認)   (エージェント)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install learning-to-skill@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add learning-to-skill@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install learning-to-skill@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/learning-to-skill/skills/learning-to-skill   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「次から覚えておいて」「これをプロジェクトの決まりに足して」「これはもう指示に書いてある？」のように、学びを残すよう頼むと始まります。
同じ間違いを2回直した時には、エージェントの方から使うか尋ねることがあり、何かをする前に必ず確かめます。
呼び出して始めることもできます。Claude Codeでは`/learning-to-skill:learning-to-skill`を実行し、Codexでは`$`を入力して**Learning to Skill**を選びます。
GitHub Copilot CLIでは依頼の中に`/learning-to-skill`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントが、学びを短い決まり1行にします
2. エージェントが、プロジェクトにある指示のファイルと、それぞれを読むエージェントを並べます
3. エージェントが、書くファイルと節を選び、同じことを書いた行がまだ無いかを確かめます
4. エージェントが、差分、それを読むエージェント、似た行を見せます。あなたは承認するか、直すか、見送るかを選びます
5. エージェントが、承認した変更をそのとおりに書きます。その間にファイルが変わっていたら止まります

ファイルの一覧は次のようになります。

```text
Instruction files in ~/projects/shop

  AGENTS.md                          15 lines  Codex, GitHub Copilot CLI, Claude Code (imported by CLAUDE.md)
  CLAUDE.md                           1 line   Claude Code, GitHub Copilot CLI; imports AGENTS.md
  .claude/skills/release/SKILL.md     9 lines  Claude Code, GitHub Copilot CLI; 1 more .md file in the skill folder
  .github/copilot-instructions.md     2 lines  GitHub Copilot CLI
  web/AGENTS.md                       3 lines  Codex, GitHub Copilot CLI; for work in web/

Each agent, in every session
  Claude Code         CLAUDE.md, AGENTS.md (imported by CLAUDE.md)
  Codex               AGENTS.md
  GitHub Copilot CLI  AGENTS.md, CLAUDE.md, .github/copilot-instructions.md
  Gemini CLI          nothing (it reads GEMINI.md, which is missing)

AGENTS.md reaches the most agents: Claude Code, Codex, GitHub Copilot CLI.

Repeated lines
  - Run `pnpm build` before pushing.
    AGENTS.md:6, .github/copilot-instructions.md:1
```

変更の提案は次のようになります。あなたが承認するまで何も書きません。

```text
File       AGENTS.md
Read by    Codex, GitHub Copilot CLI, Claude Code (imported by CLAUDE.md)
Placement  at the end of the section "Testing", after line 11
Size       15 -> 16 lines

--- a/AGENTS.md
+++ b/AGENTS.md
@@ -9,6 +9,7 @@
 
 - Run `pnpm test` for the unit tests.
 - Put new tests next to the code they test.
+- Run `pnpm test:e2e` before opening a pull request; the unit tests do not cover checkout.
 
 ## Style
 

Similar lines already in the instruction files: none

Fingerprint  56d1c6cf161bc716
Nothing was written. Show this diff to the user. After they approve it, run the same command with apply in place of propose and add --expect 56d1c6cf161bc716.
```

## 学びを書く場所

| 学びの対象 | エージェントが書く場所 |
|---|---|
| プロジェクト全体 | 使っているエージェントに最も多く届くファイル。多くは`AGENTS.md`です |
| 1つのフォルダ | そのフォルダに`AGENTS.md`か`CLAUDE.md`があれば、そのファイル |
| 1つのスキル | そのスキルの`SKILL.md`か、その話題を扱う隣のファイル |
| 1つのエージェント | `CLAUDE.md`や`GEMINI.md`のような、そのエージェント用のファイル |
| すべてのプロジェクトでのあなた自身 | `~/.claude/CLAUDE.md`のような、ホームフォルダにあるあなた用のファイル。ほかの人が読むファイルには書きません |

1つの決まりは1か所にだけ書きます。
選んだファイルを読まないエージェントがある時は、決まりを写す代わりに、そのエージェントのファイルから選んだファイルを指すよう提案します。例えば`CLAUDE.md`に`@AGENTS.md`と書きます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、読むファイルの全部、どのエージェントを読み手と数えるか、似た行の見つけ方、変更の書き方を載せています。
要点は次のとおりです。

- プロジェクトにある指示のファイル、その下の`SKILL.md`、`.gemini/settings.json`を読みます。依存パッケージとビルドのフォルダ、ほかのリポジトリ、worktreeは飛ばします
- `--home`を付けると、ホームフォルダにあるClaude Code、Codex、Gemini CLI、GitHub Copilot CLIの指示のファイルとスキルのフォルダも読みます
- 書くのは、あなたが承認した変更を、名前を示した1つのファイルにだけです。コミットはしません
- ほかのプログラムは動かさず、どこにも何も送らず、自分用のファイルも残しません

## ライセンス

[MIT](LICENSE)
