# 用語集

このrepoが1つの意味で使う語。

| 語 | 意味 |
|---|---|
| `agent-shared` | `agent-shared/`に在る命令。1つ以上の置き場のスキルと決まりとhookを、agentの表の全てのagentに置く |
| 置き場 | `.shared`の形を持つフォルダ。`skills/<name>/SKILL.md`、`rules/*.md`、`hooks.json`と、任意の`agents.json`を持つ |
| `~/.shared` | そのコンピューターの全てのagentに向けた、本人のスキルと決まりとhookを持つ置き場 |
| repoの`.shared` | repoの根に在る置き場。そのスキルは、そのrepoの`.claude/skills`と`.agents/skills`へ繋がれる |
| agentの表 | 各agentの名前と、スキルと決まりとhookの置き場を挙げる行。命令の既定の`agents.json`と、`~/.shared/agents.json`の行から成る |
| plugin | `plugins/`の下のフォルダで、agentのpluginの命令で入れる。pluginは`agent-shared`と別の物である |
| 書式のスキル | ほかのスキルが従う文書の書式を持つスキル。`doc-formats`のpluginの`design-doc`がこれに当たる。自分では何も書かない |
| 出す側のスキル | musubiでほかのスキルに中身を出すスキル。`musubi.json`の`provides`に書く |
| 使う側のスキル | ほかのスキルが出す中身に従うスキル。`musubi.json`の`follows`に書き、そのスキルを名前で開いて読む |
