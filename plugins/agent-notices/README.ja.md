# Agent Notices

Claude CodeとCodexで、はっきりしたエラーを出さずに失敗する間違いをエージェントに知らせ、編集したファイルを整形するフックです。呼び出しを止めることはありません。

[English](README.md) · 日本語

シェルのスクリプトを書き、命令を代わりに打つエージェントは、どの命令も知らせない間違いをします。
`set -o pipefail`の中の`find . | grep -q x`は文字が在っても失敗し、`nohup make &`はエージェントが知らないうちに終わり、`git switch feature`は`main`のままでも、エージェントは切り替えたつもりで進みます。
このプラグインは、エージェントのシェルの命令と編集の後に動くフックを足し、エージェントが次の手の前に読む短い知らせを付けます。
フックは呼び出しを止めず、変えず、許可もしません。
エージェントの許可の決まりは今までどおりです。
危ない命令を止めるフックは、別の[agent-guards](../agent-guards)プラグインにあります。

## インストール

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install agent-notices@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add agent-notices@agent-shuriken
```

フックは次の会話から動きます。
Codexは、信用したプラグインのフックだけを動かします。
Codexの会話で`/hooks`を開き、agent-noticesのフックを信用してください。
更新でフックが変わると、Codexはそのフックを変更済みにして止めるので、`/hooks`でもう一度信用してください。

## 各フックがすること

| フック | 動く時 | エージェントに知らせること | 外す変数 |
|---|---|---|---|
| pipefail-grep | シェルのスクリプトの編集の後 | スクリプトが`pipefail`を設定している中で、足した行が`grep -q`へ流していること。文字が見つかってもパイプが失敗するので、ファイルと行を示します | `AGENT_NOTICES_PIPEFAIL_GREP=off` |
| nohup | シェルの命令の後 | `nohup`を`&`か`disown`と使うと命令が切り離され、終わった知らせが来ないこと。エージェント自身の裏での実行を使うように言います | `AGENT_NOTICES_NOHUP=off` |
| grep-binary | Claude CodeのGrepの後 | 探した所のバイナリのファイルに語が在るのに、何も見つからなかったこと。ファイルを示し、`grep -a`か`rg -a`で探すように言います | `AGENT_NOTICES_GREP_BINARY=off` |
| branch | シェルの命令の後 | `git switch`か`git checkout`の後もリポジトリが別のブランチに居ること、またはその会話が最後に切り替えたのと違うブランチで`git commit`したこと | `AGENT_NOTICES_BRANCH=off` |
| env-example | JavaScript、TypeScript、Python、Go、Ruby、Rustの編集の後 | 編集で足した環境変数の読み取りを、リポジトリの`.env.example`が持っていないこと | `AGENT_NOTICES_ENV_EXAMPLE=off` |
| tmp-space | シェルの命令の後 | 一時ディレクトリの空きが`AGENT_NOTICES_TMP_MIN_GB`ギガバイト (既定は5) より少ないこと | `AGENT_NOTICES_TMP_SPACE=off` |
| security | 編集の後 | 新しいコードに当たる、Anthropicの`security-guidance`プラグインの型ごとの注意。例えば`os.system(`、`innerHTML =`、`pickle.load`、GitHub Actionsのワークフロー | `AGENT_NOTICES_SECURITY=off` |
| format | 編集の後 | 編集したファイルにプロジェクトの整形の道具を回し、ファイルが変わった時は読み直すように知らせます | `AGENT_NOTICES_FORMAT=off` |
| presence | Claude Codeの会話の始めと終わり | 何も知らせません。`CLAUDE_CLIENT_PRESENCE_FILE`が名指すファイルを始めに作り、終わりに消します。ファイルが在る間、Claude Codeはスマホへの通知を控えます | `AGENT_NOTICES_PRESENCE=off` |
| skill-log | Claude Codeのスキルの呼び出し | 何も知らせません。オンの時、呼び出しごとに1行を書きます | `AGENT_NOTICES_SKILL_LOG=on`にしない限りオフ |
| mcp-log | MCPの道具の呼び出し | 何も知らせません。オンの時、呼び出しごとに1行を書きます | `AGENT_NOTICES_MCP_LOG=on`にしない限りオフ |

変数は、Claude Codeでは`~/.claude/settings.json`の`env`に、Codexではシェルの起動ファイルに書きます。
編集の知らせは編集のすぐ後に出ます。
エージェントがそこで読むからです。
CodexにはGrepの道具もスキルの呼び出しも無いので、grep-binaryとskill-logはClaude Codeだけで動きます。
在席のファイルを読むのもClaude Codeだけです。

## 整形の道具

formatのフックは、プロジェクトの設定が名指し、道具が既に入っている時だけ整形の道具を回します。
何も入れず、`npx`も動かしません。

| ファイル | 道具 | 回す時 |
|---|---|---|
| JavaScript、TypeScript、JSON、CSS | Biome、`biome format --write` | ファイルのフォルダかその上に`biome.json`か`biome.jsonc`があり、そこの`node_modules/.bin`か`PATH`に`biome`がある |
| JavaScript、TypeScript、JSON、CSS、HTML、Markdown、YAMLなどPrettierが扱うファイル | Prettier、`prettier --write` | ファイルのフォルダかその上にPrettierの設定ファイルか`package.json`の`prettier`があり、そこの`node_modules/.bin`か`PATH`に`prettier`がある |
| Python | Ruff、`ruff format` | `pyproject.toml`に`[tool.ruff]`があるか`ruff.toml`があり、`.venv/bin`、`venv/bin`、`PATH`のどれかに`ruff`がある |
| Python | Black、`black -q` | `pyproject.toml`に`[tool.black]`があってRuffの設定が無く、`.venv/bin`、`venv/bin`、`PATH`のどれかに`black`がある |
| Go | `gofmt -w` | ファイルのフォルダかその上に`go.mod`があり、`PATH`に`gofmt`がある |
| Rust | `Cargo.toml`のeditionを付けた`rustfmt` | ファイルのフォルダかその上に`Cargo.toml`があり、`PATH`か`~/.cargo/bin`に`rustfmt`がある |

## ログ

スキルとMCPのログは、既定では何も書きません。
`AGENT_NOTICES_SKILL_LOG=on`にするとスキルの呼び出しごとに1行を`~/.local/share/agent-notices/skill-calls.jsonl`に、`AGENT_NOTICES_MCP_LOG=on`にするとMCPの呼び出しごとに1行を`~/.local/share/agent-notices/mcp-calls.jsonl`に足します。

```
{"v":1,"skill":"pdf","start":"2026-11-24T06:12:03.418Z","end":"2026-11-24T06:12:09.902Z","duration_ms":6484,"ok":true}
{"v":1,"server":"files","tool":"read_file","start":"2026-11-24T06:13:40.010Z","end":"2026-11-24T06:13:40.152Z","duration_ms":142,"ok":false}
```

1行は、スキルの名前かMCPのサーバーと道具の名前、UTCの始めと終わりの時刻、かかった時間、呼び出しが成功したかを持ちます。
呼び出しの引数と結果は、あなたの文や鍵を含むことがあるので、持ちません。
ファイルはあなただけが読め、1 MBを超えたファイルは次の行の前に`.1`へ移します。
`XDG_DATA_HOME`を設定していると、ファイルは`$XDG_DATA_HOME/agent-notices/`に置きます。

## 必要な物

| 必要な物 | 使う所 |
|---|---|
| Python 3 | 全てのフック。無いと、フックは何もしません |
| `bash` | フックの起動 |
| `git` | branchのフックと、env-exampleとformatでリポジトリの一番上を探す所 |

## 読む物と動かす物と送る物

- Claude CodeやCodexがシェルの命令、編集、Grep、スキルの呼び出し、MCPの呼び出しの後に送る出来事、編集で変わったファイル、リポジトリの一番上の`.env.example`のファイル、整形の道具を名指すプロジェクトの設定、何も見つからなかったGrepの後は探した所の下のファイルを読みます
- 命令が名指すリポジトリで`git`を動かし、編集したファイルにプロジェクトの整形の道具を動かします
- 会話ごとに最後に切り替えたブランチと、ログがオンの間は呼び出しの始めの時刻を、あなただけが読める`~/.local/share/agent-notices/`に残し、7日より古いブランチの記録は消します
- どこにも何も送らず、モデルも呼びません
- フックを持つプラグインはOpenAIのプラグインの公式ディレクトリに載せられないので、載せていません。このマーケットプレイスから入れます

securityのフックの注意は、Anthropicの`security-guidance`プラグインの`hooks/lib/security_guidance/patterns.py`から来ます。
Apache License 2.0のもとで手を加えずに写し、出典は[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)にあります。
各フックが従う決まりは[仕組み](docs/how-it-works.ja.md)にあります。

## ライセンス

MIT。ただし`hooks/lib/security_guidance/`はApache License 2.0です
