# pass-move

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| `--store pass`を付けた時、`move`は選んだ値を`pass insert`で入れ、`pass show`で読み戻して同じ値と確かめ、行を`"$(pass show NAME 2>/dev/null)"`に書き換え、結果に`pass`へ入れたと書く | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"with --store pass, move stores the value in pass, reads it back, and rewrites the line"`が通る | #126 |
| `--store pass`では、値は`pass`の標準入力にだけ渡り、命令の引数に値も値の一部も載らない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"with --store pass, the value reaches pass only on standard input"`が通る | #126 |
| `--store pass`では、fishの行を`(pass show NAME 2>/dev/null)`に書き換える | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"with --store pass, a fish line reads the value with fish command substitution"`が通る | #126 |
| `--store pass`で、同じ名前に別の値が入っている時、`move`はその項目を飛ばして理由を書き、`pass`の項目もfileも変えない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"with --store pass, a name that holds a different value is skipped and not overwritten"`が通る | #126 |
| `--store pass`で、GPGの鍵が使えず読み戻せない時、`move`はその項目を飛ばして`pass`が書いた理由を添え、fileを変えない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"with --store pass, a value that cannot be read back is skipped and the file is left as it was"`が通る | #126 |
| `--store pass`では、`scan`は書き換えた後の行を`pass show`の形で見せる | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"with --store pass, scan shows the pass line as what the line becomes"`が通る | #126 |
| 書き換えた行は、新しいbashで`pass`から同じ値を読み込む | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"with --store pass, a new bash loads the moved value through pass"`が通る | #126 |
| `--store pass`で`pass`が無い時、`move`は終了コード3で止まって`pass`の名前を出し、`scan`は移せない理由に`pass`の名前を書く | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"without pass, move --store pass exits 3 and names it, and scan says why it cannot move"`が通る | #126 |
| `scan`は、`pass`と初期化した置き場がある時だけ、選べる置き場に`pass`を挙げる | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"scan lists pass as a store to choose only when the password store is initialized"`が通る | #126 |
| `README.md`、`README.ja.md`、`docs/how-it-works.md`、`docs/how-it-works.ja.md`、`SKILL.md`が、`pass`へ移す道と、KWalletは`secret-tool`の道で届くことを書き、`SKILL.md`はどちらへ移すかを利用者に聞く手順を持つ | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"the docs describe moving into pass and reaching KWallet through secret-tool"`が通る | #126 |
| 今どおり、どの出力にも値と値の頭の4文字が出ない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"no output contains a value or its first 4 characters"`が通る | #126 |
| 今どおり、Linuxの置き場では`secret-tool`で移し、macOSではKeychainへ移す | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"on Linux, move stores the value in the secret service, reads it back, and rewrites the line"`と`"move moves GH_TOKEN"`が通る | #126 |
| 今どおり、`scan`は標準エラーに何も書かない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"the scan wrote nothing to standard error"`が通る | #126 |
