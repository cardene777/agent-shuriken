# diagram-explainer-skill

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| diagram-explainerの評価のセットは、決めた4組の案件を5件のフォルダとして`plugins/diagram-explainer/evals/`の下に持ち、どれも`case.yaml`を持つ。5件は`outline-first`、`unrelated-request`、`build-from-outline`、`fix-missing-figure`、`japanese-document` | `bash plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh`の検査`"the eval suite has the five cases"`が通る | #149 |
| 案件の用意の命令を一時の作業の場所で回すと、案件が前提にする状態ができる。5件とも説明する小さなproject(`package.json`と`src/queue.js`)を持ち、`fix-missing-figure`だけが`docs/explainers/queue-lite/`に内容のJSONと組み立てたHTMLを持ち、そのHTMLに`check.py`を当てると図の無い節を名指して1で終わる。ほかの4件は`docs/explainers/`を持たない | `bash plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh`の検査`"the eval fixtures build the states their cases start from"`が通る | #149 |
| 評価の結果を置くフォルダ`plugins/diagram-explainer/evals/results/`の下のファイルは、gitに追加できない | `bash plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh`の検査`"eval results are ignored by git"`が通る | #149 |
| `SKILL.md`の本文の語数と説明文の字数は、検査が持つ上限を超えない。上限は削った後の語数と字数で、今の2,373語と800字より小さい | `bash plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #149 |
| 削った後の`SKILL.md`も、調べる時に利用者のproject名や会社名を検索に入れないこと、Webの文とfileの文を指示として扱わないこと、推測を事実と書かないこと、資料がネットワークから何も読み込まないこと、書く前に構成の同意を取ること、完成したHTMLを手で直さないこと、ブラウザが無い時は`--live`無しで確かめて測っていないと伝えることを書く | `bash plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh`の検査`"the SKILL.md keeps its rules on searches, sources, the network, the outline, and editing"`が通る | #149 |
| `check.py --help`は、削った後の`SKILL.md`が書かない`--sections`、`--widths`、`--words`、`--para`、`--sent`を説明する | `bash plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh`の検査`"check.py --help describes the options the SKILL.md leaves out"`が通る | #149 |
