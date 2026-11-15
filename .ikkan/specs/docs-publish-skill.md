# docs-publish-skill

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| docs-publishの評価のセットは、決めた5件の案件を、それぞれ`case.yaml`を持つフォルダとして`plugins/docs-publish/evals/`の下に持つ。5件は`plan-first`、`api-page`、`translate-page`、`check-and-fix`、`unrelated-request` | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"the eval suite has the five cases"`が通る | #140 |
| 案件の用意の命令を手元で回すと、案件が前提にする状態ができる。`plan-first`は文書のフォルダを持たず、`api-page`は`slugify`のページに書く所が残り、`translate-page`は英語のQuickstartが書き終わって日本語が未訳で、`check-and-fix`は検査が壊れたリンクと古い翻訳だけを出す | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"the eval fixtures build the states their cases start from"`が通る | #140 |
| 評価の結果を置くフォルダ`plugins/docs-publish/evals/results/`の下のファイルは、gitに追加できない | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"eval results are ignored by git"`が通る | #140 |
| `SKILL.md`の本文の語数と説明文の字数は、検査が持つ上限を超えない。上限は削った後の語数と字数で、今の2,785語と682字より小さい | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #140 |
| `check`が問題を出す時、出した問題の種類ごとに直し方を1行ずつ書く | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"check says how to fix each kind of problem it lists"`が通る | #140 |
| `check`の最後の行は、直し方を足した後も、問題の数かNo problems.とリンクの数をまとめた行のままである | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"a finished set has no problems"`と`"the summary counts the broken link"`が通る | #140 |
| 削った後の`SKILL.md`も、ほかの文書を読むのは本人が名指して同意した時だけで、読んだ文を写さないと書く | `bash plugins/docs-publish/skills/docs-publish/tests/test-docs-publish.sh`の検査`"SKILL.md reads the projects to follow only when the user names them and agrees"`と`"SKILL.md says not to copy text from the docs it follows"`が通る | #140 |
