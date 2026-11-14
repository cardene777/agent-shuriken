# port-registry

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| portmanの台帳で別のフォルダのprojectが3100を持つ時、`plan --assign-port --from 3100`は3100を選ばず、別のportを返す | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"with portman, plan skips a port portman holds for another folder"`が通る | #68 |
| portmanの台帳で同じフォルダ(`dir`が同じ)のprojectがそのサービスの名前のportを持つ時、`plan`はそのportを返し、選んだ理由を`registered in portman`と出す | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"with portman, plan uses the port portman holds for this folder"`が通る | #68 |
| portmanの台帳に`dir`の無いprojectがフォルダ名と同じ名前で在る時、`plan`はそのprojectのportを返す | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"with portman, a project without a folder is matched by the folder name"`が通る | #68 |
| portmanが入っている時、`apply`は選んだportを`portman.py add`で台帳に登録し、`ports.json`に書かない | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"with portman, apply registers the port in portman and not in the ports record"`が通る | #68 |
| git worktreeの作業場所で`plan`を打った時、元のcheckoutが台帳に持つportとは別のportを返す | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"with portman, a worktree gets a port of its own"`が通る | #68 |
| `ports.json`に移す前の行が残る間、`plan`はそのportも選ばず、`ports --move`で移せることを1行で知らせる | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"with portman, plan skips the ports not yet moved and names ports --move"`が通る | #68 |
| portmanの`list --json`が台帳を読めずに終わり方2で終わった時、`plan`は警告を1行出して`ports.json`だけで選び、終わり方0で終わる | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"an unreadable registry gives one warning and plan uses the ports record"`が通る | #68 |
| `ports --move`は移す行と飛ばす行を見せ、`--confirm`が無い時は台帳と`ports.json`のどちらも変えない | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"ports --move without --confirm changes neither record"`が通る | #68 |
| `ports --move --confirm`は`ports.json`の全部の行を`portman.py add`で台帳に登録し、登録できた行を`ports.json`から消す | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"ports --move --confirm moves every port into portman"`が通る | #68 |
| 台帳で別のprojectが同じportを持つ行は、`ports --move --confirm`が理由を出して登録を拒み、その行を`ports.json`に残す | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"ports --move keeps a port portman holds for another project"`が通る | #68 |
| `INIT_PROJECT_PORTMAN`を置かない時、Claude Codeのプラグインの置き場(`~/.claude/plugins/cache`)に在るportmanを見つけて使う | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"portman is found in the Claude Code plugins folder"`が通る | #68 |
| `INIT_PROJECT_PORTMAN`を置かず、Claude Codeの置き場にportmanが無い時、Codexのプラグインの置き場(`~/.codex/plugins/cache`)に在るportmanを見つけて使う | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"portman is found in the Codex plugins folder"`が通る | #68 |
| portmanの`doctor`は、`dir`のフォルダがもう無いprojectのportを名指す | `bash plugins/portman/skills/portman/tests/test-portman.sh`の検査`"doctor names a project whose folder is gone"`が通る | #68 |
| init-projectの`README.md`と`README.ja.md`と`docs/how-it-works.md`と`docs/how-it-works.ja.md`が、portmanが入っている時はportmanの台帳に登録することと`ports --move`を書く | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the README and How it works say the ports go to portman"`が通る | #68 |
| portmanの`README.md`と`README.ja.md`が、init-projectが台帳に登録することと、フォルダの無いprojectを`doctor`が名指すことを書く | `bash plugins/portman/skills/portman/tests/test-portman.sh`の検査`"the README says init-project registers here and doctor names missing folders"`が通る | #68 |
| `plan`は台帳を変えない(`plan`の前と後で`registry.json`のhashが同じ) | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"with portman, plan leaves the registry unchanged"`が通る | #68 |
| `init_project.py`は台帳のfileの名前(`registry.json`)を持たず、台帳を直接書けない | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the script never names the registry file"`が通る | #68 |
| portmanが入っていない時、`plan`は今と同じく`--from`からの最初の空きportを返す | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"the first free port from --from is picked"`が通る | #68 |
| portmanが入っていない時、`plan`は`ports.json`で別のprojectのportと使用中のportを飛ばす | `bash plugins/init-project/skills/init-project/tests/test-init-project.sh`の検査`"a port recorded for another project and a port in use are both skipped"`が通る | #68 |
| `.ikkan/specs/`の下に日本語の記録が在っても、`check.sh`の英語の検査が通る | `bash scripts/check.sh`の検査`"English outside the Japanese pages"`が通る | #68 |
