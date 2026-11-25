# mechanism-explainer

| Criterion | How to check | Origin |
|---|---|---|
| The marketplace lists `mechanism-explainer`, and the plugin has both manifests, README and how-it-works pages in English and Japanese, a changelog, the root license, and an icon on the shared tile | `bash plugins/mechanism-explainer/tests/test-mechanism-explainer.sh` check `"the marketplace lists the plugin with its pages"` passes | #507 |
| The dependency line of `AGENTS.md` names `mechanism-explainer` and the dragon it fetches with `npx` | `bash plugins/mechanism-explainer/tests/test-mechanism-explainer.sh` check `"AGENTS.md names the plugin's dragon use"` passes | #507 |
| `SKILL.md` has the agent plan each section as one question with a one-sentence answer and two to four figures before writing any notation | `bash plugins/mechanism-explainer/tests/test-mechanism-explainer.sh` check `"the skill plans questions and figures first"` passes | #507 |
| `SKILL.md` has the agent write a `layout: guide` Markdown with `note: pop` and export it with `npx -y @cardenelabs/dragon@<version>` at one exact version | `bash plugins/mechanism-explainer/tests/test-mechanism-explainer.sh` check `"the skill exports a guide page with a pinned dragon"` passes | #507 |
| `SKILL.md` has the agent run `dragon check` and `dragon check --layout` and fix every error before the export | `bash plugins/mechanism-explainer/tests/test-mechanism-explainer.sh` check `"the skill checks the notation and the layout before exporting"` passes | #507 |
| The PDF script writes a PDF from an exported page with a Chromium-based browser already on the machine | `bash plugins/mechanism-explainer/tests/test-mechanism-explainer.sh` check `"the PDF script prints an exported page"` passes | #507 |
| The PDF script refuses with exit 3 and writes nothing when no browser is found | `bash plugins/mechanism-explainer/tests/test-mechanism-explainer.sh` check `"the PDF script refuses without a browser"` passes | #507 |
| The skill's description says it writes an explainer page that answers questions with dragon figures, and its PDF | `bash plugins/mechanism-explainer/tests/test-mechanism-explainer.sh` check `"the description names the page and the PDF"` passes | #507 |
| The repository checks pass with the new plugin | `bash scripts/check.sh` check `"plugin manifests agree"` passes | #507 |
