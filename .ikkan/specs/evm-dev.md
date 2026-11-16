# evm-dev

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| `evm-standards.sh check`は、同梱の全ての項目が`status`と`checked`と`source`の3つの欄を持ち、`status`が`announced`、`specified`、`live`、`stopped`のどれかで、`checked`が実在する日付の時に0で終わる | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"check passes on the bundled items"`が通る | #199 |
| `evm-standards.sh check`は、欄が欠けた項目、知らない`status`の項目、実在しない日付の項目を名指して1で終わる | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"check names an item with a missing field, an unknown status, or an impossible date"`が通る | #199 |
| `evm-standards.sh list`は、全ての項目をfile名と`status`と`checked`で並べ、`status`ごとの日数(`announced`は30日、`specified`は90日、`live`と`stopped`は180日)を過ぎた項目に印を付ける。`--today`で今日の日付を差し替えられる | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"list marks the items past the days for their status"`が通る | #199 |
| 同梱の項目は全てERCかEIPで、file名が`erc-`か`eip-`で始まる。L2の項目を持たない | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"every item is an ERC or an EIP"`が通る | #199 |
| 同梱の項目はURLを持たず、出どころを組織と文書の名前で書く | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"no item holds a URL"`が通る | #199 |
| `SKILL.md`は、答える前に`list`で古い項目を見ること、古い項目は公式のERCかEIPの文書で今の状態を調べ直してから答えること、調べ直せない時は項目の確かめた日を添えて確かめられなかったと書くこと、プラグインの項目を書き換えないことを書く | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"the SKILL.md keeps its rules on stale items and on not editing the items"`が通る | #199 |
| `SKILL.md`の本文の語数と説明文の字数は、検査が持つ上限を超えない | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"the SKILL.md stays within its size limits"`が通る | #199 |
| `plugins/evm-dev/evals/`は、EOFが入る予定か、P-256の署名を確かめるプリコンパイル、ERCの状態、関係の無い依頼の案件を持ち、各fixtureが案件の始まりの状態を作る | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"the eval suite has its cases and each fixture builds its state"`が通る | #199 |
| 関係の無い依頼(gitのブランチの名前の変え方)では、技を起動しない | `bash plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh`の検査`"the eval suite has its cases and each fixture builds its state"`が通り、評価の案件`unrelated-request`の採点`skill-not-loaded`が通る | #199 |
| `plugins/evm-dev/`は2つのmanifest、`README.md`と`README.ja.md`、`docs/how-it-works.md`と`docs/how-it-works.ja.md`、`CHANGELOG.md`、`LICENSE`、`assets/icon.svg`、`skills/evm-standards/agents/openai.yaml`を持ち、`.claude-plugin/marketplace.json`と根の`README.md`と`README.ja.md`の表がプラグインを載せ、項目とページは英語で書かれる | `bash scripts/check.sh` | #199 |
| 他のプラグインのfileと版は変わらず、repoの検査が全て通る | `bash scripts/check.sh` | #199 |
