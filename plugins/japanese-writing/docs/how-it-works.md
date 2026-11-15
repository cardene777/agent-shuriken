# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Japanese Writing reads, runs, and keeps, which files come from upstream, and how to update them.
The agent writes and fixes the text; the scripts in `skills/japanese-writing/scripts/` only point at suspect lines and print to the terminal.
The steps, most scripts, and several references come from `coji/natural-japanese` v2.0.0, copied without changes.

## Files in the skill

Paths are relative to `skills/japanese-writing/`.

| Path | From | What it holds |
|---|---|---|
| `SKILL.md` | This plugin | What to read first and how to run the scripts |
| `references/rules.md` | This plugin | The order of precedence, the format for Markdown kept in a repository, the plugin's own rules, when to read each of its references, and how to return a fix |
| `references/terminology.md`, `subject-and-verb.md`, `ai-smell.md`, `explaining.md`, `asking.md`, `natural-explanation.md`, `sentence-forms.md` | This plugin | Choosing terms, rewriting things used as subjects with metaphor verbs, three shapes of AI-like text, building an explanation, writing questions and options, opening an article, and eight sentence forms |
| `references/metaphor-words.tsv` | This plugin | The metaphor words and the patterns `suspects.py` matches |
| `scripts/suspects.py` | This plugin | Points at the forms `lint.py` does not count |
| `upstream-manifest.txt` | This plugin | The SHA-256 of every file copied from upstream |
| `tests/test-japanese-writing.sh` | This plugin | The plugin's checks |
| `UPSTREAM-SKILL.md` | Upstream | The upstream `SKILL.md`: the steps from writing to cleaning up |
| `references/diagnose.md`, `references/manual-checklist.md`, `references/doctypes/` | Upstream | How to score a text, the checks to do by eye without `uv`, and a guide for each kind of document |
| `scripts/lint.py`, `outline.py`, `paragraphs.py`, `terms.py`, `calques.py`, `newfacts.py`, `textcore.py`, `fixtures/` | Upstream | The scripts, their shared code, and two sample texts |
| `assets/style-profile-template.md` | Upstream | A template for a writer's style profile, used only when you ask the agent to learn your style |
| `LICENSE` | Upstream | The upstream MIT license |

## The scripts

| Script | Reads | Prints |
|---|---|---|
| `lint.py` | One Markdown or text file | Suspect phrases by kind, with how to fix each, and the paragraphs to check one by one. `--json` prints the same as JSON and `--reading-load` points at hard-to-read sentences |
| `suspects.py` | One Markdown file | One line per suspect sentence with its line number, kind, and words, then the count of each of nine kinds. It exits 0 whatever it finds and 1 only when the file cannot be read |
| `outline.py` | One file | The headings, the first sentence of each paragraph, and the list items, with line numbers |
| `paragraphs.py` | One file | Every paragraph, numbered, for the check one by one |
| `terms.py` | One file | Where each technical term first appears and whether it is explained there |
| `calques.py` | One file | Verbs that describe machine work as human actions, and nouns that describe a mechanism as a place |
| `newfacts.py` | The original and the new file, or one file with `--git` | Numbers and proper nouns in the new text that the original lacks. With `--git`, it reads the committed version of the file through `git show` |

None of them write files.
`textcore.py` holds the code they share, and `fixtures/` holds the samples the upstream body uses as examples.

## What it runs and connects to

- Each script runs as `PYTHONDONTWRITEBYTECODE=1 uv run --script <skill folder>/scripts/<script>.py`, so Python writes no `__pycache__` into the skill folder
- `uv` reads the dependencies declared at the top of each script, `sudachipy>=0.6.8` and `sudachidict-core>=20240409`, and on first use downloads them from the Python Package Index into its cache, about 200 MB in all. The cache is `~/.cache/uv` on macOS and Linux unless `UV_CACHE_DIR` names another folder. When no Python 3.10 or later is found, `uv` may download one
- `newfacts.py --git` runs `git show` in the folder of the file you pass
- The plugin never sends your text anywhere. The scripts read local files and print to the terminal
- Left out from upstream: `semantic.py`, which downloads a model of about 1 GB and runs the model's own code, `calibrate.py` and `corpus/`, which tune the thresholds, and the `critical-thinking` skill

## What it keeps

Nothing.
The agent puts intermediate files in a temporary folder outside your project and deletes them when it finishes, as the upstream body's last step says.
The packages stay in uv's cache until you run `uv cache clean`.

## Updating the upstream copy

Copy only the upstream files, so that the plugin's own files stay as they are.

1. Fetch `coji/natural-japanese` at the new commit into an empty folder
2. Copy the files that `upstream-manifest.txt` lists from its `skills/natural-japanese/` folder, the upstream `SKILL.md` as `UPSTREAM-SKILL.md`, and `LICENSE` from its root. Leave out `scripts/semantic.py`, `scripts/calibrate.py`, `corpus/`, and the other skills. Add a line to `upstream-manifest.txt` for a new upstream file the body names, and remove the line of a file upstream removed
3. In the skill folder, rebuild the fingerprints and replace the fingerprint lines with the output, keeping the `#` lines and changing the commit on the `# Source:` line

   ```bash
   grep -E '^[0-9a-f]{64}  ' upstream-manifest.txt | cut -c67- | LC_ALL=C sort | while IFS= read -r f; do shasum -a 256 "$f"; done
   ```

4. Read the difference in `UPSTREAM-SKILL.md`, and fix `references/rules.md`, the plugin's own references, and `SKILL.md` where they no longer match it
5. Change the commit and the date in `THIRD_PARTY_NOTICES.md`, and `COMMIT` in `tests/test-japanese-writing.sh`
6. Run `bash skills/japanese-writing/tests/test-japanese-writing.sh` from the plugin folder
