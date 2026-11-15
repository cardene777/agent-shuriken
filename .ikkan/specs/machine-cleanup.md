# machine-cleanup

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 走査は、作り直されるcacheをパッケージ管理 (npm、pnpm、Yarn、Bun、pip、uv、Homebrew、Cargo、Go、Gradle、Maven、CocoaPods)、Docker、Xcode、アプリのcacheの種類ごとに、id、種類、大きさ、作り直されるかを持つJSONの項目として返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan lists each kind of rebuilt cache with id, kind, size, and rebuilt"`が通る | #141 |
| 走査は、gitの管理下のプロジェクトで無視の指定に当たる`node_modules`とビルドの出力のフォルダを返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan lists ignored build output in a git project"`が通る | #141 |
| 走査は、gitが追跡するファイルを1つでも含むビルドの出力のフォルダを返さない | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan never lists a build folder that holds a tracked file"`が通る | #141 |
| 走査は、ゴミ箱の中身、30日より古いログとクラッシュの記録、ダウンロードの30日より古いインストーラーを返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan lists trash, old logs, and old installers"`が通る | #141 |
| 走査は、500MB以上のファイルと、10MB以上で中身が同じファイルの組を返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan lists large files and duplicate sets"`が通る | #141 |
| 走査は、macOSでは利用者が書き換えられるアプリを最後に開いた日と付属のファイルとともに返し、Linuxでは利用者の範囲で入れたflatpakを返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan lists apps with their last-used date and support files"`が通る | #141 |
| 走査は、同期フォルダ (`~/Library/Mobile Documents`、`~/Library/CloudStorage`、`~/Dropbox`) とWSLの`/mnt`の下の物を返さない | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan never enters sync folders or Windows drives"`が通る | #141 |
| 走査は、シンボリックリンクの先の物を返さない | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan does not follow symbolic links"`が通る | #141 |
| 走査は、時間の上限に達すると止まり、測らなかった場所を結果に返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan stops at its time limit and lists what it skipped"`が通る | #141 |
| 走査は、大きさを測る命令を優先度19で回す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan measures sizes at the lowest priority"`が通る | #141 |
| 走査は、終わった会話から残った開発用のプロセス、メモリかCPUを多く使うプロセス、ログイン時に起動する項目、動いているDockerのコンテナを返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan lists leftover dev processes, heavy processes, login items, and running containers"`が通る | #141 |
| 親をたどって動いているエージェントの会話 (`claude`、`codex`、`copilot`、`gemini`) か開いている端末に着くプロセスは、理由を添えた選べない項目として返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"a process under a live agent session or terminal is locked with a reason"`が通る | #141 |
| 動いているプロセスが作業場所にしているプロジェクトのフォルダの中の項目は、理由を添えた選べない項目として返す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"build output in a folder a running process works in is locked"`が通る | #141 |
| 走査の結果は`MACHINE_CLEANUP_HOME`の下に、フォルダは700、ファイルは600の権限で置く | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"scan state is readable only by the user"`が通る | #141 |
| ページは英語で開き、ヘッダーの切り替えで日本語に変わり、画面の文言を1つの辞書に持つ | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"the sheet opens in English and switches to Japanese from one dictionary"`が通る | #141 |
| 待つ命令は127.0.0.1だけで聞き、一回限りの合言葉を持つ選択を受け取ると、選んだidを出して終わる | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"serve returns the picked ids after one request with the token"`が通る | #141 |
| 待つ命令は、合言葉の無い要求と別のOriginからの要求を拒み、選択として受け取らない | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"serve refuses a request without the token or from another origin"`が通る | #141 |
| 写すボタンが写す文はページの言語に依らず同じで、適用の命令がそのまま読める | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"the copied selection is the same in both languages and apply reads it"`が通る | #141 |
| 適用は、渡したidだけを消すか止める | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"apply acts only on the passed ids"`が通る | #141 |
| 適用は、走査に無いidと選べない項目のidを拒む | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"apply refuses unknown and locked ids"`が通る | #141 |
| 適用は、走査の後に大きさか中身か使用中かが変わった項目を、理由を添えて飛ばす | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"apply skips an item that changed after the scan"`が通る | #141 |
| 適用は、道具が自分の消す命令を持つcacheにはその命令を使う | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"apply uses the tool's own clean command when it has one"`が通る | #141 |
| 適用は、大きいファイルと重複とアプリを消さずにゴミ箱へ移し、Linuxでは元の場所へ戻せる記録 (`.trashinfo`) を残す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"apply moves files and apps to the trash with restore info"`が通る | #141 |
| 適用は、プロセスに終了の合図 (SIGTERM) を送り、残ったプロセスを報告する | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"apply sends SIGTERM and reports the survivors"`が通る | #141 |
| 適用は、残ったと報告したプロセスを利用者がもう一度選んだ時だけ強制の終了 (SIGKILL) を送り、最初の回には送らない | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"apply sends SIGKILL only to survivors picked again"`が通る | #141 |
| 適用は、PIDが走査の時と別のプロセス (開始時刻か命令が違う) を指す時、合図を送らない | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"apply never signals a reused pid"`が通る | #141 |
| ログイン時の起動項目を止めた後、戻す命令で元のとおり有効に戻せる | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"a stopped login item can be restored"`が通る | #141 |
| 報告は、dfで測った空きとメモリと負荷の前後を実測で出し、Docker Desktopの仮想ディスクが縮まない時はその旨を出す | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"the report shows measured free space, memory, and load before and after"`が通る | #141 |
| pluginのテストが走査と適用に渡すpathは、全て使い捨ての`HOME`の下にある | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"every path the tests touch is under the throwaway HOME"`が通る | #141 |
| pluginのscriptは、127.0.0.1の待つ命令の他に、外への接続を開く処理を持たない | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"no script connects outside the machine"`が通る | #141 |
| marketplaceは`machine-cleanup`の項目を持ち、repo直下の`README.md`と`README.ja.md`の一覧が`machine-cleanup`の行を持つ | `bash plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh`の検査`"the marketplace and the root READMEs list machine-cleanup"`が通る | #141 |
| repoの検査が全部通る | `bash scripts/check.sh`が終了0 | #141 |
