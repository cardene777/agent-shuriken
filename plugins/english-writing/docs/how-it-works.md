# How it works

English · [日本語](how-it-works.ja.md)

This page describes what English Writing reads, runs, and keeps, which files come from upstream, and how to update them.
The agent writes and fixes the text; the checks only point at suspect lines and print to the terminal.
The patterns of AI-sounding prose come from `blader/humanizer`, copied without changes.

## Files in the skill

Paths are relative to `skills/english-writing/`.

| Path | From | What it holds |
|---|---|---|
| `SKILL.md` | This plugin | What to read first, the content other skills follow, and how to run the checks |
| `references/rules.md` | This plugin, with short quotes from three style guides | The order of precedence, the rules on phrasing translated from Japanese, sentence length, terms, plain English, and vague words, and how to return a fix |
| `references/translationese.tsv` | This plugin | The phrasings translated word for word from Japanese that `suspects.py` matches, each with an example and what to write instead |
| `musubi.json` | This plugin | The content `rules`, version 1.0.0, that other skills follow through musubi: the file `references/rules.md` |
| `scripts/suspects.py` | This plugin | Points at long sentences, passive voice, and phrasing translated from Japanese |
| `upstream-manifest.txt` | This plugin | The SHA-256 of every file copied from upstream |
| `tests/test-english-writing.sh` | This plugin | The plugin's checks |
| `UPSTREAM-SKILL.md` | Upstream | The upstream `SKILL.md`: 26 patterns of AI-sounding prose, how to rewrite each, and when not to act |
| `LICENSE` | Upstream | The upstream MIT license |

## The checks

| Check | Reads | Prints |
|---|---|---|
| `suspects.py` | The Markdown or text files passed to it, and `references/translationese.tsv` | For each file, one line per suspect with its line number, kind, words, and a note, then the count of each of three kinds. It exits 0 whatever it finds, 2 when a file is missing, and 1 when the phrase list is broken |
| proselint 0.16.0 | The file passed to it, and the first settings file that exists of `/etc/proselintrc`, `~/.proselintrc.json`, `~/.config/proselint/config.json`, and `.proselintrc.json` in the current folder | JSON with one diagnostic per finding: the check, the message, and the line and column. It exits 1 when it finds something |

`suspects.py` reads only the prose.
It skips front matter, fenced code, inline code, HTML comments, link targets, and URLs.
It points at a sentence of more than 25 words as long.
Code, a command, a path, and a URL each count as one word.
Neither check writes a file.

## What it runs and connects to

- `suspects.py` runs as `python3 <skill folder>/scripts/suspects.py <file>` and imports only the Python standard library
- proselint runs as `uv run --with proselint==0.16.0 proselint check --output-format json <file>`. On first use, `uv` downloads proselint 0.16.0 and its dependencies `google-re2` and `google-re2-stubs` from the Python Package Index into its cache. The cache is `~/.cache/uv` on macOS and Linux unless `UV_CACHE_DIR` names another folder. When no fitting Python is found, `uv` may download one
- Without `uv`, the agent skips proselint and checks set phrases, hedging, and vague words by eye with `references/rules.md`
- The plugin never sends your text anywhere. The checks read local files and print to the terminal
- Left out from upstream: `scripts/validate-package.py`, which checks the upstream package itself, and the upstream repository's manifests, documents, and settings

## What it keeps

Nothing.
The agent puts intermediate files in a temporary folder outside your project and deletes them when it finishes.
proselint stays in uv's cache until you run `uv cache clean`.

## Updating the upstream copy

Copy only the upstream files, so that the plugin's own files stay as they are.

1. Fetch `blader/humanizer` at the new commit into an empty folder
2. Copy its `SKILL.md` as `UPSTREAM-SKILL.md` and its `LICENSE` into the skill folder. Leave out `scripts/` and the repository's other files
3. In the skill folder, rebuild the fingerprints and replace the fingerprint lines with the output. Keep the `#` lines, and change the commit on the `# Source:` line

   ```bash
   grep -E '^[0-9a-f]{64}  ' upstream-manifest.txt | cut -c67- | LC_ALL=C sort | while IFS= read -r f; do shasum -a 256 "$f"; done
   ```

4. Read the difference in `UPSTREAM-SKILL.md`, and fix `references/rules.md` and `SKILL.md` where they no longer match it
5. Change the commit and the dates in `THIRD_PARTY_NOTICES.md`, and `COMMIT` in `tests/test-english-writing.sh`
6. Run `bash skills/english-writing/tests/test-english-writing.sh` from the plugin folder
