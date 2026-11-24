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
- A second skill, `remotion-motion-plan`, that plans how the scenes of a Remotion explainer video move before the rough cut, and provides its choreography, continuous choreography, motion language, and motion evidence contracts and their checks through musubi
- The choreography check makes every scene bring an object in when it is needed and change a state, and keeps the rough cut's camera, routes, and handoffs the same as the final cut's
- The continuous choreography check makes every scene take over the subject the scene before it handed on, instead of clearing the screen, and keeps a summary to the objects shown before it
- The motion language check makes every scene rest its main recipe on a watched video of the user's motion evidence library, kept in `~/.local/share/remotion-explainer/` or the folder `REMOTION_EXPLAINER_HOME` names, and the evidence check refuses a verified entry without a time range
- A third skill, `remotion-catalog`, that fetches the outside Remotion examples listed in `data/sources.json`, each at a pinned commit and under a license that allows the use, into the data folder with `git`, and searches them by form, composition, typography, or motion, one layer at a time
- The catalog leaves out a source whose commit is not a full hash, whose license is not one that allows the use, or whose license evidence is missing at that commit, never runs code from a source, and never follows a symbolic link in it
- The catalog lists `reactvideoeditor/remotion-templates` under MIT and `Vincentwei1021/video-shotcraft` under Apache-2.0, without the sounds of the latter, and `THIRD_PARTY_NOTICES.md` records their commits and license evidence
