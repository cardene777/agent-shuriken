# 目的と利用者

- この repo は、Claude Code と Codex と GitHub Copilot CLI に入れる plugin の一覧 (marketplace) を持つ。Gemini CLI ほか `SKILL.md` を読む agent も skill を使える (根拠 `README.md`、`AGENTS.md` の What this repository is)
- 各 plugin は面倒な作業を agent に任せ、戻せない手順は利用者の承認を通す (根拠 `README.md` の冒頭)
- 利用者は、公開された marketplace から plugin を入れる開発者で、入れ方は agent ごとに `README.md` の Install が持つ
- plugin は repo 全体と別に版を持ち、`<plugin>--v<版>` の tag で出す。repo の版は `v<版>` の tag で出す (根拠 `README.md` の Versions、`docs/releasing.md`)
- 各 plugin の今の版は `plugins/<plugin>/.claude-plugin/plugin.json` と `plugins/<plugin>/.codex-plugin/plugin.json` の `version` が持つ
- 守る約束 (秘密の値を読まない、消す操作は利用者が選んだ物だけ、利用者のデータを外へ送らない) は `docs/safety.md` が持つ
- Anthropic と OpenAI の plugin の一覧への出し方は `docs/publishing.md` が持つ
- 利用者の数と、どの plugin がどれだけ使われているかは不明
