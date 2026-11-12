# Tech Debt

先に直す価値のある技術的負債を見つけます。チームが何度も手を入れていて、しかも大きい、テストが無い、長い関数や古いTODOや写したコードが多いファイルです。

[English](README.md) · 日本語

![報告のページの順位。上位2つのファイルに、何のファイルか、チームの負担になる理由、直す最初の一手をエージェントが書いています](assets/screenshot.png)

リンターは何千もの警告を並べますが、どれが大事かは教えてくれません。
負債が効いてくるのは人が作業し続ける所です。誰も触らない2,000行のファイルの負担は小さく、毎週変わる400行のファイルの負担は大きくなります。
このプラグインはコードとgitの履歴を読み、ファイルごとの変更の回数に、大きさ、長い関数、TODOとFIXMEのコメントとその古さ、重複した部分、テストの有無を合わせて、直すほど効き目の大きいファイルから順位を付けます。
そのうえでエージェントが上位のファイルを読み、何のファイルか、なぜチームの負担になるか、直す最初の一手を書きます。

```
コードと履歴を測る ──> ファイルに順位を付ける ──> 上位のファイルを説明する ──> 報告を見せる
 (エージェント)        (エージェント)             (エージェント)               (エージェント)
```

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install techdebt@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add techdebt@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install techdebt@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/techdebt/skills/techdebt   # Gemini CLI
```

`SKILL.md`を読むほかのエージェントでは、各リリースに添付したスキルのzipを、そのエージェントのスキル用フォルダに展開します。
手順は[はじめに](../../docs/getting-started.ja.md#マーケットプレイスを使わずにインストールする)にあります。

## 使い方

このプラグインは、「このリポジトリの技術的負債はどこにあって、何から直すべき？」のように技術的負債について尋ねると始まります。
呼び出して始めることもできます。Claude Codeでは`/techdebt:techdebt`の後に必要ならフォルダを続けて実行し、Codexでは`$`を入力して**Tech Debt**を選びます。
GitHub Copilot CLIでは依頼の中に`/techdebt`と書き、Gemini CLIではやりたいことを伝えます。

1. エージェントがリポジトリか、その中のフォルダ(monorepoのパッケージ1つなど)を調べます
2. エージェントがファイルに順位を付け、上位のファイルを読んで、何のファイルか、なぜ負担になるか、直す最初の一手を書きます
3. エージェントが報告のページを開き、上位のファイルと各項目の合計をチャットでまとめます

調べた結果の要約は次の形です。

```text
techdebt scan of ~/work/shop (HEAD 3f2a91c on main, 412 source files, 96 test files, 388 commits in the last 12 months)
Hotspots:       118 files changed 2 or more times
Markers:        57 (FIXME 9, HACK 3, TODO 41, deprecated 4), oldest 1312 days
Untested:       64 source files have no test file with a matching name
Long functions: 22 over 60 lines
Large files:    7 over 500 lines
Duplication:    11 blocks, 214 lines
Tool knip:      38 findings

Start here
 1  src/billing/invoice.py  score 0.86  changed 31 times, 612 lines, 3 long functions, marker weight 5, no test file
 2  src/api/orders.ts  score 0.71  changed 44 times, 380 lines, 1 long function, 26 duplicated lines
```

報告のページには、順位のタブと項目ごとのタブがあり、英語と日本語を切り替えられます。

## 必要な物

| 道具 | 要る時 |
|---|---|
| `python3` | 常に |
| `git` | ファイルごとの変更の回数、TODOのコメントの古さ、順位付けに使います。無くてもほかの項目は測れます |
| `knip` | 任意です。プロジェクトの`node_modules/.bin`に入っている時に使います |
| `ruff` | 任意です。`.venv/bin`か`PATH`に入っている時に使います |

## 読む物、動かす物、送る物

[仕組み](docs/how-it-works.ja.md)に、各項目の測り方、順位の付け方、飛ばす物を載せています。
要点は次のとおりです。

- 調べるフォルダのソースファイルと、gitの履歴(`git log`、`git blame`)を読みます
- `knip`と`ruff`は、すでに入っている時だけ動かします。何も取り寄せず、何も入れません
- プロジェクトのファイルは一切書き換えません
- ネットワークにはつなぎません
- `scan.json`、エージェントの説明、`report.html`を`~/.local/share/techdebt/<project>/`に置き、あなただけが読めるようにします。消すまで残ります

## ライセンス

[MIT](LICENSE)
