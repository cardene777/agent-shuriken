# compare-report-verify

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| スキルが読むMarkdownの3つ (`SKILL.md`、`references/report-structure.md`、`references/research-guide.md`) を`page-design`の`verify`に文書として通すと、`ok`を返す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the Markdown the skill reads passes the verify of page-design"`が通る | #281 |
| `report-structure.md`の`## Components`の節に在る部品の例を全て頁の節に置いて雛形を埋めた時、`check-report.py`が`ok`を返し、`verify`も`ok`を返す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"a report built from the components of report-structure.md passes check-report and verify"`が通る | #281 |
| `report-structure.md`が推奨の部品`Recommendation`を持ち、その表は推奨と候補と選ぶ条件の3列と、第一候補と代わりと最後の手の3行を持つ。推奨の行をラベルとコロンで繋ぐ形を、部品の例は持てない | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"report-structure.md gives the recommendation as a table of the first choice, the alternative, and the fallback"`が通る | #281 |
| `report-structure.md`の根拠の決まりが、1つの欄で数を含む事実をカンマで区切るのは2つまでと書き、出典の番号と日付と日本語の読点も同じに数えると書く | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"report-structure.md limits the figures joined with commas in one cell"`が通る | #281 |
| 評価の雛形が組む`applies-feedback`と`pdf-fallback`の頁を`verify`が`ok`で通し、`fixes-check`の頁には文の決まり (`label-colon`、`facts-in-one-line`、`heading-punctuation`) を1つも挙げない | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the eval fixture reports keep the text rules of page-design"`が通る | #281 |
| 評価の雛形は今と同じ状態を作り、`applies-feedback`と`pdf-fallback`の頁に`check-report.py`が`ok`を返し、`fixes-check`の頁には3つの問題だけを返す | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the eval fixtures build the states their cases start from"`が通る | #281 |
| `report-structure.md`が雛形の置き場の印を全て挙げる | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"report-structure.md lists every placeholder in the template"`が通る | #281 |
| `SKILL.md`の本文の語数と説明文の字数が、検査の上限を超えない | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #281 |
| `SKILL.md`が検索と出どころと見積もりと著者の名前の決まりを持ち続ける | `bash plugins/compare-report/skills/compare-report/tests/test-compare-report.sh`の検査`"the SKILL.md keeps its rules on searching, sources, estimates, and the author's name"`が通る | #281 |
