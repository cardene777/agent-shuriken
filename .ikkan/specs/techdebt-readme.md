# techdebt-readme

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 見本を作るscriptが、空のフォルダに日付を固定したcommitとTODOと重複を持つ`shop`のリポジトリを作れる | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the sample script builds the shop repository with dated commits"`が通る | #294 |
| READMEと日本語のREADMEの要約の見本が、見本のリポジトリを1回走査した出力の先頭の行と、HEADの短いhashを除いて1行ずつ一致し、順位が20位まで続くと書く文も走査と合う | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the README summaries match one scan of the sample repository"`が通る | #294 |
| READMEの要約の見本の1行が走査と違う時、比べる命令はその行を名指して終了1を返し、ずれたREADMEを通さない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the README check names a summary line that differs from the scan"`が通る | #294 |
| READMEと日本語のREADMEの画像の説明文が、一覧の横に1位のファイルの項目とエージェントの注記を出した今のレポートを書き、画像は見本の走査から作ったレポートをその行を開いて写した物になる | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the README screenshot alt text describes the list with the top file's details beside it"`が通る | #294 |
| 見本から作ったレポートのページは、コミットの名前とメールアドレスとほかのメールアドレスを持たず、手元のpathは画面に書かないデータの`root`の欄だけが持ち、テンプレートはその欄を画面に書かない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the sample report shows no local path and holds no name or email address"`が通る | #294 |
| READMEと`docs/how-it-works.md`の英語と日本語は、5個のタブと、URLに残る開いた行と、ツールの札を書いたままになる | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the changelog, README, and how-it-works describe the tabs, the link to an open row, and the tool tags"`が通る | #294 |
