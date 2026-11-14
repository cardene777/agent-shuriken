# report-pdf-pages

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 9つの節を持つ見本のレポートを実際のブラウザーで印刷すると、PDFの目次のどの行も、その節の見出しがある頁の番号で終わる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"every contents entry in the PDF shows the page that holds its section heading"`が通る | #61 |
| 表紙を除く各頁の下に、表紙を1頁目と数えた頁番号が出る | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"every page but the cover shows its number at the bottom"`と`"the cover shows no page number"`が通る | #61 |
| 印刷の後も`report.html`は変わらず、そのフォルダーに一時の写しが残らない | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"printing leaves report.html unchanged and no copy in its folder"`が通る | #61 |
| ブラウザーで開いた`report.html`の目次に頁番号が無い | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"report.html in a browser has no page numbers in its contents"`が通る | #61 |
| PDFが頁の行き先を持たない時、`to-pdf.sh`は終了コード0でPDFを書き、標準出力にPDFのパスだけを出し、標準エラーに題名だけにした理由を1行出す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"a PDF without page destinations keeps titles only and says why"`が通る | #61 |
| 目次のリンク先の節がレポートに無い時、`to-pdf.sh`は題名だけのPDFを書き、理由の1行でその節を名指す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"a contents link to a missing section keeps titles only and names the section"`が通る | #61 |
| `README.md`、`README.ja.md`、`docs/how-it-works.md`、`docs/how-it-works.ja.md`が、目次と各頁の頁番号を書く | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the docs describe the page numbers"`が通る | #61 |
| `to-pdf.sh`は今どおり終了コード0でレポートの隣にPDFを書き、そのパスを出す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"to-pdf exits 0 and prints the PDF next to the report"`が通る | #61 |
| PDFは呼び出し側のumaskが022でも本人だけが読める | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the PDF is readable only by the user although the caller's umask is 022"`が通る | #61 |
| ブラウザーの使い捨てのプロフィールは終わった後に消える | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the profile is removed afterwards"`が通る | #61 |
| 全てのプレースホルダーを埋めたテンプレートに、`check-report.py`は今どおり`ok`を出す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the filled template with an author prints ok"`が通る | #61 |
