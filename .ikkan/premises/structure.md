# 置き場と命名

- plugin の一覧は `.claude-plugin/marketplace.json` で、1 plugin に 1 つの項目を持つ (根拠 `AGENTS.md`)
- plugin は `plugins/<name>/` に全てを持ち、入れる時はその folder だけが写る。script は自分の skill の folder から見た相対で file を探す (根拠 `AGENTS.md`)
- plugin の folder は `.claude-plugin/plugin.json`、`.codex-plugin/plugin.json`、`README.md`、`README.ja.md`、`CHANGELOG.md`、`LICENSE`、`assets/icon.svg`、`docs/`、`skills/<skill>/`、`evals/` を持つ (根拠 `AGENTS.md` の図)
- skill の folder は `SKILL.md`、`agents/openai.yaml`、`scripts/`、`templates/`、`data/`、`references/`、`tests/` を持ち、例を置くスキルは `examples/` も、ほかのスキルが従う書式を出すスキルは `formats/` も持つ (根拠 `AGENTS.md`、`plugins/convey/skills/convey/`、`plugins/slides/skills/slide-builder/`、`plugins/design-formats/skills/page-design/`)
- 別の skill が出す中身に従う skill は、`SKILL.md` の隣の `musubi.json` に従う中身を版の範囲と指紋で書き、その skill を名前で開いて読む。必須で従う時は、Claude Code では従う先の plugin を `.claude-plugin/plugin.json` の `dependencies` に書く。任意で従う時は `"optional": true` を付けて `dependencies` に書かず、従う先が入っていなければ自分の雛形か今の順で進む (根拠 `docs/adr/0002-design-skills-run-the-shared-verify.md`、`plugins/evm-dev/skills/contract-design/musubi.json`、`plugins/techdebt/skills/techdebt/musubi.json`)
- HTML の頁を書く skill が利用者の色と書体を当てる時は、雛形の基の色を page-design の意匠の file の鍵の名前で持ち、ほかの濃淡を `color-mix()` でそこから混ぜ、仕上がった頁に page-design の `theme --keys` を名前で開いて回す。意匠の file を読む処理を自分で持たない (根拠 `docs/adr/0003-design-skills-apply-the-shared-theme.md`、`plugins/diagram-explainer/skills/diagram-explainer/assets/doc.css`、`plugins/compare-report/skills/compare-report/templates/base.html`)
- 2 つの `plugin.json` は `name`、`version`、`description`、`author`、`license` が同じで、`name` と `description` は marketplace の項目と同じ (根拠 `AGENTS.md`、`scripts/check.sh`)
- plugin の名前は英小文字と `-` の語で、作業の中身を表す (例 `convey`、`techdebt`、`japanese-writing`) (根拠 `.claude-plugin/marketplace.json`)
- commit の題は `<絵文字> <種別>(<範囲>): <要約>` の英語で、範囲は plugin の名前か `repo` (根拠 `AGENTS.md` の Commits and pull requests)
- ikkan の受入条件は `.ikkan/specs/<機能>.md` に残し、どの plugin にも入らない (根拠 `AGENTS.md`)
- 版を出す手順は `scripts/release.sh` と `docs/releasing.md` が持つ
- `agent-shared` のコマンドは plugin ではなく `agent-shared/` の Python package で、code と既定のエージェントの表 `agents.json` を `src/agent_shared/` に、テストを `tests/test-agent-shared.sh` に持つ。説明の頁は `docs/agent-shared.md` (根拠 `AGENTS.md`)
