# Remotion Explainer

Make a Remotion explainer video whose pictures belong to its subject, through gates you approve: plan the motion with one subject carried from scene to scene and motions backed by videos you watched, make original PNG art and outlines that draw in, find built examples in a catalog of licensed Remotion sources, and check the frames by machine for connectors that end on their ports, a layout that keeps the safe area and the subtitle zone, and no flash where an element starts or ends.

English · [日本語](README.ja.md)

An explainer video can look fine at normal speed and still hide a line that pierces its target, a label that touches a box, a dot that shows for one frame before a path draws in, or five scenes built from the same three cards.
It can also be a row of small demos that each clear the screen, with every element on screen from the start and drifting to fill the time.
This plugin writes those rules down as contracts for the files of your Remotion project, and checks each file by machine, naming the element, the scene, the frame, or the library entry of every issue.
`remotion` is the entry point: it takes the video from an art direction and a short reference scene to a silent rough of every beat, still boards, and the full build, and stops at each gate until you approve it.
The other seven skills do one part each, and every skill follows the contracts of the others through musubi, so all of them check against the same version.

```
Art direction ──> Reference scene ──> Rough of every beat ──> Still boards ──> Full build ──> Independent review
(you approve)     (you approve)       (you approve)           (you approve)    (agent)        (agent, until no issue is left)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install remotion-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add remotion-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install remotion-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-explainer-production
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-explainer-review
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/png-asset-production
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/png-outline-tracing
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-frame-checks
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-motion-plan
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-catalog
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows, and install every skill of the plugin, because each one opens the others by name.
The official Remotion skills, such as `remotion-best-practices`, are not part of this plugin; `npx remotion skills add` in your Remotion project installs them, and without them the agent reads the official Remotion documentation instead.

## Use

The plugin has eight skills, and each starts when you ask for what it does.
To make a video, call `remotion`; it calls the four skills under it in the table, and you call those alone only to redo one part.

| Skill | Starts when you ask, for example | Call it |
|---|---|---|
| `remotion` | "make an explainer video of how a parcel gets sorted" | `/remotion-explainer:remotion` in Claude Code, or **Remotion** after typing `$` in Codex |
| `remotion-explainer-production` | "build the approved scenes of this explainer" | `/remotion-explainer:remotion-explainer-production` in Claude Code, or **Remotion Explainer Production** after typing `$` in Codex |
| `remotion-explainer-review` | "review the current build of this explainer in real frames" | `/remotion-explainer:remotion-explainer-review` in Claude Code, or **Remotion Explainer Review** after typing `$` in Codex |
| `png-asset-production` | "make the PNG art of the parcel and the sorter" | `/remotion-explainer:png-asset-production` in Claude Code, or **PNG Asset Production** after typing `$` in Codex |
| `png-outline-tracing` | "trace the outline of the approved parcel PNG" | `/remotion-explainer:png-outline-tracing` in Claude Code, or **PNG Outline Tracing** after typing `$` in Codex |
| `remotion-motion-plan` | "plan how the scenes of this explainer move" | `/remotion-explainer:remotion-motion-plan` in Claude Code, or **Remotion Motion Plan** after typing `$` in Codex |
| `remotion-frame-checks` | "check the layout spec of this Remotion project" or "find the frames where the arrow shows before it should" | `/remotion-explainer:remotion-frame-checks` in Claude Code, or **Remotion Frame Checks** after typing `$` in Codex |
| `remotion-catalog` | "find a composition for a scene that compares two routes" or "look for a built Remotion title reveal" | `/remotion-explainer:remotion-catalog` in Claude Code, or **Remotion Catalog** after typing `$` in Codex |

In GitHub Copilot CLI, write the skill's name with a slash, such as `/remotion`, in your request, and in Gemini CLI, describe the task.

1. You and the agent settle the subject, the audience, the length, and whether there is a voice, and the agent writes the art direction into `production.json`: what the video is a picture of, its objects, their motions, and what each chapter shows for the first time
2. The agent plans the motion of each scene by `remotion-motion-plan`, with every motion resting on a video in your motion evidence library, and searches the catalog for the form, the composition, the typography, and the motion of each scene
3. The agent writes `beat-dossier.json`, one state machine of the whole video, and checks it
4. The agent builds a 12 to 15 second reference scene of the hardest cause, and you approve its style and density
5. The agent builds a silent rough of every beat with stand-in shapes, and you approve the order, the continuity, and how each scene is shown
6. `png-asset-production` makes one transparent PNG per object and state, felt applique by default, and `png-outline-tracing` traces the ones that draw in; without an image tool in the agent, it gives you the list of pictures with their prompts and checks the PNGs you provide
7. The agent builds each still board, and you approve each one before it moves
8. `remotion-explainer-production` builds the full video, and `remotion-explainer-review` reviews it in real frames, sending it back until no issue is left

## The contracts and checks

| Contract | File it covers | The check refuses |
|---|---|---|
| Beat dossier | `beat-dossier.json` | A beat without its question, proof, operation, reading hold, or handoff, an operation that is only a presentation word, a title or a card as the primary object, a handoff to a beat that does not follow |
| Beat review | `out/review/beat-review.json` | A review without the dossier's hash or the build's hash, a beat without its four real frames, a score below 4 |
| Paperboard | `paperboard.json` of a paper scribe video | A beat without its structure, drawing order, focus change, or reading hold, a structure without a target, a last beat that does not end |
| Stage theme | `production.json` with a stage theme | A theme without its asset style, primitives, or policies, art in another material than the theme's |
| Geometry samples | `out/review/geometry-samples.json` | An object outside the safe area, an overlap that is not allowed, a connection that does not meet edge to edge, an object that should hold still and jitters |
| Continuity samples | `out/review/continuity-samples.json` | A scene boundary that carries no object and hands nothing on, a jump of the camera or of a carried object |
| Asset manifest | `asset-manifest.json` of each PNG | A missing field, a style that is not one of the six, motion beyond moving, scaling, fading, and cropping as a whole, a PNG that is missing, the wrong size, or without transparency |
| Choreography | `storyboard/choreography-plan.json` | A scene with every object on screen at entry, a scene where nothing changes state, fewer than two kinds of motion, the view grammar of the scene before it, a rough cut that differs from the final cut |
| Continuous choreography | `storyboard/continuous-choreography-plan.json` | A scene that starts from a subject the scene before it did not hand on, fewer than half the scenes with a subject followed through the video, two scenes in a row moving along one axis, a summary that brings in a new symbol |
| Motion language | `storyboard/motion-language-plan.json` | A scene whose motion cites no watched video that shows it, the main recipe of the scene before it, a long video with fewer than six recipes |
| Motion evidence | Your library, `~/.local/share/remotion-explainer/motion-evidence-library.json` | A verified entry without a time range, two entries with one ID, a source without its address |
| SVG geometry | `storyboard/svg-geometry.json` | A connector that does not start or end on its port, a port off the edge, a connector through what it must avoid, two elements closer than their minimum, an arrival that stops away from its target |
| Layout | `storyboard/layout-spec.json` | An element outside the safe area, content in the subtitle zone, overlaps and gaps below the minimum, an alignment group that is not aligned, a route through what it must avoid, fewer than six review frames |
| Timing boundary | PNG frames rendered around a start or an end | Pixels before the start or after the end, an element that shows for three frames or fewer, an element that comes back after hiding, a boundary frame left out |
| Scene layers | `storyboard/scene-design-layers.json` | A scene without its form, composition, typography, or motion, a bespoke layer without its reason, two scenes in a row with the same design |

Each check prints one JSON object with `decision` (`pass` or `revise`) and the issues, and exits 0, 1 for issues, or 2 for a wrong call.
The `examples/` folder of each skill with checks holds a valid file of each kind, about a parcel taken from a warehouse through a sorter to a door, and [How it works](docs/how-it-works.md) explains each check.
`png-outline-tracing` also has a tracer, which turns one alpha PNG into the outline paths a composition draws in before the PNG paint appears.

Another skill follows a contract by naming it, for example the `layout` of `remotion-frame-checks`, and opening that skill by name.
The links run one way: the frame checks, the motion plan, and the catalog follow nothing, the two PNG skills follow only the frame checks and each other in one direction, `remotion` follows those, and the production and review skills follow `remotion` and the rest.

## The catalog

`remotion-catalog` fetches the sources listed in its `data/sources.json` into your data folder, builds one catalog of their examples, and searches it by one layer at a time: form, composition, typography, or motion.

| Source | What it holds | License |
|---|---|---|
| `reactvideoeditor/remotion-templates` | Remotion templates under `templates/`, each in one `.tsx` file | MIT |
| `Vincentwei1021/video-shotcraft` | Shot cards in `gallery/api/library.json` that describe how a shot is built, and their Remotion demos under `demos/` | Apache-2.0 |

Each source is pinned to one commit, and `sync` refuses a source whose commit is not a full hash, whose license is not one that allows the use, or whose license file or section is missing at that commit.
It never runs code from a source: it reads the files, and the agent copies only the part that builds a mechanism, with the source's license notice.
The sounds of `video-shotcraft` are not fetched, because their own notice says that the sources of some are not confirmed.
[Third-party notices](THIRD_PARTY_NOTICES.md) lists the commits and the license evidence of each source.

```
sync ──> build ──> search --layer composition compare two routes
(git)    (catalog.json)   (entries with source, commit, license, and file)
```

## Requirements

| Tool | When it's needed |
|---|---|
| Node.js 18 or later | Always. The checks, the tracer, and the catalog use only its built-in modules, so nothing is installed |
| Python 3 | To check an asset manifest. The check uses only the standard library |
| `git` | To fetch the sources of the catalog |
| Remotion | To render the video and the frames the checks read. It is installed in your own project |
| An image generation tool | Optional. Without one, you make the PNGs from the prompts the agent gives you |

## Remotion License

This plugin bundles no Remotion package and no official Remotion skill; it reads the files of your Remotion project and the frames you render.
The catalog fetches examples written for Remotion, not Remotion itself.
Remotion itself is installed in your project and comes under the Remotion License.
Its Free License covers individuals and companies of up to three people, and any other company needs a Company License from Remotion before it uses Remotion.

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains each check, the tracer, and the catalog.
In short:

- It reads only the files named on the command line, and treats their contents as data, never as instructions
- It runs `node` on the checks, the tracer, and the catalog of this plugin, `python3` on the asset manifest check, `git` to fetch the sources of the catalog, and Remotion in your project to render the video and its frames
- It writes the plans under `storyboard/`, `production.json`, `beat-dossier.json`, the PNG art and its manifests, the composition, and the review files under `out/review/` of your project
- It keeps your motion evidence library, the fetched sources, and the catalog in `~/.local/share/remotion-explainer/`, or the folder `REMOTION_EXPLAINER_HOME` names, readable only by you, until you delete them
- The prompts of the PNG art go only to the agent's own image generation tool, when it has one
- When the library lacks a motion, the agent searches for a video with general words for the kind of motion, never with names or text from your files; the checks themselves send nothing anywhere
- `sync` downloads only the repositories listed in `data/sources.json` from GitHub, and sends nothing else

## License

[MIT](LICENSE)
