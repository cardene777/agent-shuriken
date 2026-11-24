# Changelog

Releases of the remotion-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- One skill, `remotion-frame-checks`, that holds four contracts for the frames of a Remotion explainer video and provides them and their checks to other skills through musubi
- The SVG geometry check keeps connectors on the ports of their targets, elements apart by their minimum, and moving things on their target at the arrival frame
- The layout check keeps elements in the safe area, out of the subtitle zone, apart, aligned, and clear of the routes of moving things, and can write the audit files of a review
- The timing boundary check reads the PNG frames rendered around the start or end of an element with Node.js's own zlib, and finds pixels that show too early or too late, flashes of three frames or fewer, flicker, and boundary frames left out
- The scene layers check makes every scene decide its form, composition, typography, and motion apart, and refuses two scenes in a row with the same design
- The checks run on Node.js 18 or later with its built-in modules only, and the README states that Remotion itself comes under the Remotion License
