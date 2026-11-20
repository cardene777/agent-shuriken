# repo-checks

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 日本語の頁 (`*.ja.md`) の見出しの行が、囲みの中を除いて「、」も全角のコロンも語の後の半角のコロンも持たず、`scripts/check.sh`はそのような見出しを`<file>:<行>`で名指して拒む | `bash scripts/check.sh`の検査`"Japanese headings have no commas or colons"`が通る | #275 |
| 見出しを書き換えても、頁の中の相対のリンクが全て辿れる | `bash scripts/check.sh`の検査`"relative links resolve"`が通る | #275 |
| 英語の頁と日本語の頁が今どおり対になる | `bash scripts/check.sh`の検査`"pages have Japanese counterparts"`が通る | #275 |
