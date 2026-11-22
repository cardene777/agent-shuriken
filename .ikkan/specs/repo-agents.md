# repo-agents

| Criterion | How to check | Origin |
|---|---|---|
| `AGENTS.md` names issues, with the sections the ikkan workflow adds to them, among what is written in English | `bash scripts/check.sh` check `"AGENTS.md asks for issues and new .ikkan records in English"` passes | #377 |
| `AGENTS.md` asks that an issue be titled like a commit subject in English, because the pull request and the squashed commit take its title | `bash scripts/check.sh` check `"AGENTS.md asks for issues and new .ikkan records in English"` passes | #377 |
| `AGENTS.md` says that new records under `.ikkan/` are written in English and that older ones are in Japanese | `bash scripts/check.sh` check `"AGENTS.md asks for issues and new .ikkan records in English"` passes | #377 |
| The check that reads the dependency exceptions in `AGENTS.md` still passes | `bash scripts/check.sh` check `"script dependencies are named in AGENTS.md"` passes | #377 |
