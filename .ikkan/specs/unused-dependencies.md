# unused-dependencies

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| knipの無い見本のrepoで、`scan`は使っていない`unused-lib`と`unused-dev`と`@types/unused-lib`だけを、`package.json`の場所と`dependencies`か`devDependencies`の別と一緒に挙げ、名前で探した結果と書く | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"unused dependencies are listed by name search and marked approximate"`が通る | #65 |
| import、require、動的なimport、`lodash/fp`のような下の階層の読み込みで使う依存は挙げない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a dependency used by import, require, dynamic import, or a subpath is not listed"`が通る | #65 |
| `scripts`の命令だけで使う依存は、`typescript`を`tsc`と書くように`bin`の名前で使う物も挙げない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a dependency used only by a scripts entry is not listed, also through its bin name"`が通る | #65 |
| `vite.config.ts`のような設定のファイルだけで使う依存は挙げない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a dependency used only in a config file is not listed"`が通る | #65 |
| `<名前>`を使っている間は`@types/<名前>`を挙げない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"@types/<name> is not listed while <name> is used"`が通る | #65 |
| 使っている依存が`peerDependencies`で求める依存と、設定に短い名前で書かれた差し込み(`eslint-plugin-react`を`react`と書く形)は挙げない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a peer dependency of a used package and a plugin named by its short name are not listed"`が通る | #65 |
| knipが動いた時は、knipが挙げた依存を数え、名前での探索は回さず、同じ依存を2度挙げない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"when knip ran, its dependency findings are used and none is listed twice"`が通る | #65 |
| 要約に`Unused deps:`の行があり、数と、名前で探した概算かknipの結果かを示す | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the summary shows the unused dependencies and how they were found"`が通る | #65 |
| 報告に、英語と日本語の見出しを持つ「使っていない依存」の欄がある | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the report has a tab for unused dependencies"`が通る | #65 |
| `package.json`の無いフォルダーでは、使っていない依存を測らず、要約にその行を出さない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a folder without package.json has no unused dependencies measure"`が通る | #65 |
| `scan.json`の形式の版は使っていない依存の欄を足した2より後(今は3)で、`report`と`explain`は版1の`scan.json`を終了コード2で断り、`scan`のやり直しを求める | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"scan.json has schema 3"`と`"report refuses a scan.json of schema 1 and asks to scan again"`が通る | #65 |
| `SKILL.md`と`docs/how-it-works.md`と`docs/how-it-works.ja.md`と`README.md`と`README.ja.md`が、使っていない依存の測り方を概算と書く | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the docs call the unused dependencies approximate"`が通る | #65 |
| `scan`はパッケージの管理の命令(`npm`、`npx`、`pnpm`、`yarn`、`bunx`)を動かさず、ネットにつながない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the scan runs no package manager"`が通る | #65 |
| knipが入っている時は今どおりknipを動かし、その結果を道具の欄に残す | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"installed knip ran"`が通る | #65 |
| `scan`は今どおり標準エラーに何も書かない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the scan wrote nothing to standard error"`が通る | #65 |
