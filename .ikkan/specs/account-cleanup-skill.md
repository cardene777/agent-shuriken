# account-cleanup-skill

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| account-cleanupの評価のセットは、決めた4組の案件を5件のフォルダとして`plugins/account-cleanup/evals/`の下に持ち、どれも`case.yaml`を持つ。5件は`trigger-asks-first`、`unrelated-request`、`collect-and-describe`、`password-not-shown`、`plan-before-deleting` | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"the eval suite has the five cases"`が通る | #145 |
| 案件の用意の命令を一時のHOMEで回すと、案件が前提にする状態ができる。`trigger-asks-first`と`unrelated-request`はデータのフォルダを持たず、`collect-and-describe`と`password-not-shown`はHOMEの下にChromeの保存データと履歴を持ってデータのフォルダを持たず、`plan-before-deleting`は日本を地域に保存し、消せないサービスを1件含む候補を持つ | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"the eval fixtures build the states their cases start from"`が通る | #145 |
| 案件が作るChromeの保存データは、どの行もパスワードの欄が空で、パスワードを持つ行を拒む | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"the eval fixtures hold no password"`が通る | #145 |
| 評価の結果を置くフォルダ`plugins/account-cleanup/evals/results/`の下のファイルは、gitに追加できない | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"eval results are ignored by git"`が通る | #145 |
| `SKILL.md`の本文の語数と説明文の字数は、検査が持つ上限を超えない。上限は削った後の語数と字数で、今の2,731語と730字より小さい | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #145 |
| 削った後の`SKILL.md`も、パスワードを読む命令と`Login Data`を直に開くことを禁じ、消す前に回ごとの承認を取り、ブラウザでは消す事以外をしないと書く | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"the SKILL.md keeps its rules on passwords, approval, and the browser"`が通る | #145 |
| 地域が他の時、`plan.sh`は消す依頼と一緒に、法律の引用を住む所の法律へ替えるよう伝える注意を出す | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"plan for another region tells the agent to replace the citation"`が通る | #145 |
| `plan.sh`は保存した地域の消す依頼をサービスの名前つきで出し、地域が無い時は聞いて保存するよう伝える | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"plan prints the erasure request for the saved region with the service name"`と`"plan without a saved region tells the agent to ask"`が通る | #145 |
| `prepare.sh`は集めた後に、理由ごとの数を含む要約を出す | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"prepare exits 0 and prints the summary"`と`"prepare counts the reasons"`が通る | #145 |
| `annotate.sh -`は説明のJSONを標準入力から受け取って候補に付け、`descriptions.json`に足し、データのフォルダに説明のファイルを残さない | `bash plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh`の検査`"annotate reads the descriptions from standard input with - and leaves no file behind"`が通る | #145 |
