# secure-dotfile-skill

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| secure-dotfileの評価のセットは、決めた6件の案件を、それぞれ`case.yaml`を持つフォルダとして`plugins/secure-dotfile/evals/`の下に持つ。6件は`trigger-and-scan`、`git-history`、`tool-files`、`value-not-shown`、`pasted-value`、`unrelated-request` | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"the eval suite has the six cases"`が通る | #138 |
| 評価のセットのファイルは、鍵の形をした値を1つも持たない。偽の鍵は案件を回す時に用意の命令が作る | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"the eval files hold no literal secret"`が通る | #138 |
| 評価の結果を置くフォルダ`plugins/*/evals/results/`の下のファイルは、gitに追加できない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"eval results are ignored by git"`が通る | #138 |
| `SKILL.md`の本文の語数と説明文の字数は、検査が持つ上限を超えない。上限は削った後の語数と字数で、今の2,978語と627字より小さい | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #138 |
| scriptが失敗を出す時、出力は失敗の理由に加えて、利用者かエージェントが次にする事を書く | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"failure messages say what to do next"`が通る | #138 |
| scriptの出力は、失敗の文を変えた後も、鍵の値も値の最初の4文字も持たない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"no output contains a value or its first 4 characters"`が通る | #138 |
