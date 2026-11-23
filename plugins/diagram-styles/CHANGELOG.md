# Changelog

Releases of the diagram-styles plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- `tech-book-figure` draws from the written style4 rules without `~/.styles/`, instead of stopping. `references/style4.md` now writes the look in words that are enough to draw, and the provided `style4` moves to version 1.1.0. Your style4 samples are passed as references only when the catalog and two or more samples are there, and the skill tells you which of the two it drew from and what was missing. A theme file, `.design-theme.json` at the root of your repository or `~/.design-theme.json`, in the format of the design-formats theme file, replaces the ground, the ink, the gray, the first accent and its fill, and the handwritten letters with your colors and typeface; a file with an unknown key or a bad value is refused with each key named, and the skill stops before drawing. The new `scripts/book_style.py` tells the skill which of these applies

## [0.3.0] - 2026-11-21

- `article-diagram-styles` ships thirty-two built-in styles in eight families, adding `dimensional` (`low-poly`, `papercraft`, `diorama`, `toy-blocks`), `notebook-and-archive` (`notebook-doodle`, `grid-memo`, `patent-drawing`, `old-map`), `ink-and-print` (`sumi-e`, `risograph`, `copperplate`, `paper-cut`), and `signs-and-screens` (`pictogram`, `metro-map`, `terminal-screen`, `sticker`). The definitions of `flat-vector`, `isometric`, `minimal`, and `comic-panel` now name what they forbid: a gradient anywhere, an oblique view, a second place for the accent color, and decoration unrelated to the content
- `article-diagram-styles` ships sixteen built-in structures in four groups, `flow-and-order`, `structure-and-containment`, `comparison`, and `state-and-change`, each defined in words by the relation it shows, its parts, its reading order, and the subjects it fits and does not fit. The skill chooses the structure of each figure from the reader's question apart from the style and records it in `structure`, and `validate_composition_ledger.py` refuses a figure without a structure in use. When you ask to compare the same content in different structures, it draws as many as you ask for, three without a number, in the `structure-comparison` mode. `diagram_sample_catalog.py` gains `--structures` and `--show-structure`, your catalog may add, replace, or retire structures under `structures`, and `style-catalog` and `figure-request` move to version 1.2.0

## [0.2.0] - 2026-11-21

- `article-diagram-styles` ships sixteen built-in styles in four families, each defined in words with the kinds of figures it suits, and draws in them without `~/.styles/`. It draws in the style you name, or picks one from the article and tells you which and why, falling back to `handdraft`. Your catalog in `~/.styles/` adds styles beside the built-in styles, replaces a built-in style of the same name, or retires one with `"status": "retired"`. `diagram_sample_catalog.py` gains `--list` and `--show`, and `style-catalog` and `figure-request` move to version 1.1.0. `tech-book-figure` still needs your style4 samples

## [0.1.0] - 2026-11-21

- The `article-diagram-styles` skill designs a figure for an article from the reader's question before opening any style sample, applies a style from your catalog `~/.styles/style-catalog.json`, draws the figure with the image generation of the agent running it, and checks the text, the connections, and the readability at the published width with its own scripts
- The `tech-book-figure` skill designs a figure for a technical book with its role, figure number, caption, alternative text, and black and white readability, and draws it in the fixed style4 from at least two of your samples in `~/.styles/diagram-style-samples/style4/`
- The plugin ships no sample images. Both skills read the catalog and the samples from `~/.styles/`, stop before drawing when they are missing, and write figures and records only in the folder you name. `diagram_sample_catalog.py --validate` reads a version 2 catalog, refuses version 1 and `resources`, and names every image whose SHA-256 differs, every wrong count, and every image the catalog does not name
- Without image generation, both skills save the content summary, the figure spec, and the drawing instructions and stop, so the same skill can draw them later in an agent that has image generation. A figure spec drawn by image generation has `rendering_mode: generated`
- `article-diagram-styles` provides `style4`, `figure-request`, and `style-catalog` through musubi, and `tech-book-figure` follows `article-diagram-styles/style4`
- The font Kaisei Decol Bold ships with its license for figures drawn from HTML or SVG source

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/diagram-styles--v0.3.0...HEAD
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-styles--v0.3.0
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-styles--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-styles--v0.1.0
