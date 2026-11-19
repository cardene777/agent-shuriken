# agent-shared

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| `agent-shared/`のfolderを一時のtoolの置き場へ`uv tool install`で入れた時、`agent-shared`のコマンドが入り、入った物は`plugins/`の下のfileを1つも含まない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"uv tool install puts agent-shared on PATH without any plugin"`が通る | #250 |
| 一時の`HOME`で`agent-shared deploy`を打った時、`~/.shared/skills/`の各skillが`~/.claude/skills/<名前>`と`~/.agents/skills/<名前>`のlinkになり、どちらのlinkも`~/.shared/skills/<名前>`を指す | `bash agent-shared/tests/test-agent-shared.sh`の検査`"deploy links every skill into the Claude Code and shared agent folders"`が通る | #250 |
| `agent-shared deploy`は、Codexが廃止予定とする`~/.codex/skills`に何も置かない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"deploy places nothing in the deprecated Codex skills folder"`が通る | #250 |
| `agent-shared deploy`を打った時、`~/.shared/rules/*.md`が`~/.claude/rules/`のlinkになり、`~/.codex/AGENTS.md`の印の行で挟んだ1つの囲みに本文が入り、囲みの外の行は打つ前とbyteが同じ | `bash agent-shared/tests/test-agent-shared.sh`の検査`"deploy writes rules as links for Claude Code and one block for Codex"`が通る | #250 |
| `agent-shared deploy`を打った時、`~/.shared/hooks.json`のhookが印付きで`~/.claude/settings.json`と`~/.codex/hooks.json`に入り、`settings.json`のhooks以外の欄は値が変わらない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"deploy adds marked hooks and keeps the other settings"`が通る | #250 |
| 見本の`codex app-server`が在る時、`agent-shared deploy`は置いたhookの分だけCodexの`hooks.state`へ信頼の印を書く | `bash agent-shared/tests/test-agent-shared.sh`の検査`"deploy writes Codex trust for the hooks it placed"`が通る | #250 |
| `codex`のコマンドが無い時、`agent-shared deploy`はCodexの`/hooks`の画面で信頼する手順を出し、ほかのagentへの配りを終えて終わり方0で終わる | `bash agent-shared/tests/test-agent-shared.sh`の検査`"without codex the run prints how to trust hooks in Codex"`が通る | #250 |
| `.shared/skills/`を持つrepoで`agent-shared deploy`を打った時、そのrepoのskillがそのrepoの`.claude/skills/`と`.agents/skills/`のlinkになる | `bash agent-shared/tests/test-agent-shared.sh`の検査`"deploy in a repository links its skills into its own folders"`が通る | #250 |
| 配る元からskillとrulesとhookを1つずつ外して打ち直した時、外した物だけがagentの置き場から消え、残りは打つ前と同じ | `bash agent-shared/tests/test-agent-shared.sh`の検査`"a removed skill, rule, or hook is taken out on the next run"`が通る | #250 |
| `agent-shared deploy`は、印の無いhookとskillのfolderと`AGENTS.md`の囲みの外の行を変えない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"entries without the mark are left unchanged"`が通る | #250 |
| agentに入っているpluginが同じ名前のskillを持つ時、`agent-shared deploy`はそのagentの置き場へそのskillを置かず、skillの名前とpluginの名前を出す | `bash agent-shared/tests/test-agent-shared.sh`の検査`"a skill an installed plugin already has is not placed for that agent"`が通る | #250 |
| 2つの配る元が同じ名前のskillを持つ時、`agent-shared deploy`は何も置かずに2つの配る元を出し、終わり方1で終わる | `bash agent-shared/tests/test-agent-shared.sh`の検査`"two sources with the same skill name are refused"`が通る | #250 |
| 印の無いhookが宣言のhookと同じ命令を持つ時、`agent-shared deploy`はそのagentのhookのfileを変えずに終わり方1で終わる | `bash agent-shared/tests/test-agent-shared.sh`の検査`"a hand-written hook with a declared command is refused"`が通る | #250 |
| 既定の表はJSONで同梱され、`~/.shared/`の表のfileに3つ目のagentの行を足すと、codeを変えずにそのagentの置き場へskillが置かれる | `bash agent-shared/tests/test-agent-shared.sh`の検査`"a row in the user's table adds an agent"`が通る | #250 |
| 置いた物の記録は`~/.local/share/agent-shared/`の下 (環境変数で替えられる) に在り、本人だけが読める権限を持つ | `bash agent-shared/tests/test-agent-shared.sh`の検査`"the record of placed items is kept readable only by the user"`が通る | #250 |
| `README.md`と`README.ja.md`は、`agent-shared`の節をpluginの一覧の節より前に置く | `bash agent-shared/tests/test-agent-shared.sh`の検査`"the READMEs put agent-shared before the plugins"`が通る | #250 |
| `docs/getting-started.md`と`docs/getting-started.ja.md`は、Codexのskillの置き場を`~/.agents/skills`と書き、`~/.codex/skills`を書かない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"getting started no longer points Codex at its deprecated skills folder"`が通る | #250 |
| repoの検査が全て通る | `bash scripts/check.sh`が終了0 | #250 #258 |
| `agent-shared hooks --agent "Claude Code"`が出すJSONの`hooks`の欄は、同じ元で`agent-shared deploy`が`~/.claude/settings.json`へ足した印付きのhookの組と一致する | `bash agent-shared/tests/test-agent-shared.sh`の検査`"hooks prints the groups deploy adds for an agent"`が通る | #256 |
| `agent-shared hooks --agent Codex`は、宣言の`tools`がCodexを名指さないhookを出さない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"hooks leaves out a hook whose tools name another agent"`が通る | #256 |
| `agent-shared hooks`は、`--source`で渡したfolderの宣言のhookも出す | `bash agent-shared/tests/test-agent-shared.sh`の検査`"hooks includes the hooks of every source"`が通る | #256 |
| `agent-shared hooks`は終わり方0で終え、打った後のホームと記録の置き場のfileの中身が打つ前と同じ | `bash agent-shared/tests/test-agent-shared.sh`の検査`"hooks writes nothing"`が通る | #256 |
| agentの表に無い名前を`--agent`に渡すと、`agent-shared hooks`は標準出力に何も出さず、その名前を名指して終わり方2で断る | `bash agent-shared/tests/test-agent-shared.sh`の検査`"hooks refuses an agent the table does not have"`が通る | #256 |
| `--agent`を渡さないと、`agent-shared hooks`は`--agent`を名指して終わり方2で断る | `bash agent-shared/tests/test-agent-shared.sh`の検査`"hooks refuses a call without --agent"`が通る | #256 |
| `agent-shared deploy`は今どおり印付きのhookを足し、ほかの設定を変えない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"deploy adds marked hooks and keeps the other settings"`が通る | #256 |
| `agent-shared deploy --source <folder>`の後に`agent-shared placed --source <folder>`を打つと、`agents`の`Claude Code`と`Codex`の欄に、その元が置いた技の名前とruleの名前とhookを返す。CodexのruleはAGENTS.mdの塊から読む | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed lists what a source placed for each agent"`が通る | #258 |
| `agent-shared placed`が返すhookは、`event`と、組が持つ時だけの`matcher`と、印の行を除いた`command`を持つ | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed prints each hook without the mark"`が通る | #258 |
| `agent-shared placed --source <folder>`は、`~/.shared`のように別の元が置いた技とruleとhookを返さない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed leaves out what another source placed"`が通る | #258 |
| agentに入っているpluginが同じ名前の技を持つために置かなかった技を、`agent-shared placed`はそのagentの欄に返さず、置いた別のagentの欄には返す | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed leaves out a skill a plugin already has"`が通る | #258 |
| 配った後に本人が消したlinkと、印の無いhookと、本人が置いた技のfolderを、`agent-shared placed`は返さない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed counts only what still carries the mark"`が通る | #258 |
| `agent-shared placed`は終わり方0で終え、打った後のホームと記録の置き場のfileの中身が打つ前と同じ | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed writes nothing"`が通る | #258 |
| 1度も配っていない元を渡すと、`agent-shared placed`はagentの表の全てのagentを表の順に、技とrulesとhookを空の配列にして返し、終わり方0で終わる | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed prints empty lists for a source never deployed"`が通る | #258 |
| agentのhookのfileがJSONで読めない時、`agent-shared placed`は標準出力に何も出さず、そのfileを名指して終わり方2で断る | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed refuses a hook file it cannot read"`が通る | #258 |
| rulesの塊の印の行が壊れている時、`agent-shared placed`は標準出力に何も出さず、そのfileを名指して終わり方2で断る | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed refuses a broken rules block"`が通る | #258 |
| `--source`を渡さない呼び方と、在らないfolderを渡す呼び方を、`agent-shared placed`は標準出力に何も出さず、`--source`かそのfolderを名指して終わり方2で断る | `bash agent-shared/tests/test-agent-shared.sh`の検査`"placed refuses a call without an existing source"`が通る | #258 |
| `agent-shared deploy`は今どおり技とruleのlinkを置き、Codexのrulesを1つの塊に書く | `bash agent-shared/tests/test-agent-shared.sh`の検査`"deploy writes rules as links for Claude Code and one block for Codex"`が通る | #258 |
| `agent-shared deploy`は今どおり、pluginが同じ名前の技を持つagentへその技を置かない | `bash agent-shared/tests/test-agent-shared.sh`の検査`"a skill an installed plugin already has is not placed for that agent"`が通る | #258 |
| `agent-shared hooks`は今どおり、`deploy`が足すhookの組を返す | `bash agent-shared/tests/test-agent-shared.sh`の検査`"hooks prints the groups deploy adds for an agent"`が通る | #258 |
