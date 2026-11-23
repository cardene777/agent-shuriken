# 用語集

このrepoが1つの意味で使う語。

| 語 | 意味 |
|---|---|
| plugin | `plugins/`の下のフォルダで、agentのpluginの命令で入れる |
| 書式のスキル | ほかのスキルが従う文書の書式を持つスキル。`doc-formats`のpluginの`design-doc`がこれに当たる。自分では何も書かない |
| 出す側のスキル | musubiでほかのスキルに中身を出すスキル。`musubi.json`の`provides`に書く |
| 使う側のスキル | ほかのスキルが出す中身に従うスキル。`musubi.json`の`follows`に書き、そのスキルを名前で開いて読む |
| 流れ | プロジェクトの`.screen-video/flows/`に置くJSONのファイル。`screen-video`のpluginが撮る1本の動画の操作の順と字幕を持つ |
| 通し | `screen-video`のpluginが流れを録画せずに行うこと。送信か支払いを起こす最初の操作の手前で止まる |
| 台本 | 通しが書く頁`storyboard.html`。操作ごとの画と、操作の内容と、字幕を並べる |
| テーマ | `screen-video`のpluginが作る編集済みの動画の見た目を決める、色と字体と角の丸みのJSONのファイル。pluginの`themes/`に同梱した物と、プロジェクトの`.screen-video/themes/`に置く物がある |
| 管理者の行 | `machine-cleanup`のpluginで、片付けに管理者の権限が要る行。システムのキャッシュ、システムのログ、rootが入れたアプリ、システムのlaunch daemonかsystemdのunitがこれに当たる。本人が`sudo`で承認した後にだけ片付ける |
