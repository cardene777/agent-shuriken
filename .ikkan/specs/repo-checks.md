# repo-checks

| Criterion | How to check | Origin |
|---|---|---|
| 日本語の頁 (`*.ja.md`) の見出しの行が、囲みの中を除いて「、」も全角のコロンも語の後の半角のコロンも持たず、`scripts/check.sh`はそのような見出しを`<file>:<行>`で名指して拒む | `bash scripts/check.sh`の検査`"Japanese headings have no commas or colons"`が通る | #275 |
| 見出しを書き換えても、頁の中の相対のリンクが全て辿れる | `bash scripts/check.sh`の検査`"relative links resolve"`が通る | #275 |
| 英語の頁と日本語の頁が今どおり対になる | `bash scripts/check.sh`の検査`"pages have Japanese counterparts"`が通る | #275 |
| Every plugin's version matches the newest section of its changelog | `bash scripts/check.sh` check `"versions match the changelogs"` passes | #391 #398 #412 #416 #423 #428 #432 #436 #443 |
| The Latest column of both READMEs shows each plugin's version | `bash scripts/check.sh` check `"README tables list every plugin"` passes | #391 #398 #412 #416 #423 #428 #432 #436 #443 |
| The skills that follow a provided skill in diagram-styles match their recorded fingerprints | `musubi check` check `"musubi check plugins/diagram-styles/skills"` passes | #391 |
| The skills that follow page-design match their recorded fingerprints | `musubi check` check `"musubi check of design-formats and the skills that follow page-design"` passes | #398 #443 |
| The japanese-speaking test still finds the round-table line in the changelog after the line moves into the release section | `bash plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh` check `"the changelog names the round-table under Unreleased or any release"` passes | #428 |
| The portman test still finds the line of the write refusals in the changelog after the line moves into the release section | `bash plugins/portman/skills/portman/tests/test-portman.sh` check `"the changelog names the refusal for files that cannot be written"` passes | #436 |
| The skills of doc-formats and evm-dev match their recorded fingerprints | `musubi check` check `"musubi check of doc-formats and evm-dev"` passes | #443 |
