# secret-service-move

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| Linuxの置き場を選んだ時、`move`は選んだ値を秘密の置き場に入れ、読み戻して同じ値と確かめ、行を`"$(secret-tool lookup service NAME account "$USER" 2>/dev/null)"`に書き換え、結果に秘密の置き場へ入れたと書く | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"on Linux, move stores the value in the secret service, reads it back, and rewrites the line"`が通る | #27 |
| Linuxの置き場では、値は`secret-tool`の標準入力にだけ渡り、命令の引数に値も値の一部も載らない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"on Linux, the value reaches secret-tool only on standard input"`が通る | #27 |
| Linuxの置き場では、fishの行を`(secret-tool lookup service NAME account "$USER" 2>/dev/null)`に書き換える | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"on Linux, a fish line reads the value with fish command substitution"`が通る | #27 |
| Linuxの置き場で、同じ名前に別の値が入っている時、`move`はその項目を飛ばして理由を書き、置き場の値もfileも変えない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"on Linux, a name that holds a different value is skipped and not overwritten"`が通る | #27 |
| Linuxの置き場に届かない時、`move`はその項目を飛ばして`secret-tool`が書いた理由を添え、fileを変えない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"on Linux, an unreachable secret service skips the item and leaves the file as it was"`が通る | #27 |
| Linuxの置き場では、`scan`は項目を移せる物として挙げ、書き換えた後の行を`secret-tool`の形で見せる | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"on Linux, scan shows the secret-tool line as what the line becomes"`が通る | #27 |
| 書き換えた行は、新しいbashで同じ値を読み込む | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"on Linux, a new bash loads the moved value through secret-tool"`が通る | #27 |
| Linuxの置き場を選んで`secret-tool`が無い時、`move`は終了コード3で止まって`secret-tool`の名前を出し、`scan`は移せない理由に`secret-tool`の名前を書く | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"without secret-tool, move exits 3 and names it, and scan says why it cannot move"`が通る | #27 |
| `README.md`、`README.ja.md`、`docs/how-it-works.md`、`docs/how-it-works.ja.md`、`SKILL.md`が、Linuxで`secret-tool`を使って移す道を書く | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"the docs describe moving on Linux with secret-tool"`が通る | #27 |
| 今どおり、どの出力にも値と値の頭の4文字が出ない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"no output contains a value or its first 4 characters"`が通る | #27 |
| 今どおり、macOSではKeychainへ移し、別の値が入った名前を飛ばす | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"move moves GH_TOKEN"`と`"move skips a name that holds a different value"`が通る | #27 |
| 今どおり、`scan`は標準エラーに何も書かない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"the scan wrote nothing to standard error"`が通る | #27 |
