# init-project-skill

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| init-projectの評価のセットは、6件の案件を`plugins/init-project/evals/`の下にフォルダとして持ち、どれも`case.yaml`と`fixture.sh`を持つ。6件は`plan-first`、`approved-1password`、`env-values-stay-out`、`keeps-existing-template`、`unrelated-request`、`docker-port-blocked` | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the eval suite has the six cases"`が通る | #158 |
| 案件の用意の命令を一時の作業の場所で回すと、案件が前提にする状態ができる。6件とも`dev`のscriptを持つ`package.json`と、偽の値の名前を2つ持つ`.env`を持ち、`detect`はどれも`web-app`と判定し、どれも`Dockerfile`もcomposeのfileも持たない。`keeps-existing-template`だけが、`PANTRY_DB_HOST`を`op://Dev/pantry-shared/db-host`へ向ける手書きの行を持つ`.env.tpl`を持つ | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the eval fixtures build the states their cases start from"`が通る | #158 |
| 評価の結果を置くフォルダ`plugins/init-project/evals/results/`の下のファイルは、gitに追加できない | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"eval results are ignored by git"`が通る | #158 |
| `SKILL.md`の本文の語数と説明文の字数は、検査が持つ上限を超えない。上限は削った後の語数と字数で、今の2,260語と612字より小さい | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #158 |
| 削った後の`SKILL.md`も、env fileを開かず表示も検索もしないこと、`op read`などの値を出す命令を打たないこと、値をチャットに貼らせないこと、計画への明らかな承認の前に書かないこと、既にあるfileは名指して頼まれた時だけ置き換えることを書く | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the SKILL.md keeps its rules on env values, approval, and existing files"`が通る | #158 |
| `plan --help`は、削った後の`SKILL.md`が書かない`--docker`、`--assign-port`、`--port`、`--from`、`--service`、`--container-port`、`--overwrite`、`--env`、`--vault`、`--item`、`--env-file`を説明する | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"plan --help describes the flags the SKILL.md leaves out"`が通る | #158 |
| scriptは削る表が書いていたことを自分で出す。`detect`は種類をその理由とともに出し、`plan`は書くfileに`[create]`、残すfileに`[skip]`と理由を付け、名前の正しくない保管庫と使用中のportと知らない計画の番号を断る時は直し方を出す | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the script prints what the removed tables said"`が通る | #158 |
