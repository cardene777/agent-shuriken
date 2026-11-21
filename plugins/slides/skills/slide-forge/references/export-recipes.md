# Export recipes

The command for each format of phase 3, with a one-line fix for each common failure.
`S` is the `scripts/` folder next to `SKILL.md`, and the deck folder is `decks/<deck-name>/` in the user's project.
uv fetches python-pptx, Pillow, and Playwright into its own cache for each run, so nothing is installed into the user's Python.

## PowerPoint

```bash
uv run --with python-pptx --with Pillow --no-project python3 "$S/build_pptx.py" decks/<deck-name>/content.json decks/<deck-name>/<deck-name>.pptx --theme deep-navy
```

| Failure | Fix |
|---|---|
| `uv: command not found` | Install uv, for example with `brew install uv` or `pipx install uv`, then run the command again |
| `python-pptx is not available` | The script was run with plain `python3`. Run it through `uv run --with python-pptx --with Pillow` as above |
| A stretched photo | The centered square crop did not run (`references/pptx-build-spec.md`, "Crop photos to a centered square") |
| Overlapping bullets | `chars_per_line` is too high for the font and box. Lower it from 30 to 25 |
| Replaced fonts (another font on Windows) | Pin `run.font.name` and the `latin`, `ea`, and `cs` elements to Hiragino Sans (`references/pptx-build-spec.md`, "Pin the font") |

## PDF (Playwright's Chromium)

```bash
# The browser, once, only when the user agrees (about 150 MB)
uv run --with playwright --no-project python3 -m playwright install chromium

# The PDF
uv run --with playwright --no-project python3 "$S/export_pdf.py" decks/<deck-name>/<deck-name>.html decks/<deck-name>/<deck-name>.pdf
```

`export_pdf.py` prints each page at 1280 x 720 px with backgrounds.
When the browser is not installed, it writes nothing, prints the install command, and exits 3, and `scripts/export_all.sh` then skips only the PDF.
Neither script downloads the browser.

| Failure | Fix |
|---|---|
| `Playwright's Chromium browser is not installed` | Ask the user, and run the install command above when they agree |
| The PDF does not match the screen | Make the slide page exactly 1280 x 720 px, the size `export_pdf.py` prints |
| Japanese text shows as boxes on Windows or Linux | The machine has no Hiragino Sans. Add a fallback font such as Noto Sans CJK JP to the page's CSS |

## Public HTML

```bash
python3 "$S/export_html_final.py" decks/<deck-name>/edit-mode.html decks/<deck-name>/<deck-name>.html
```

Writes the public page without the toolbar, its dictionary, and its script.
The `contenteditable` attributes stay: a viewer who edits the public page changes only their own view.

| Failure | Fix |
|---|---|
| The toolbar is still there | Check that the toolbar sits between `<!-- slide-forge-inject-start -->` and `<!-- slide-forge-inject-end -->`, the markers `inject_edit_mode.py` writes |
| The script is still there | The same markers surround the script and dictionary in `<head>` |

## All three formats (`scripts/export_all.sh`)

```bash
bash "$S/export_all.sh" decks/<deck-name> --theme deep-navy
# Reads content.json and edit-mode.html in the deck folder, and writes
# <deck-name>.pptx, <deck-name>.html, and <deck-name>.pdf next to them.
```

The deck folder's name is the deck name, so all files of a deck stay in `decks/<deck-name>/`.

| Situation | What happens |
|---|---|
| uv is not installed | Nothing is written. The script prints how to install uv and exits 1 |
| Playwright's Chromium is not installed | The PowerPoint and HTML files are written, the PDF is skipped with the install command, and the exit code is 0 |
| `edit-mode.html` is missing | The PowerPoint file is written, and the HTML and PDF are skipped |
| The PDF fails for another reason | The PowerPoint and HTML files are written, and the exit code is 1 |

## Common problems

- Garbled text in PowerPoint (`???`): check that `content.json` is UTF-8 (`file -I content.json`)
- A missing photo: check the path in `avatar` in `content.json`. A base64 data URL is written to a temporary file first

## Related files

- `scripts/export_all.sh`, which runs these recipes
- `scripts/build_pptx.py`, `scripts/export_pdf.py`, `scripts/inject_edit_mode.py`, and `scripts/export_html_final.py`
