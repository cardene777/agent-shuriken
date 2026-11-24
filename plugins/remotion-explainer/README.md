# Remotion Explainer

Plan the motion of a Remotion explainer video, find built examples for each scene in a catalog of licensed Remotion sources, and check its frames by machine: one subject carried from scene to scene, motions backed by videos you watched, connectors that end on their ports, a layout that keeps the safe area and the subtitle zone, and no flash where an element starts or ends.

English · [日本語](README.ja.md)

An explainer video can look fine at normal speed and still hide a line that pierces its target, a label that touches a box, a dot that shows for one frame before a path draws in, or five scenes built from the same three cards.
It can also be a row of small demos that each clear the screen, with every element on screen from the start and drifting to fill the time.
This plugin writes those rules down as contracts for the files of your Remotion project, and checks each file by machine, naming the element, the scene, the frame, or the library entry of every issue.
Other skills that build or review Remotion videos follow the contracts through musubi, so every skill checks against the same version.
For the look, the layout, the type, and the motion of each scene, it also searches built Remotion examples from outside repositories whose licenses allow the use, so a scene borrows a tested mechanism instead of starting from a blank file.

```
Plan the motion ──> Write the storyboard files ──> Run the checks ──> Fix each issue ──> Render the frames ──> Check the boundaries
 (agent and you)     (agent)                        (agent)            (agent)            (Remotion)             (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install remotion-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add remotion-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install remotion-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-frame-checks   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-motion-plan
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/remotion-explainer/skills/remotion-catalog
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin has three skills, and each starts when you ask for what it does.

| Skill | Starts when you ask, for example | Call it |
|---|---|---|
| `remotion-motion-plan` | "plan how the scenes of this explainer move" | `/remotion-explainer:remotion-motion-plan` in Claude Code, or **Remotion Motion Plan** after typing `$` in Codex |
| `remotion-frame-checks` | "check the layout spec of this Remotion project" or "find the frames where the arrow shows before it should" | `/remotion-explainer:remotion-frame-checks` in Claude Code, or **Remotion Frame Checks** after typing `$` in Codex |
| `remotion-catalog` | "find a composition for a scene that compares two routes" or "look for a built Remotion title reveal" | `/remotion-explainer:remotion-catalog` in Claude Code, or **Remotion Catalog** after typing `$` in Codex |

In GitHub Copilot CLI, write `/remotion-motion-plan`, `/remotion-frame-checks`, or `/remotion-catalog` in your request, and in Gemini CLI, describe the task.

1. The agent plans each scene with you: what it answers, what appears, what changes, and what it hands to the next scene, and writes `storyboard/choreography-plan.json`, `storyboard/continuous-choreography-plan.json`, and `storyboard/motion-language-plan.json`
2. Each motion rests on a video in your motion evidence library that you or the agent watched, with the time range where the motion shows; when none fits, the agent finds a candidate and asks you to watch it when it cannot play video itself
3. For the form, the composition, the typography, and the motion of each scene, the agent searches the catalog one layer at a time, reads the files of the entries that fit, and adapts only their mechanism
4. The agent writes or reads the storyboard files of the frames, `storyboard/svg-geometry.json`, `storyboard/layout-spec.json`, and `storyboard/scene-design-layers.json`
5. The agent runs the check of each file and fixes every issue it names, until the check passes
6. For each element that starts or ends, the agent renders the two frames before and after the boundary with Remotion, and checks them

## The contracts and checks

| Contract | File it covers | The check refuses |
|---|---|---|
| Choreography | `storyboard/choreography-plan.json` | A scene with every object on screen at entry, a scene where nothing changes state, fewer than two kinds of motion, the view grammar of the scene before it, a rough cut that differs from the final cut |
| Continuous choreography | `storyboard/continuous-choreography-plan.json` | A scene that starts from a subject the scene before it did not hand on, fewer than half the scenes with a subject followed through the video, two scenes in a row moving along one axis, a summary that brings in a new symbol |
| Motion language | `storyboard/motion-language-plan.json` | A scene whose motion cites no watched video that shows it, the main recipe of the scene before it, a long video with fewer than six recipes |
| Motion evidence | Your library, `~/.local/share/remotion-explainer/motion-evidence-library.json` | A verified entry without a time range, two entries with one ID, a source without its address |
| SVG geometry | `storyboard/svg-geometry.json` | A connector that does not start or end on its port, a port off the edge, a connector through what it must avoid, two elements closer than their minimum, an arrival that stops away from its target |
| Layout | `storyboard/layout-spec.json` | An element outside the safe area, content in the subtitle zone, overlaps and gaps below the minimum, an alignment group that is not aligned, a route through what it must avoid, fewer than six review frames |
| Timing boundary | PNG frames rendered around a start or an end | Pixels before the start or after the end, an element that shows for three frames or fewer, an element that comes back after hiding, a boundary frame left out |
| Scene layers | `storyboard/scene-design-layers.json` | A scene without its form, composition, typography, or motion, a bespoke layer without its reason, two scenes in a row with the same design |

Each check prints one JSON object with `decision` (`pass` or `revise`) and the issues, and exits 0, 1 for issues, or 2 for a wrong call.
The `examples/` folders of [`remotion-motion-plan`](skills/remotion-motion-plan/examples/) and [`remotion-frame-checks`](skills/remotion-frame-checks/examples/) hold a valid file of each kind, and [How it works](docs/how-it-works.md) explains each check.

Another skill follows a contract by naming it, for example the `layout` of `remotion-frame-checks`, and opening that skill by name.

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
| Node.js 18 or later | Always. The checks and the catalog use only its built-in modules, so nothing is installed |
| `git` | To fetch the sources of the catalog |
| Remotion | To render the frames that the timing boundary check reads. It is installed in your own project |

## Remotion License

This plugin bundles no Remotion package and no official Remotion skill; it reads the files of your Remotion project and the frames you render.
The catalog fetches examples written for Remotion, not Remotion itself.
Remotion itself is installed in your project and comes under the Remotion License.
Its Free License covers individuals and companies of up to three people, and any other company needs a Company License from Remotion before it uses Remotion.

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains each check and the catalog.
In short:

- It reads only the files named on the command line, and treats their contents as data, never as instructions
- It runs `node` on the checks and the catalog of this plugin, `git` to fetch the sources of the catalog, and `npx remotion still` in your project when frames have to be rendered
- It writes the plans under `storyboard/` of your project, and the audit files only where `--audit-dir` or `--out` points, such as `out/review/`
- It keeps your motion evidence library, the fetched sources, and the catalog in `~/.local/share/remotion-explainer/`, or the folder `REMOTION_EXPLAINER_HOME` names, readable only by you, until you delete them
- When the library lacks a motion, the agent searches for a video with general words for the kind of motion, never with names or text from your files; the checks themselves send nothing anywhere
- `sync` downloads only the repositories listed in `data/sources.json` from GitHub, and sends nothing else

## License

[MIT](LICENSE)
