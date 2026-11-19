# 技術の構成と制約

- skill は Agent Skills の形 (`SKILL.md`) で書き、agent ごとの道具の名前に頼らない (根拠 `AGENTS.md` の Rules for plugins)
- 実行時に使ってよいのは Bash、`jq`、Python 3 の標準ライブラリで、Node.js はブラウザを動かす時だけ使う。利用者に全体へ入れる package を求めない (根拠 `AGENTS.md`)
- 例外は `japanese-writing` だけで、上流の script を `uv run` で動かす (根拠 `AGENTS.md`、`scripts/check.sh`)
- hook を足さない。CI の workflow を足さない (根拠 `AGENTS.md`)
- 画像と font 以外の binary を置かない。画像以外の file は 256 KiB 未満、plugin は 512 file 未満にする (根拠 `AGENTS.md`)
- 状態は `~/.local/share/<plugin>/` に置き、環境変数で替えられるようにする (根拠 `AGENTS.md`)
- code、コメント、script の出力、commit、PR は英語で書く。README と docs の頁は `<name>.ja.md` の日本語の対を持つ (根拠 `AGENTS.md` の Language)
- 日本語を含んでよい file は、`*.ja.md` と `.ikkan/` の下と、`scripts/check.sh` の `JA_ALLOWED` に並ぶ file だけ (根拠 `scripts/check.sh`)
- repo 全体の確かめは `bash scripts/check.sh` で、終了 1 は落ちた検査を名指す (根拠 `AGENTS.md` の Verifying a change)
- plugin ごとのテストは `plugins/<plugin>/skills/<skill>/tests/` の bash の script で、`scripts/check.sh` からは回らない (根拠 `plugins/convey/skills/convey/tests/test-convey.sh`)
- `agent-shared` は Python 3.11 以上の標準ライブラリだけで書き、`uv tool install` で入れる。自分は hook を持たず、利用者が `~/.shared/hooks.json` に書いた hook を配る。テストは `agent-shared/tests/test-agent-shared.sh` で、`scripts/check.sh` からは回らない (根拠 `agent-shared/pyproject.toml`、`AGENTS.md`)
- `claude plugin eval` の case は `plugins/<plugin>/evals/` に置き、手で回し、結果は commit しない (根拠 `AGENTS.md`)
