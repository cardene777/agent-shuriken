# Third-party notices

This plugin includes the following third-party material.
Every data file the plugin bundles is listed here, including the one written for the plugin itself, the built-in styles.

## Kaisei Decol

| Item | Value |
|---|---|
| File in this plugin | `skills/article-diagram-styles/data/fonts/KaiseiDecol-Bold.ttf` |
| File in this plugin | `skills/article-diagram-styles/data/fonts/OFL.txt` |
| Source | Kaisei Decol Bold of the Kaisei typeface family (https://github.com/Font-Kai/Kaisei), copied from `ofl/kaiseidecol/` in https://github.com/google/fonts |
| Commit | `2cf929ff0bb4428b0cb43920004d1e1127706b4d` |
| SHA-256 of the font | `0e3a6da5145fdbba32cfb1c806812d95457506e1698f5d61e8f834fb847f0d6f` |
| Copied on | 2026-11-21 |
| License | SIL Open Font License 1.1 |

The font and its license text are unmodified copies.
`scripts/newsprint_finish.py` returns the font's path for figures drawn from HTML or SVG source, so that their letters are drawn from a real font file instead of one installed on the machine.
To update it, replace the font with a newer release of the Kaisei family, keep `OFL.txt` from the same release beside it, and update the commit, hash, and date above.

Copyright 2020 The Kaisei Project Authors.

## The built-in styles

| Item | Value |
|---|---|
| File in this plugin | `skills/article-diagram-styles/data/built-in-styles.json` |
| Source | Written for this plugin. It holds the written specifications of the sixteen built-in styles and no image |
| License | MIT, as the plugin's [LICENSE](LICENSE) |
