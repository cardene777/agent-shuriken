# report-author

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| テンプレートが表紙の日付の下に作者の行`<p class="cover-author">{{AUTHOR}}</p>`を持ち、行が空の時はCSSの`:empty`で隠す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the template has the author line under the date and hides it when empty"`が通る | #62 |
| 全てのプレースホルダーを埋めたテンプレートに、`check-report.py`は作者名を入れた時も空にした時も`ok`を出す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the filled template with an author prints ok"`と`"the filled template with an empty author prints ok"`が通る | #62 |
| 作者の行に空白だけを入れた報告書を、`check-report.py`は咎めて終了コード1で終わる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"a blank author line is reported"`が通る | #62 |
| 埋めていないテンプレートに、`check-report.py`は残った`{{AUTHOR}}`を挙げる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the unfilled template names {{AUTHOR}}"`が通る | #62 |
| `author.sh`は、保存が無い時に`not saved`、名前を保存した時に`name: <名前>`、載せないと保存した時に`no name`を出し、`--forget`で保存を消す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"author.sh prints not saved before the first answer"`と`"author.sh --set saves the name"`と`"author.sh --set with an empty name saves no name"`と`"author.sh --forget removes the saved answer"`が通る | #62 |
| 保存したファイルは`~/.local/share/compare-report/author.txt`(`COMPARE_REPORT_HOME`が在ればその下)に在り、本人だけが読める | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the author file is readable only by the user"`と`"author.sh follows COMPARE_REPORT_HOME"`が通る | #62 |
| `author.sh`は改行を含む名前と100文字を超える名前を終了コード2で断り、保存を変えない | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"author.sh rejects a name with a line break"`と`"author.sh rejects a name over 100 characters"`が通る | #62 |
| `git config`に`user.name`が在っても、保存が無い時の`author.sh`は`not saved`を出す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"author.sh does not fall back to git config user.name"`が通る | #62 |
| `SKILL.md`が、作者名を候補の問いと一緒に聞くこと、`author.sh`で読み出しと保存をすること、`git config`やシステムから名前を読まないことを書く | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"SKILL.md asks for the author with the candidates and never reads git config or the system"`が通る | #62 |
| `references/report-structure.md`がテンプレートの全てのプレースホルダーを表に挙げる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"report-structure.md lists every placeholder in the template"`が通る | #62 |
| `README.md`、`README.ja.md`、`docs/how-it-works.md`、`docs/how-it-works.ja.md`が、作者名を保存するファイル`author.txt`を書く | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the docs say where the author's name is kept"`が通る | #62 |
| 作者の行を持たない報告書(今までのテンプレートで作った物)に、`check-report.py`は今どおり`ok`を出す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"a complete report prints ok and exits 0"`が通る | #62 |
| 埋めていないテンプレートに、`check-report.py`は今どおり残ったプレースホルダーを咎める | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the unfilled template fails on its placeholders"`が通る | #62 |
