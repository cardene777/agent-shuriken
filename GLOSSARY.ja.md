# 用語集

このrepoが1つの意味で使う語。

| 語 | 意味 |
|---|---|
| `agent-shared` | `agent-shared/`に在る命令。1つ以上の置き場のスキルと決まりとhookを、agentの表の全てのagentに置く |
| 置き場 | `.shared`の形を持つフォルダ。`skills/<name>/SKILL.md`、`rules/*.md`、`hooks.json`と、任意の`agents.json`を持つ |
| `~/.shared` | そのコンピューターの全てのagentに向けた、本人のスキルと決まりとhookを持つ置き場 |
| 切った物の一覧 | 記録の隣の`off.json`。`deploy`が1つのagentに置かない、置き場の決まりとhook。`agent-shared off`と`agent-shared on`だけが書く |
| repoの`.shared` | repoの根に在る置き場。そのスキルは、そのrepoの`.claude/skills`と`.agents/skills`へ繋がれる |
| agentの表 | 各agentの名前と、スキルと決まりとhookの置き場を挙げる行。命令の既定の`agents.json`と、`~/.shared/agents.json`の行から成る |
| plugin | `plugins/`の下のフォルダで、agentのpluginの命令で入れる。pluginは`agent-shared`と別の物である |
| 書式のスキル | ほかのスキルが従う文書の書式を持つスキル。`doc-formats`のpluginの`design-doc`がこれに当たる。自分では何も書かない |
| 出す側のスキル | musubiでほかのスキルに中身を出すスキル。`musubi.json`の`provides`に書く |
| 使う側のスキル | ほかのスキルが出す中身に従うスキル。`musubi.json`の`follows`に書き、そのスキルを名前で開いて読む |
| 流れ | プロジェクトの`.screen-video/flows/`に置くJSONのファイル。`screen-video`のpluginが撮る1本の動画の操作の順と字幕を持つ |
| 通し | `screen-video`のpluginが流れを録画せずに行うこと。送信か支払いを起こす最初の操作の手前で止まる |
| 台本 | 通しが書く頁`storyboard.html`。操作ごとの画と、操作の内容と、字幕を並べる |
| テーマ | `screen-video`のpluginが作る編集済みの動画の見た目を決める、色と字体と角の丸みのJSONのファイル。pluginの`themes/`に同梱した物と、プロジェクトの`.screen-video/themes/`に置く物がある |
