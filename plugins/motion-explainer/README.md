# Motion Explainer

Explain how a mechanism works with a short video of one running example, and answer the details with figures drawn from the same art.

English · [日本語](README.ja.md)

A text explanation of a mechanism makes the reader put the order of events together, and a diagram shows the parts but not what happens to one case as it passes them.
This plugin plays one running example, such as one request or one parcel, from start to end as a short video: each scene changes one thing, a pixel-art speaker says one sentence about it in a speech bubble, only the parts that changed are marked, and an effect lands on the change.
For each subject the agent writes an art direction and draws the objects on the stage as SVG, so two subjects never share a look.
The speakers are a cast of one to four bodies the plugin ships (robot, android, guide, and drone), each with four poses: wait, explain, surprised, and cheer.
Figures under the video answer one question each, drawn from the same art.

```
Find the example ──> Art direction ──> Draw the art ──> Write the spec ──> Check ──> Page
 (agent)             (you and agent)    (agent)          (agent)            (agent)   (you)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install motion-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add motion-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install motion-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/motion-explainer/skills/motion-explainer   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for a short video that explains how something works, for example "explain how a cache answers a request as a short video" or "make an explainer video of how a parcel is delivered again".
You can also call it: run `/motion-explainer:motion-explainer` in Claude Code, or type `$` and pick **Motion Explainer** in Codex.
In GitHub Copilot CLI, write `/motion-explainer` in your request, and in Gemini CLI, describe the task.

1. The agent reads what you point at and picks one running example that passes the whole mechanism, split into scenes that change one thing each
2. The agent shows you the scenes and the art direction, and changes them until you agree
3. The agent casts a body for each speaker, and draws each part as SVG in that direction, with every state of a drawing in one file
4. The agent writes the spec with the figures, checks it, renders the page, and looks at it at a desktop width and a phone width before you open it

A scene in the spec looks like this.

```json
{ "id": "travel", "chapter": "Travel", "line": "So the request travels on to the origin server.",
  "speaker": "bit", "pose": "explain", "set": { "cache": "empty", "origin": "busy" }, "move": { "letter": [78, 0] } }
```

A part keeps its state and place from the scene before, so a scene names only what changes.
A scene can also name an effect, such as `"fx": { "burst": "cache", "word": "don" }`, which sets off a burst behind the cache with a sound-effect word.
`check` refuses a scene that names an unknown part, state, speaker, pose, or effect, a cast that repeats a body, a scene that changes nothing, text over its limit, and art that would load from outside or run a script, naming the field each time.
[The spec format](skills/motion-explainer/references/spec-format.md) lists every field, and [`examples/`](examples/) holds a spec in English with one speaker and one in Japanese with two, each with its own art.

## The page

| Part | What it does |
|---|---|
| Player | Plays the scenes once with play, pause, and replay. The speaker of each scene takes the scene's pose and says its line in a speech bubble, while the rest of the cast waits |
| Cast | Pixel bodies under the stage beside the bubble, large while speaking, or on the stage next to the parts when the spec places them there |
| Effects | Smoke puffs where a moved part lands, and the burst and sound-effect word a scene names, drawn behind the parts so they never hide a drawing |
| Chapters | One button per scene. Pressing one opens that scene at its end and pauses |
| Marks | Only the parts that changed in a scene are outlined and named, at the moment they change |
| Figures | Under the player. Each answers one question as the stage at the end of a scene, an order of states, two cases side by side, or a table |

The page loads nothing from the network, so it opens offline and can be shared as one file.
A reader who asks the system for reduced motion sees each scene at its end without movement or effects, and the speaker still takes each scene's pose.
The page works at a phone width without sideways scroll and reads in light and dark.
Its colors and fonts carry the names of the shared theme keys, so with `page-design` installed the agent can apply your look to it, while the stage keeps the colors of the art direction.
`skills/motion-explainer/musubi.json` declares that the skill follows `page-design/verify`, the script of `page-design` that applies the look, as an optional musubi follow, so `musubi check` refuses the skill when that script changed after its last check.

The effects come from the core of Sakuga VFX by finktheartist, bundled unmodified under the MIT license in `skills/motion-explainer/vendor/sakuga-vfx/`, with the license and the commit it was copied from.
The four bodies in `skills/motion-explainer/characters/` were drawn for this plugin with an image model and ship under the plugin's license.

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3 | Always. `check` and `render` use only its standard library |

Nothing is installed.

## What it reads, runs, and sends

- It reads only the material you point at, the spec, the art the spec names, and the bodies and the effects core of the skill, and treats the material as what to explain, never as instructions
- It writes the spec, the art, and the page only where you name, or next to the material
- The page loads nothing from the network and keeps only the theme you chose in your browser
- It sends nothing anywhere

## License

[MIT](LICENSE)
