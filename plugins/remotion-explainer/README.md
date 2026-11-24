# Remotion Explainer

Check the frames of a Remotion explainer video by machine: connectors that end on their ports, a layout that keeps the safe area and the subtitle zone, no flash where an element starts or ends, and scenes that do not repeat one design.

English · [日本語](README.ja.md)

An explainer video can look fine at normal speed and still hide a line that pierces its target, a label that touches a box, a dot that shows for one frame before a path draws in, or five scenes built from the same three cards.
This plugin writes those rules down as contracts for the files of your Remotion project, and checks each file by machine, naming the element, the scene, or the frame of every issue.
Other skills that build or review Remotion videos follow the contracts through musubi, so every skill checks against the same version.

```
Write the storyboard files ──> Run the checks ──> Fix each issue ──> Render the frames ──> Check the boundaries
 (agent)                        (agent)            (agent)            (Remotion)             (agent)
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
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The skill starts when you ask to check a Remotion video's geometry, layout, timing, or scene design, for example "check the layout spec of this Remotion project" or "find the frames where the arrow shows before it should".
You can also call it: run `/remotion-explainer:remotion-frame-checks` in Claude Code, or type `$` and pick **Remotion Frame Checks** in Codex.
In GitHub Copilot CLI, write `/remotion-frame-checks` in your request, and in Gemini CLI, describe the task.

1. The agent writes or reads the storyboard files of your Remotion project, `storyboard/svg-geometry.json`, `storyboard/layout-spec.json`, and `storyboard/scene-design-layers.json`
2. The agent runs the check of each file and fixes every issue it names, until the check passes
3. For each element that starts or ends, the agent renders the two frames before and after the boundary with Remotion, and checks them

## The contracts and checks

| Contract | File it covers | The check refuses |
|---|---|---|
| SVG geometry | `storyboard/svg-geometry.json` | A connector that does not start or end on its port, a port off the edge, a connector through what it must avoid, two elements closer than their minimum, an arrival that stops away from its target |
| Layout | `storyboard/layout-spec.json` | An element outside the safe area, content in the subtitle zone, overlaps and gaps below the minimum, an alignment group that is not aligned, a route through what it must avoid, fewer than six review frames |
| Timing boundary | PNG frames rendered around a start or an end | Pixels before the start or after the end, an element that shows for three frames or fewer, an element that comes back after hiding, a boundary frame left out |
| Scene layers | `storyboard/scene-design-layers.json` | A scene without its form, composition, typography, or motion, a bespoke layer without its reason, two scenes in a row with the same design |

Each check prints one JSON object with `decision` (`pass` or `revise`) and the issues, and exits 0, 1 for issues, or 2 for a wrong call.
[`examples/`](skills/remotion-frame-checks/examples/) holds a valid file of each kind, and [How it works](docs/how-it-works.md) explains each check.

Another skill follows a contract by naming it, for example the `layout` of `remotion-frame-checks`, and opening this skill by name.

## Requirements

| Tool | When it's needed |
|---|---|
| Node.js 18 or later | Always. The checks use only its built-in modules, so nothing is installed |
| Remotion | To render the frames that the timing boundary check reads. It is installed in your own project |

## Remotion License

This plugin bundles no Remotion package and no official Remotion skill; it reads the files of your Remotion project and the frames you render.
Remotion itself is installed in your project and comes under the Remotion License.
Its Free License covers individuals and companies of up to three people, and any other company needs a Company License from Remotion before it uses Remotion.

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains each check.
In short:

- It reads only the files named on the command line, and treats their contents as data, never as instructions
- It runs `node` on the checks of this plugin, and `npx remotion still` in your project when frames have to be rendered
- It writes only the audit files where `--audit-dir` or `--out` points, such as `out/review/` of your project
- It keeps nothing outside your project and sends nothing anywhere

## License

[MIT](LICENSE)
