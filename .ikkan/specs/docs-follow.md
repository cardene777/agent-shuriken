# docs-follow

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 計画のJSONが`follow`の欄に倣うプロジェクト(名前、`https://`のURL、採った形)を持つ時、`scaffold --dry-run`はそれを表示し、`scaffold`は翻訳の対応表の`follow`に同じ中身を書く | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"a plan with projects to follow is shown and kept in the map"`が通る | #73 |
| 計画のJSONに`follow`が無い時、`scaffold`は対応表に空の`follow`を書き、今どおり全部の頁を書く | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"a plan without projects to follow keeps an empty list"`と`"scaffold writes every page in every language"`が通る | #73 |
| `follow`の項目に名前が無い、URLが`https://`で始まらない、採った形が無いか1行200文字を超える時、`scaffold`は終了コード2で断り、項目の番号と直し方をほかの問題と一緒に挙げ、何も書かない | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"a plan with a bad project to follow is refused and names the entry"`が通る | #73 |
| 対応表の形式の版は2で、言語は元の言語が先に並ぶ | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"the map has version 2 and the source language first"`が通る | #73 |
| 仕上がった頁の組で、対応表が`follow`を持つ時も持たない時も、`check`は`No problems.`を出して終了コード0で終わる | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"check passes with and without projects to follow"`が通る | #73 |
| 対応表が`follow`を持つ時、`check`は倣ったプロジェクトの名前を出す | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"check names the projects the docs follow"`が通る | #73 |
| `add`、`drop`、`translated`が対応表を書き直しても、`follow`は消えない | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"add, drop, and translated keep the projects to follow"`が通る | #73 |
| 版1の対応表は倣うプロジェクトの無い物として読め、`check`は通り、次に書き直す時は版2で書く | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"a version 1 map is read as following no project and written as version 2"`が通る | #73 |
| 版3の対応表と、`follow`の項目の形が崩れた対応表は、終了コード2で断る | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"a map of version 3 exits 2"`と`"a map with a bad project to follow exits 2"`が通る | #73 |
| `SKILL.md`は、本人がプロジェクトを名指して読むことに同意した時だけ回るstepを持ち、GitHubのrepoを`gh api`で、ほかのサイトをwebを読む道具で、目次と5頁まで読むと書き、道具が無い時は飛ばして本人に伝えると書く | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"SKILL.md reads the projects to follow only when the user names them and agrees"`が通る | #73 |
| `SKILL.md`は、倣った文書の文を写さないと書く | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"SKILL.md says not to copy text from the docs it follows"`が通る | #73 |
| `README.md`と`README.ja.md`は、ほかのプロジェクトの文書を本人の同意がある時だけ読むと書く | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"the READMEs say the docs of other projects are read only with the user's agreement"`が通る | #73 |
| 今どおり、悪い計画は終了コード2で何も書かず、問題を一度に全部挙げる | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"a bad plan exits 2 and writes nothing"`と`"every problem in the plan is listed at once"`が通る | #73 |
| 今どおり、`check`はfileを1つも変えない | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"check changes no file"`が通る | #73 |
| 今どおり、対応表は頁を読む順に並べる | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"the map lists the pages in reading order"`が通る | #73 |
