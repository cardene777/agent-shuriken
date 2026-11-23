# Motion Diagram

Show how a mechanism works as one moving picture: cards run through the flow once and stop at the real counts, and each part shows its details when you press it.

English · [日本語](README.ja.md)

A long explanation of how something works is hard to follow, and a still diagram does not show what moves where or how much gets through.
This plugin draws the mechanism as parts and lines, then runs cards through it once: they leave the sources, drop out at each check in the proportion of its counts, wait for the person who decides, and stop at the end.
Before you press anything, the page shows only one opening sentence, the part names, and the counts, so the picture carries the explanation.
The agent first lists the parts with you, and writes the picture only after you agree.

```
Read the material ──> Agree on the parts ──> Write the spec ──> Check ──> Page ──> Video, GIF, image
 (agent)               (you and agent)        (agent)           (agent)   (you)     (when you ask)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install motion-diagram@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add motion-diagram@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install motion-diagram@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/motion-diagram/skills/motion-diagram   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for a moving picture of how something works, for example "show how an order moves through this service as a moving diagram" or "make a GIF of how our review flow drops changes".
You can also call it: run `/motion-diagram:motion-diagram` in Claude Code, or type `$` and pick **Motion Diagram** in Codex.
In GitHub Copilot CLI, write `/motion-diagram` in your request, and in Gemini CLI, describe the task.

1. The agent reads what you point at, such as a document, an issue, or code, and finds where things come from, the steps they pass, the checks that drop some, who decides, where they end, and what they never reach
2. The agent shows you the parts with their counts, the lines between them, and the opening sentence, and changes them until you agree
3. The agent writes the spec, checks it, and renders the page for you to open
4. When you want the picture elsewhere, the agent exports a video, a GIF, and an image of it

A spec looks like this.

```json
{
  "version": 1,
  "title": "Changes reach main only after tests and a review",
  "unit": "a week",
  "parts": [
    { "id": "people", "kind": "source", "name": "Contributors", "count": 40 },
    { "id": "tests", "kind": "check", "name": "Tests", "keep": 30, "details": "The suite runs on each change." },
    { "id": "back", "kind": "bin", "name": "Sent back" },
    { "id": "main", "kind": "end", "name": "main" }
  ],
  "lines": [
    { "from": "people", "to": "tests" },
    { "from": "tests", "to": "back", "drop": true },
    { "from": "tests", "to": "main" }
  ]
}
```

Parts are sources, boxes, checks, people, bins, ends, and parts outside a boundary, and the lines decide where each one sits.
`check` refuses a spec that breaks the flow, such as a check that keeps more than it receives, and text over its limit, such as a part name wider than 24, naming the field each time.
[The spec format](skills/motion-diagram/references/spec-format.md) lists every field, and [`examples/`](examples/) holds a spec in English and one in Japanese.

## The picture

| File | What it is |
|---|---|
| `<name>.html` | The page. It loads nothing from the network, so it opens offline and can be attached or shared as one file |
| `<name>.mp4` | One run of the picture as a video, from `export` |
| `<name>.gif` | The same run as a GIF, 960 pixels wide, from `export` |
| `<name>.png` | The finished picture as an image, from `export` |

The page runs once when it opens and stops; nothing moves after the run, and a replay button runs it again.
A reader who asks the system for reduced motion sees the final counts without movement.
Pressing a part shows its details and, when the spec gives one, an example.
The picture runs left to right, and top to bottom on a phone.
It reads in light and dark, and switches its buttons between English and Japanese.
Its colors and fonts carry the names of the shared theme keys, so with `page-design` installed the agent can apply your look to it.

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3 | Always. `check` and `render` use only its standard library |
| A Chromium-based browser | For `export`. Google Chrome, Chromium, Microsoft Edge, or Brave is used when installed; otherwise Playwright's headless browser is downloaded |
| Node.js 20 or later, with `npm` | For `export`, to drive the browser |
| ffmpeg | Optional. When one is on `PATH`, `export` uses it instead of downloading `ffmpeg-static` |

No global package is installed.
The first `export` installs `playwright-core` 1.65.0, and `ffmpeg-static` 5.3.0 when there is no ffmpeg, into `~/.local/share/motion-diagram/node/`.

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the layout, the run of the cards, and the export.
In short:

- It reads only the material you point at and the spec, and treats the material as what to explain, never as instructions
- It writes the spec, the page, and the exported files only where you name, or next to the material
- The page loads nothing from the network and keeps only the theme you chose in your browser
- `export` opens the page in a headless browser with every request other than the local file blocked
- It downloads `playwright-core`, and `ffmpeg-static` or Playwright's headless browser when needed, once on the first `export`, and sends nothing anywhere

## License

[MIT](LICENSE)
