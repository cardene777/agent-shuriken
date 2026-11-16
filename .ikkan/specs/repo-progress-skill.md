# repo-progress-skill

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| repo-progressの評価のセットは、決めた5件の案件を`plugins/repo-progress/evals/`の下にフォルダとして持ち、どれも`case.yaml`と実行できる`fixture.sh`を持つ。5件は`asks-name`、`asks-folders`、`sums-up-saved-table`、`deletes-nothing`、`unrelated-request` | `bash plugins/repo-progress/skills/repo-progress/tests/test-repo-progress.sh`の検査`"the eval suite has the five cases"`が通る | #193 |
| 案件の用意の命令を一時の`HOME`と作業の場所で回すと、案件が前提にする状態ができる。5件とも作業の場所は`.git`を持たず、`HOME`は`.gitconfig`を持たない。`asks-name`では命令が終わり方2で終わり、`asks-folders`では`--author "Dana Kim"`を付けた命令が終わり方1で終わる。`sums-up-saved-table`の作業の場所は命令が出した表を`progress.txt`に持ち、表は2行以上のrepoを持ち、どの行も`issues`と`prs`の欄が`?`になる。`deletes-nothing`の作業の場所はgitのrepo`shop`を持ち、`shop`は`main`に取り込み済みの枝`feat/12-login`と、取り込んでいない枝`fix/15-typo`を持つ | `bash plugins/repo-progress/skills/repo-progress/tests/test-repo-progress.sh`の検査`"the eval fixtures build the states their cases start from"`が通る | #193 |
| 評価の結果を置くフォルダ`plugins/repo-progress/evals/results/`の下のfileは、gitに追加できない | `bash plugins/repo-progress/skills/repo-progress/tests/test-repo-progress.sh`の検査`"eval results are ignored by git"`が通る | #193 |
| `SKILL.md`の本文の語数と説明文の字数は、検査が持つ上限を超えない。上限は削った後の語数と字数で、今の829語と577字より小さい | `bash plugins/repo-progress/skills/repo-progress/tests/test-repo-progress.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #193 |
| 削った後の`SKILL.md`も、repoと枝と作業場所とissueを変えないこと、技が何も消さないこと、測れなかった値は0でなく分からないと言うこと、repoの在るフォルダを本人に聞くこと、commitの名前を本人に聞くこと、枝か作業場所を消す時は1つずつ名指して本人に確かめ、中身が入ったかを確かめてから消すことを書く | `bash plugins/repo-progress/skills/repo-progress/tests/test-repo-progress.sh`の検査`"the SKILL.md keeps its rules on changing nothing, unknown values, and asking first"`が通る | #193 |
