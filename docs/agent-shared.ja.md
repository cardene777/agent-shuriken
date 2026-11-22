# agent-shared

[English](agent-shared.md) · 日本語

`agent-shared`は、1つのフォルダーに置いたスキルとルールとhookを、PCの全てのコーディングエージェントへ配ります。
スキルとルールはそのフォルダーの1つの実体を指すリンクなので、直すと全てのエージェントに一度に届きます。
フォルダーはPCの中に残り、コマンドはネットワークに何も送りません。

## インストール

コマンドには[uv](https://docs.astral.sh/uv/)が要り、macOSとLinuxで動きます。
uvが入れるのはコマンドだけで、このリポジトリのプラグインは入りません。PCにPython 3.11以上が無い時はuvが用意します。

```
uv tool install "git+https://github.com/cardene777/agent-shuriken#subdirectory=agent-shared"
uv tool upgrade agent-shared
```

2行目は、後でコマンドをアップデートする時に打ちます。

## 配る元のフォルダー

スキルとルールとhookを`~/.shared`に置きます。

```
~/.shared/
  skills/<name>/SKILL.md   スキルごとに1つのフォルダー
  rules/*.md               全てのエージェントが読む指示
  hooks.json               hook。Claude Codeの設定のhooksと同じ形で書く
  agents.json              エージェントを足すか、置き場を変える行 (無くてもよい)
```

`hooks.json`は、Claude Codeの設定の`hooks`と同じ中身を持ちます。
命令の中の`${CLAUDE_PLUGIN_ROOT}`は配る元のフォルダーのpathに置き換わり、`tools`を書いたhookはその名前のエージェントだけに配ります。

```json
{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh", "tools": ["Claude Code"]}]}]}}
```

置いたら、コマンドを打ちます。

```
agent-shared deploy
```

## 置き場

| エージェント | スキル | ルール | hook | リポジトリのスキル |
|---|---|---|---|---|
| Claude Code | `~/.claude/skills`にスキルごとのリンク | `~/.claude/rules`にルールごとのリンク | `~/.claude/settings.json` | `.claude/skills` |
| Codex | `~/.agents/skills`にスキルごとのリンク | `~/.codex/AGENTS.md`の中の1つの囲み | `~/.codex/hooks.json` | `.agents/skills` |

GitHub Copilot CLIとGemini CLIも、`~/.agents/skills`のスキルを読みます。
Codexは古い置き場の`~/.codex/skills`も読み続けているため、コマンドはそこに何も置かず、同じスキルが2回並ばないようにします。
Codexは信頼したhookだけを動かすので、コマンドはCodexの`/hooks`の画面と同じやり方で、`codex app-server`を通して信頼の印を書きます。
`codex`のコマンドが無い時と答えない時は、そのことを出し、Codexで`/hooks`を1度開くよう案内します。

## リポジトリのスキル

リポジトリは、自分のスキルを`.shared/skills`に置けます。
リポジトリの中か`--repo <folder>`を付けて`agent-shared deploy`を打つと、そのリポジトリの`.claude/skills`と`.agents/skills`に相対のリンクを置くので、どのクローンでもリンクが働きます。
リポジトリのルールは`AGENTS.md`に置いたままにし、`CLAUDE.md`から`@AGENTS.md`の1行で読ませます。

## エージェントの表

コマンドは、各エージェントの置き場を並べた表を持っています。
`~/.shared/agents.json`に新しい名前の行を書くとエージェントが増え、既定の行と同じ名前の行を書くとその行を置き換えます。

```json
{"version": 1, "agents": [{"name": "My agent", "skills": "~/.my-agent/skills"}]}
```

| 欄 | 中身 |
|---|---|
| `name` | エージェントの名前。`hooks.json`の`tools`もこの名前を書く |
| `skills` | スキルごとのリンクを置くフォルダー |
| `repo_skills` | リポジトリの中で、そのリポジトリのスキルのリンクを置くフォルダー |
| `rules` | `place`と`form`。`link`は`place`のフォルダーにルールごとのリンクを置き、`block`は`place`のファイルの1つの囲みにルールを書く |
| `hooks` | `file`にhookを書く。`trust: codex-app-server`を書くと、Codexの信頼の印も書く |
| `plugins` | `claude`か`codex`。そのエージェントに入れたプラグインが既に持つスキルは、そのエージェントへ配らない |

## 配る元を増やす

`--source <folder>`で、同じ形のフォルダーを1回の実行に足せます。ikkan-studioのようなアプリが自分のスキルとhookを置くフォルダーがこれに当たります。
配る元は、それぞれ自分が置いた物だけを外すので、全ての配る元を1回の実行で配ります。

```
agent-shared deploy --source ~/apps/my-tool/.shared
```

## プラグインが既に持つスキル

Claude CodeかCodexに入れたプラグインが、フォルダーのスキルと同じ名前のスキルを持つ時は、コマンドはそのエージェントへそのスキルを配らず、スキルとプラグインの名前を出します。
エージェントの一覧には各スキルが1回だけ並び、入れたプラグインはそのまま働きます。

## 読む物と書く物と残す物

| 種類 | 場所 |
|---|---|
| 読む物 | 配る元のフォルダー、`~/.claude/plugins/installed_plugins.json`、`~/.claude/settings.json`の`enabledPlugins`、`~/.codex/config.toml`、`~/.codex/plugins/cache`の下のスキルのフォルダー。`placed`は記録とエージェントの表の置き場だけを読む |
| 書く物 | エージェントの表の置き場。自分が置いた物だけ |
| 残す物 | `~/.local/share/agent-shared/placed.json`。あなただけが読め、置いたリンクを1つずつ記録する。その隣の`off.json`は、`agent-shared off`と`agent-shared on`が書く切った物の一覧。`AGENT_SHARED_STATE`でフォルダーを変えられる |
| 動かす物 | `codex app-server`。置いたhookにCodexの信頼の印を書くため。`AGENT_SHARED_CODEX_BIN`で別の`codex`のコマンドを指せる |
| 送る物 | ネットワークには何も送らない |

## 自分が置いた物の見分け方

| 置いた物 | 印 |
|---|---|
| スキルとルールのリンク | 記録が、リンクごとに指す先を持つ |
| ルールの囲み | 前後の`<!-- agent-shared begin source=<id> -->`と`<!-- agent-shared end source=<id> -->`の行 |
| hook | 命令の最後の行が、shellのコメント`# agent-shared 1 source=<id>` |

`<id>`は、配る元のフォルダーの実際のpathのSHA-256の先頭12桁です。
手で書いたhook、自分で置いたスキル、`AGENTS.md`の囲みの外の行は、byteまで変わりません。

## 置くhookを出す

`agent-shared hooks`は、`deploy`が1つのエージェントのhookの置き場へ足すhookの組を、印と配る元のフォルダーを埋めた形のままJSONで出します。
何も書かないので、設定を弱める変更を止める見張りは、hookを別の作り方で組み立て直さずに、エージェントのhookの置き場とこの出力を比べられます。

```
agent-shared hooks --agent "Claude Code"
agent-shared hooks --agent Codex --source ~/work/team-shared
```

読む元は`deploy`と同じで、`~/.shared`と、`--source`で渡した全てのフォルダーです。
`--agent`にはエージェントの表の名前を渡し、`tools`がそのエージェントを含まないhookは出しません。
表に無い名前と、`--agent`の無い呼び方は、何も出さずに終わり方2で終わります。

## 配る元が置いた物を出す

`agent-shared placed`は、1つの配る元のフォルダーが各エージェントへ置き、今も残っているスキルとルールとhookをJSONで出します。
何も書かないので、ikkan-studioのように自分のフォルダーを配るアプリは、各エージェントの置き場をもう1か所に持たずに、各エージェントへ何が置かれたかを一覧にできます。

```
agent-shared placed --source ~/apps/my-tool/.shared
agent-shared placed --source ~/.shared
```

```json
{
  "source": "/path/to/apps/my-tool/.shared",
  "agents": {
    "Claude Code": {
      "skills": ["review", "release-notes"],
      "rules": ["writing.md"],
      "hooks": [{"event": "PreToolUse", "matcher": "Bash", "command": "bash /path/to/apps/my-tool/.shared/hooks/guard.sh"}]
    },
    "Codex": {
      "skills": ["review", "release-notes"],
      "rules": ["writing.md"],
      "hooks": []
    }
  }
}
```

| 欄 | 意味 |
|---|---|
| `source` | 配る元のフォルダーのフルパス |
| `agents` | エージェントの表の全てのエージェントを表の順に並べ、それぞれが`skills`と`rules`と`hooks`を持つ |
| `skills` | 配る元がそのエージェントへ置き、今も置いた時の先を指すスキルのリンクの名前 |
| `rules` | ルールのリンクのファイル名か、ルールのファイルの中のその配る元の囲みにあるルールのファイル名 |
| `hooks` | その配る元の印を持つhook。`event`と、組が持つ時だけの`matcher`と、印の行を除いた`command`を持つ |
| `left_out` | 切った物の一覧がこの配る元の項目を名指すエージェントにだけ在る。`agent-shared off`に渡した形のままの項目 |

`--source`は1つのフォルダーを名指し、そのフォルダーが置いた物だけを出します。
プラグインが既に持つスキルはそのエージェントへ置いていないので、出しません。
あなたが消したか別の先へ向けたリンクと、印の無いhookも出しません。
1度も配っていないフォルダーには、全てのエージェントを空の配列で出し、終わり方0で終わります。
`--source`の無い呼び方、在らないフォルダー、JSONでない記録か切った物の一覧かhookのファイル、崩れたルールの囲みは、何も出さずに終わり方2で終わります。

## 1つのエージェントでルールかhookを切る

`agent-shared off`は、配る元の1つのルールかhookを1つのエージェントから外し、`agent-shared on`はまた置きます。
どちらも何も置きません。
次の`deploy`が、どの道具から打たれても選んだ状態に従い、前に置いた所からは切った物を外します。

```
agent-shared off --source ~/.shared --agent Codex rules/writing.md
agent-shared off --source ~/.shared --agent Codex hooks/guardrails/stop-guard.sh
agent-shared off --source ~/.shared --agent "Claude Code" "afplay /System/Library/Sounds/Glass.aiff"
agent-shared on --source ~/.shared --agent Codex rules/writing.md
```

| 項目 | 名指す物 |
|---|---|
| `rules/<名前>.md` | 1つのルールのファイル。リンクで置くエージェントにはリンクを置かず、囲みで置くエージェントには囲みに本文を入れない |
| 配る元のフォルダーの下のファイル | そのファイルを実行するhookの命令の全て。`/bin/sh hooks/lib/run.sh bash hooks/x.sh`のように包む命令を通す物も含む。パスの頭だけが同じ命令は残す |
| hookの命令の全体 | 配る元のファイルを実行しないhook。`hooks.json`に書いた形のまま書く |

選んだ状態は、記録の隣の`off.json`に残り、あなただけが読めます。

```json
{"version": 1, "off": [{"source": "/path/to/.shared", "agent": "Codex", "item": "rules/writing.md"}]}
```

1件ずつが配る元のフォルダーを名指すので、別の配る元に在る同じパスの物は置いたままです。
このファイルは`off`と`on`だけで書きます。
`off`は、表に無いエージェントと、配る元に無い項目か外を指すパスを、何も書かずに終わり方2で断ります。
`on`は、合う1件を外し、合う物が無ければ何も変えません。
`deploy`と`hooks`と`placed`は打つたびに一覧を読み、`off.json`を読めない時は何も書かずに終わり方2で終わり、そのファイルを名指します。
`off.json`が無い時は、どのコマンドも一覧が無かった頃と同じに置いて出します。

## 断る時

コマンドは先に変更の全体を確かめ、何かが邪魔をする時は何も書かず、理由を1つずつ出して終わり方1で終わります。

| 理由 | 直し方 |
|---|---|
| 同じ名前のスキルかルールが2つの配る元に在る | どちらかの名前を変える |
| 置き場に、コマンドが置いていない物が在る | その物を移すか、スキルかルールの名前を変える |
| 置き場が別の配る元から置かれている | 2つの配る元を1回の実行で配る |
| 手で書いたhookが、宣言のhookと同じ命令を持つ | どちらかを外す |
| エージェントの設定のファイルがJSONでない | ファイルを直す |
| ファイルの中のルールの囲みが崩れている | 印の行を手で外す |
| ルールが印と同じ形で始まる行を持つ | その行を変える |

終わり方0は配り終えたこと、2はコマンドの引数か配る元のフォルダーか表か記録か切った物の一覧を使えなかったことを表します。
