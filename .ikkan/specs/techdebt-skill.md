# techdebt-skill

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| techdebtの評価のセットは、決めた5件の案件を`plugins/techdebt/evals/`の下にフォルダとして持ち、どれも`case.yaml`と実行できる`fixture.sh`を持つ。5件は`ranks-and-explains`、`fixes-notes`、`masks-marker`、`tools-not-run`、`unrelated-request` | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the eval suite has the five cases"`が通る | #191 |
| 案件の用意の命令を一時の`HOME`と作業の場所で回すと、案件が前提にする状態ができる。5件とも作業の場所は`.git`を持たない。`tools-not-run`を除く4件の作業の場所はPythonの`ledger`を持ち、gitの無い`PATH`で回した`scan`の順位に`ledger/billing.py`と`ledger/report.py`が入り、`tests/test_util.py`は入らない。`ledger/config.py`は`password = "tiger-canary-77"`を持つTODOの行を持ち、`scan.json`ではその値が`***`になる。`fixes-notes`の作業の場所だけが`notes/draft.json`を持ち、`explain`はそれを終わり方2で断る。`tools-not-run`の作業の場所は、Pythonのfileと`node_modules`と`semgrep`の規則を持たないJavaScriptの`package.json`を持ち、`scan.json`では非推奨の呼び出しを調べる道具が1つも走らず、使っていない依存に`left-pad-lite`が挙がる | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the eval fixtures build the states their cases start from"`が通る | #191 |
| 評価の結果を置くフォルダ`plugins/techdebt/evals/results/`の下のfileは、gitに追加できない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"eval results are ignored by git"`が通る | #191 |
| `SKILL.md`の本文の語数と説明文の字数は、検査が持つ上限を超えない。上限は削った後の語数と字数で、今の1,273語と460字より小さい | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #191 |
| 削った後の`SKILL.md`も、頼まれない限りcodeを変えないこと、本人が名指したfileにだけ課題を立てること、印の行を`scan.json`か報告書が見せる形でだけ引くこと、道具が1つも走らない時は調べていないと言うこと、名前で見つけた使っていない依存は消す前に確かめるよう伝えること、道具を入れるのは本人が望む時だけであること、落ちた道具の結果を0と数えないことを書く | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the SKILL.md keeps its rules on code, issues, quoting, and tools"`が通る | #191 |
| 報告書の雛形は`templates/base.html`に在り、プラグインは`report.html`という名前のfileを持たない。`scan`は報告書を状態のフォルダへ`report.html`として書く | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the template is not named report.html, and scan writes report.html"`が通る | #191 |
