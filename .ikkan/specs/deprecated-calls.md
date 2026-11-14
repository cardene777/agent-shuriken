# deprecated-calls

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 入っているruffが非推奨の規則(`UP035`など)の結果を返した時、`scan`はその結果をfileと行とruffの名前と一緒に非推奨の呼び出しとして挙げる | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a ruff finding of a deprecation rule is listed as a deprecated call with file and line"`が通る | #66 |
| ruffが非推奨の規則の表に無い規則(書き方の提案の`UP032`とセキュリティの`S306`)の結果を返しても、`scan`は非推奨の呼び出しに挙げない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a ruff finding of another rule is not listed as a deprecated call"`が通る | #66 |
| ruffの複雑さの規則(`C901`など)の結果は、今どおり道具の欄のruffに、rootから見たpathで並ぶ | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"installed ruff ran with paths relative to the root"`が通る | #66 |
| プロジェクトが`.semgrep.yml`を持つ時、`scan`はsemgrepに`--metrics off`を渡し、`--config`にはプロジェクトの規則のfileだけを渡す。登録所の規則(`auto`、`p/`、`r/`、URL)は渡さない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"semgrep runs with the project's rule file, metrics off, and no registry rules"`が通る | #66 |
| プロジェクトが規則のfile(`.semgrep.yml`、`.semgrep.yaml`、`.semgrep/`)を持たない時、`scan`はsemgrepを動かさず、その理由を非推奨の呼び出しの記録に残す | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"semgrep does not run without the project's own rule file and says why"`が通る | #66 |
| semgrepの結果のうち、規則のid、文、metadataに非推奨とある物を、`scan`はfileと行と一緒に非推奨の呼び出しとして挙げる | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a semgrep finding of a rule about deprecation is listed as a deprecated call"`が通る | #66 |
| 規則のidかmetadataの`category`がセキュリティを示すsemgrepの結果は、非推奨の呼び出しにも道具の欄にも出せない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a semgrep finding of a security rule is listed nowhere"`が通る | #66 |
| 非推奨ともセキュリティとも書かれていないsemgrepの結果は、道具の欄のsemgrepに並ぶ | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"other semgrep findings are listed under the semgrep tool"`が通る | #66 |
| `node_modules/.bin`のESLintの設定が非推奨の規則(`@typescript-eslint/no-deprecated`など)を有効にしている時、`scan`はESLintを回し、その規則の結果だけをfileと行と一緒に非推奨の呼び出しとして挙げる | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"eslint findings of a deprecation rule are listed when its config turns one on"`が通る | #66 |
| ESLintの設定が非推奨の規則を1つも有効にしていない時、`scan`はESLintでの検査を回さず、その理由を記録に残す | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"eslint does not lint when its config turns on no deprecation rule and says why"`が通る | #66 |
| ruffもsemgrepもESLintも入っていない時、`scan`は道具ごとに動かなかった理由を記録に残し、報告にも載せる | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"without ruff, semgrep, or eslint, each tool's reason is kept and put in the report"`が通る | #66 |
| ruffかsemgrepが誤りで止まった時、`scan`は結果0件と書かず、動かなかった理由として止まった時の文を残す | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"a ruff or semgrep that stops with an error is recorded as not run with its reason"`が通る | #66 |
| 要約に`Deprecated calls:`の行があり、数と、動いた道具と、動かなかった道具を示す | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the summary shows the deprecated calls and the tools that did not run"`が通る | #66 |
| 報告に、英語と日本語の見出しを持つ「非推奨の呼び出し」の欄がある | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the report has a tab for deprecated calls"`が通る | #66 |
| `scan.json`の形式の版は3で、`report`は版2の`scan.json`を終了コード2で断り、`scan`のやり直しを求める | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"scan.json has schema 3"`と`"report refuses a scan.json of schema 2 and asks to scan again"`が通る | #66 |
| `report`は今どおり版1の`scan.json`も終了コード2で断る | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"report refuses a scan.json of schema 1 and asks to scan again"`が通る | #66 |
| `SKILL.md`と`README.md`と`README.ja.md`と`docs/how-it-works.md`と`docs/how-it-works.ja.md`が、非推奨の呼び出しを測る物として挙げ、semgrepに`--metrics off`を渡すと書く | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the docs describe the deprecated calls and how semgrep is run"`が通る | #66 |
| `scan`はパッケージの管理の命令(`npm`、`npx`、`pnpm`、`yarn`、`bunx`)を動かさず、ネットにつながない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the scan runs no package manager"`が通る | #66 |
| knipが入っている時は今どおりknipを動かし、その結果を道具の欄に残す | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"installed knip ran"`が通る | #66 |
| `scan`は今どおり標準エラーに何も書かない | `bash plugins/techdebt/skills/techdebt/tests/test-techdebt.sh`の検査`"the scan wrote nothing to standard error"`が通る | #66 |
