# agent-shared-repository

| 条件 | 確かめ方 | 出元 |
|---|---|---|
| `README.md` and `README.ja.md` name `cardene777/agent-shared` as where `agent-shared` lives | `bash scripts/check.sh` check `"README names the agent-shared repository"` passes | #394 |
| `scripts/check.sh` refuses a tracked `agent-shared/` folder, a `docs/agent-shared` page, and any file that names the old install command `agent-shuriken#subdirectory=agent-shared` | `bash scripts/check.sh` check `"no agent-shared copy is left"` passes | #394 |
| After `agent-shared` leaves, every relative link of the pages still resolves | `bash scripts/check.sh` check `"relative links resolve"` passes | #394 |
| The marketplace and the README tables still list every plugin | `bash scripts/check.sh` checks `"marketplace lists every plugin once"` and `"README tables list every plugin"` pass | #394 |
