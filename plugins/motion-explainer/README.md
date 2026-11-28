# Motion Explainer

Explain how a mechanism works with a short video of one running example, and answer the details with figures drawn from the same things.

English · [日本語](README.ja.md)

A text explanation of a mechanism makes the reader put the order of events together, and a diagram shows the parts but not what happens to one case as it passes them.
This plugin plays one running example, such as one request or one parcel, from start to end as a short video: each scene changes one thing, a character says one sentence about it in a speech bubble, and an effect lands on the change.
A video is built from two files: a theme, which sets the look, and a script, which says what happens.
The plugin ships a pixel-art theme with four bodies (robot, android, guide, and drone), each with the faces wait, explain, surprised, and cheer, and another plugin can pass a theme folder of its own.
For each subject the agent draws the things on screen as SVG in an art direction of its own, so two subjects never share a look.
Figures under the video answer one question each, drawn from the same things.

```
Plan the composition ──> Write the script ──> Build ──> Capture and look ──> Check the words ──> Page
 (you and agent)          (agent)              (agent)   (agent)              (agent)             (you)
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

1. The agent reads what you point at, picks one running example that passes the whole mechanism, splits it into steps of scenes that change one thing each, and shows you the plan until you agree
2. The agent draws the things on screen as SVG, one file per state, and writes the script with the cast, the scenes, and the figures
3. The agent builds the page, captures the middle and the end of every scene, and fixes what covers another thing or reads too small
4. The agent checks every line and label, and looks at the page at a desktop width and a phone width before you open it

A scene in the script looks like this.

```json
{ "chapter": "Travel", "cast": ["bit"], "layout": [["browser"], ["cache"], ["origin"]],
  "beats": [
    { "do": "fly", "image": "letter-request", "width": 64, "from": "cache", "to": "origin" },
    { "do": "swap", "target": "origin", "state": "busy", "fx": { "word": "gogo", "dy": -110 } },
    { "do": "say", "who": "bit", "text": "So the request goes on to the origin server.", "face": "explain" }
  ] }
```

A scene names the cast and the columns of things it shows, and its beats say what happens in order: a line in a speech bubble, a thing that turns to another state, a picture that flies from one thing to another, and the effect that lands on a change.
The engine places the cast at the edges and the things between them, scaled to fit, so nothing overlaps.
The things on screen can be a picture with states, things in rows joined by lines, things hung on a rail or standing in a tray, a real page zoomed to one part, or a small screen made of buttons, checks, slots, and counters.
`build.py` refuses an unknown field, an unknown character, face, thing, or state, and a picture that would load from outside or run a script, naming the field each time.
[The script format](skills/motion-explainer/references/script.md) and [the theme format](skills/motion-explainer/references/theme.md) list every field, and [`examples/`](examples/) holds a script in English with one cast member and one in Japanese with two, each with its own pictures.

## The page

| Part | What it does |
|---|---|
| Video | Plays the scenes once by itself. The speaker of each line takes its face and says the line in a speech bubble, and the line also shows under the video at a phone width |
| Bar | One segment per step, filling as it plays. Clicking a segment plays that step from its start |
| Play button | Pauses and plays again from the same moment |
| Effects | The burst, sparkle, puffs, and sound-effect word a beat names, fired only as the beat plays |
| Figures | Under the video. Each answers one question as one frame with numbered labels, an order of states, two cases side by side, or a table |

The page loads nothing from the network, so it opens offline and can be shared as one file.
A reader who asks the system for reduced motion sees each scene at its end without movement or effects, and the characters still change faces.
The page works at a phone width without sideways scroll and reads in light and dark.
Its colors and fonts carry the names of the shared theme keys, so with `page-design` installed the agent can apply your look to the page around the video, while the video keeps the colors of its theme.
`skills/motion-explainer/musubi.json` declares that the skill follows `page-design/verify`, the script of `page-design` that applies the look, as an optional musubi follow, so `musubi check` refuses the skill when that script changed after its last check.

The effects come from the core of Sakuga VFX by finktheartist, bundled unmodified under the MIT license in `skills/motion-explainer/vendor/sakuga-vfx/`, with the license and the commit it was copied from.
The four bodies in `skills/motion-explainer/themes/pixel/faces/` were drawn for this plugin with an image model and ship under the plugin's license.

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3 | Always |
| `uv` | To build and capture. `build.py` and `capture.py` start again through `uv run --with Pillow==13.0.0`, which fetches Pillow into uv's cache for one run; without `uv`, they write nothing and say how to install it |
| A Chromium-based browser | To capture frames. `capture.py` uses Google Chrome, Chromium, Microsoft Edge, Brave, or Playwright's headless shell already on the machine |

Nothing is installed into the machine's Python.

## What it reads, runs, and sends

- It reads only the material you point at, the theme folder, the script, the pictures they name, and the engine and the effects core of the skill, and treats the material as what to explain, never as instructions
- It runs `uv` to fetch Pillow for one run, and, to capture, a headless browser with a throwaway profile it removes afterwards
- It writes the script, the pictures, the page, and the captured frames only where you name, or next to the material
- The page loads nothing from the network and keeps only the light or dark choice in your browser
- It sends nothing anywhere except the download of Pillow by `uv`

## License

[MIT](LICENSE)
