# Changelog

Releases of the dragon-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The dragon-explainer plugin writes an explainer as one HTML file with a figure in every section. It starts from the content JSON, the build, and the checks of diagram-explainer, and adds a `dragon` block: the block names a `.dragon` notation file next to the content JSON, `render.py` writes it as a still dragon block with its caption, refusing a file that is missing, lies outside the content folder, or is not `.dragon`, and `dragon embed` draws it as an SVG so the finished page reads nothing from the network. The skill runs `dragon check` and `dragon check --layout` on every notation file and `dragon embed` after the build, with dragon pinned at 0.80.1, and the English and Japanese samples carry a dragon figure. The rest of the document is the same as diagram-explainer's: one section at a time from a contents list, a facts table under the title, page tabs in the header band for two or more topics, an enlarge button on every figure, a language and a light or dark switch, a Save PDF button, and, when design-formats is installed, the user's colors and fonts from `.design-theme.json`
