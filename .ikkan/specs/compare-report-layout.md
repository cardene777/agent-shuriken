# compare-report-layout

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 雛形を埋めた頁を1400pxの幅で開いた時、表の`num`と`center`の欄は点数も「Not scored」も1行に収まる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"at 1400px, scores and Not scored stay on one line in their table cells"`が通る | #290 |
| 1400pxの幅で候補のカードが2、3、4、5、6枚のどれでも、各行のカードが格子の左端から右端までを埋め、空いた欄の隣に1枚だけのカードを残せない | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"at 1400px, two to six candidate cards fill every row with no lone card beside an empty cell"`が通る | #290 |
| 390pxの幅でカードが1列に並び、頁は横にはみ出せない | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"at 390px, the candidate cards stack in one column and the page does not scroll sideways"`が通る | #290 |
| 1400pxの幅で候補の表とリスクの表の`short`の列が1行に収まり、文の列はどれも短い列より広い | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"at 1400px, the short columns of the candidates and risks tables stay on one line and every text column is wider than each short column"`が通る | #290 |
| 1400pxの幅で本文が1200pxの幅を持ち、表紙の文が本文と同じ左端に揃い、表紙の題が本文の幅まで伸び、数の帯と日付の間が40px以下になる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"at 1400px, the body is 1200px wide and the cover lines up with it, with the title across the body width and the date close under the numbers"`が通る | #290 |
| 1400pxの幅で棒グラフの名前が左に揃い、名前の列は一番長い名前の幅に締まる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"at 1400px, the bar chart names sit on the left in a column as wide as the longest name"`が通る | #290 |
| `report-structure.md`が短い列の書き方を説明し、部品の表の例が短い列に`short`を付ける | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"report-structure.md shows the short class on the short columns of its tables"`が通る | #290 |
| `report-structure.md`の部品の例で埋めた頁は、`check-report.py`と`verify`の両方を通る | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"a report built from the components of report-structure.md passes check-report and verify"`が通る | #290 |
| PDFは表紙を1頁目に置き、目次の各項目は節の見出しが在る頁を示す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"every contents entry in the PDF shows the page that holds its section heading"`が通る | #290 |
| PDFの表紙は頁番号を持てない | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the cover shows no page number"`が通る | #290 |
| 雛形の色は全て色の名前から取り、暗い色は画面にだけ効き、印刷は切り替えを隠す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the template takes every color from a token, keeps dark colors to screens, and hides the switches in print"`が通る | #290 |
| 表紙の作者の行は日付の次の行に在り、空の時は隠れる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the template has the author line under the date and hides it when empty"`が通る | #290 |
| 変えたpluginは`CHANGELOG.md`の`## [Unreleased]`に変更を書く | `bash plugins/design-formats/skills/page-design/tests/test-followers.sh`の検査"the changed plugins note the change under Unreleased"が通る | #290 |
| `page-design`に従うスキルのテストとrepoの検査が通る | `bash plugins/design-formats/skills/page-design/tests/test-followers.sh`の検査"the followers and page-design keep passing their own tests"と検査"the repository checks pass"が通る | #290 |
