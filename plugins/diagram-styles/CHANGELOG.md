# Changelog

Releases of the diagram-styles plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.2.0] - 2026-11-21

- `article-diagram-styles` ships sixteen built-in styles in four families, each defined in words with the kinds of figures it suits, and draws in them without `~/.styles/`. It draws in the style you name, or picks one from the article and tells you which and why, falling back to `handdraft`. Your catalog in `~/.styles/` adds styles beside the built-in styles, replaces a built-in style of the same name, or retires one with `"status": "retired"`. `diagram_sample_catalog.py` gains `--list` and `--show`, and `style-catalog` and `figure-request` move to version 1.1.0. `tech-book-figure` still needs your style4 samples

## [0.1.0] - 2026-11-21

- The `article-diagram-styles` skill designs a figure for an article from the reader's question before opening any style sample, applies a style from your catalog `~/.styles/style-catalog.json`, draws the figure with the image generation of the agent running it, and checks the text, the connections, and the readability at the published width with its own scripts
- The `tech-book-figure` skill designs a figure for a technical book with its role, figure number, caption, alternative text, and black and white readability, and draws it in the fixed style4 from at least two of your samples in `~/.styles/diagram-style-samples/style4/`
- The plugin ships no sample images. Both skills read the catalog and the samples from `~/.styles/`, stop before drawing when they are missing, and write figures and records only in the folder you name. `diagram_sample_catalog.py --validate` reads a version 2 catalog, refuses version 1 and `resources`, and names every image whose SHA-256 differs, every wrong count, and every image the catalog does not name
- Without image generation, both skills save the content summary, the figure spec, and the drawing instructions and stop, so the same skill can draw them later in an agent that has image generation. A figure spec drawn by image generation has `rendering_mode: generated`
- `article-diagram-styles` provides `style4`, `figure-request`, and `style-catalog` through musubi, and `tech-book-figure` follows `article-diagram-styles/style4`
- The font Kaisei Decol Bold ships with its license for figures drawn from HTML or SVG source

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/diagram-styles--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-styles--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-styles--v0.1.0
