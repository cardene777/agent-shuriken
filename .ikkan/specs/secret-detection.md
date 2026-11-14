# secret-detection

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| `PGPASSWORD`に6文字の値がある時、`scan`はその行を種類`short password`の移せる物として返す | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"scan lists a six-character PGPASSWORD as a movable short password"`が通る | #64 |
| `scan`は`MYSQL_PWD`(5文字)、`DB_PASS`(3文字)、`SIM_PIN`(4文字)、`LOCAL_PASSWORD`(2文字)の値を返す | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"scan finds MYSQL_PWD"`と`"scan finds DB_PASS"`と`"scan finds SIM_PIN"`と`"scan finds LOCAL_PASSWORD"`が通る | #64 |
| `MYPASSWD`のように`_`の無い名前で`PASSWD`で終わる名前の8文字以上の値を、`scan`は種類`password`で返す | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"scan finds MYPASSWD as a password"`が通る | #64 |
| `move`は短いパスワードをほかの値と同じく移し、新しいzshがキーチェーンから同じ値を読む | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"move moves PGPASSWORD"`と`"move moves DB_PASS"`と`"a new zsh loads the short passwords"`が通る | #64 |
| `SKILL.md`と`README.md`と`README.ja.md`と`docs/how-it-works.md`と`docs/how-it-works.ja.md`が、種類`short password`と、短い値も拾う名前を書く | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"the docs name the short password kind and the names"`が通る | #64 |
| `scan`は1文字の`SINGLE_PASSWORD`と、仮の値`todo`の`TEST_PASSWORD`を返さない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"scan ignores SINGLE_PASSWORD"`と`"scan ignores TEST_PASSWORD"`が通る | #64 |
| `scan`は6文字の`FEATURE_KEY`と、`_`の無い名前で`PASS`で終わる`COMPASS`を返さない | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"scan ignores FEATURE_KEY"`と`"scan ignores COMPASS"`が通る | #64 |
| 8文字以上の`DB_PASSWORD`の種類は今どおり`password`のまま | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"a long DB_PASSWORD keeps the kind password"`が通る | #64 |
| どの出力にも、短いパスワードを含む全ての値と、その最初の4文字が無い | `bash plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh`の検査`"no output contains a value or its first 4 characters"`が通る | #64 |
