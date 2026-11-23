# repo-checks

| Criterion | How to check | Origin |
|---|---|---|
| 日本語の頁 (`*.ja.md`) の見出しの行が、囲みの中を除いて「、」も全角のコロンも語の後の半角のコロンも持たず、`scripts/check.sh`はそのような見出しを`<file>:<行>`で名指して拒む | `bash scripts/check.sh`の検査`"Japanese headings have no commas or colons"`が通る | #275 |
| 見出しを書き換えても、頁の中の相対のリンクが全て辿れる | `bash scripts/check.sh`の検査`"relative links resolve"`が通る | #275 |
| 英語の頁と日本語の頁が今どおり対になる | `bash scripts/check.sh`の検査`"pages have Japanese counterparts"`が通る | #275 |
| Every plugin's version matches the newest section of its changelog | `bash scripts/check.sh` check `"versions match the changelogs"` passes | #391 |
| The Latest column of both READMEs shows each plugin's version | `bash scripts/check.sh` check `"README tables list every plugin"` passes | #391 |
| The skills that follow a provided skill in diagram-styles match their recorded fingerprints | `musubi check` check `"musubi check plugins/diagram-styles/skills"` passes | #391 |
