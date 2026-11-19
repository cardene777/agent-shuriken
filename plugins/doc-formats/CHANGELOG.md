# Changelog

Releases of the doc-formats plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-19

First public release.

- The `design-doc` skill holds the format of a design document: a title, an intro, the sentence on how sections point to each other, the place for the following skill's own sections, and Open decisions last. Skills follow it through musubi, which pins its version and fingerprint
- `design-doc.py verify` takes the following skill's sections file and names each section of a design that is missing, out of order, empty, or still holding a `Fill in:` line, a dated section without a real date, and a cited decision ID the Open decisions table does not define, without printing the design's text. It refuses a sections file with no sections or with Open decisions in it

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/doc-formats--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/doc-formats--v0.1.0
