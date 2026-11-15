# init-project-1password-link

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| 既にある`.env.tpl`の行が、計画の書く参照と違う`op://`の参照を持つ変数は、`plan --env`が出す`op item edit`の命令に入らず、ほかの変数は入る | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"a kept template line with another reference is left out of the 1Password commands"`が通る | #164 |
| 既にある`.env.tpl`の行が、計画の書く参照と同じ参照を持つ変数は、`op item edit`の命令に入る | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"a kept template line with the planned reference stays in the 1Password commands"`が通る | #164 |
| 既にある`.env.tpl`の行が参照の代わりに値を持つ変数は、`op item edit`の命令に入らず、scriptのどの出力にもその値が出ない | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"a kept template line with a value is left out and its value is never printed"`が通る | #164 |
| 計画は外した変数の名前を注意書きで出し、その注意書きは残した行の参照も値も持たない | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the plan names the variables it left out, without their lines"`が通る | #164 |
| env fileの変数が全部外れた時、計画はそのenv fileの`op item edit`の命令を出さない | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"no 1Password command is printed when every variable is left out"`が通る | #164 |
| `.env.tpl`が無いprojectでは、計画が書く`.env.tpl`と出す命令は今と同じになる | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"without a template the 1Password commands copy every variable"`が通る | #164 |
| repoの検査は通る | `bash scripts/check.sh` | #164 |
