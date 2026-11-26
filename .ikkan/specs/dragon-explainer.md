# dragon-explainer

| Criterion | How to check | Origin |
|---|---|---|
| The marketplace lists `dragon-explainer`, and the plugin has both manifests, a README, a how-it-works page, a changelog, and an icon, with the Japanese counterparts | `bash plugins/dragon-explainer/skills/dragon-explainer/tests/test-dragon-figure.sh` check `plugin-is-listed-with-both-manifests` passes | #511 |
| A `dragon` block names a `.dragon` notation file next to the content JSON, and `render.py` writes its notation as a still dragon block with its caption, which counts as the section's figure | `bash plugins/dragon-explainer/skills/dragon-explainer/tests/test-dragon-figure.sh` check `dragon-block-renders-a-still-block` passes | #511 |
| `render.py` refuses a `dragon` block whose file is missing, lies outside the content folder, or is not a `.dragon` file | `bash plugins/dragon-explainer/skills/dragon-explainer/tests/test-dragon-figure.sh` check `dragon-block-refuses-bad-file` passes | #511 |
| After `dragon embed`, the finished page holds an SVG for every dragon block, no dragon block, and no script loaded from the network, and `check.py` passes it | `bash plugins/dragon-explainer/skills/dragon-explainer/tests/test-dragon-figure.sh` check `embedded-page-is-offline` passes | #511 |
| The bundled English and Japanese samples carry a dragon figure and build through `dragon embed` | `bash plugins/dragon-explainer/skills/dragon-explainer/tests/test-dragon-figure.sh` check `samples-build-with-dragon-figures` passes | #511 |
| `SKILL.md` tells the agent to run `dragon check` and `dragon check --layout` on each notation file and `dragon embed` with a pinned dragon version before handing the page over | `bash plugins/dragon-explainer/skills/dragon-explainer/tests/test-dragon-figure.sh` check `skill-runs-dragon-check-and-embed` passes | #511 |
| The repository checks pass with the new plugin | `bash scripts/check.sh` ends with 0 | #511 |
