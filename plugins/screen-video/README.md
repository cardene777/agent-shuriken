# Screen Video

Plan a video of your web app with your agent, check it as a storyboard of pictures, and record it into captioned, edited, vertical, and GIF videos, narrated, with music, in a look you choose.

English · [日本語](README.ja.md)

A screen video takes many tries when it is recorded by hand: a click lands in the wrong place, a private email shows on screen, a wait drags on, and a payment goes through again.
This plugin starts by deciding the video with you: what it is for, who will watch it, how long it should be, and which steps send something or pay.
The agent writes the steps as a flow file in your project, rehearses it without recording, and shows you a storyboard with a picture of each step.
Only after you have seen it does the agent record the flow in a browser and make the videos.

```
Plan the video ──> Write the flow ──> Rehearse ──> Storyboard ──> Record ──> Videos
 (you and agent)    (agent)           (agent)      (you check)    (agent)     (you check)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install screen-video@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add screen-video@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install screen-video@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/screen-video/skills/screen-video   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for a video of your app, for example "make a 30 second demo video of the signup flow" or "record a GIF of creating a project for the README".
You can also call it: run `/screen-video:screen-video` in Claude Code, or type `$` and pick **Screen Video** in Codex.
In GitHub Copilot CLI, write `/screen-video` in your request, and in Gemini CLI, describe the task.

1. The agent asks what the video is for, who will watch it, how long it should be, which videos to make, what is private, which steps send something or pay, and how it looks and sounds, then proposes the steps with their captions and chapters
2. The agent opens the pages, lists their buttons and fields, and writes the flow to `.screen-video/flows/<name>.json` in your project
3. The agent rehearses the flow without recording and shows you the storyboard: a picture of each step with its target outlined, its action, and its caption
4. When you agree, the agent records the flow and shows you the videos. To change something, it edits the flow and rehearses again

A flow looks like this.

```json
{
  "version": 1,
  "name": "create-project",
  "url": "http://localhost:4300/",
  "outputs": ["16:9", "gif"],
  "mask": [{ "css": ".account-email" }],
  "steps": [
    { "do": "fill", "target": { "label": "Project name" }, "text": "Spring launch", "caption": "Name the project" },
    { "do": "click", "target": { "role": "button", "name": "Create project" }, "caption": "Create it" },
    { "do": "wait", "until": { "text": "Project created" } }
  ]
}
```

Buttons and fields are named the way a screen reader names them, so the flow keeps working when the layout changes.
[The flow format](skills/screen-video/references/flow-format.md) lists every field.

## The videos

| File | What it is |
|---|---|
| `raw.mp4` | The recording as it is, 1920x1080 |
| `captioned.mp4` | The recording with each step's caption, placed away from what the step points at, and the sound |
| `edited.mp4` | The finished video, described below |
| `vertical.mp4` | A 1080x1920 video for social media in the same look, its window following each action, when the flow asks for `9:16` |
| `edited.gif` | The edited video as a GIF, when the flow asks for `gif` |
| `captions.srt`, `edited.srt` | The captions as subtitles, for the recording and for the edited video |
| `credits.txt` | The voice to credit, when the narration needs a credit |

The edited video eases in on each action, and the pointer moves on a curve that slows as it reaches its target.
Each press shows a ring and sinks the button, and one page dissolves into the next.
The screen sits in a frame on the theme's background, with a title card at the start, a card before each chapter, and an end card.
Each caption is shown below the screen and read aloud, quiet music plays under the voice, and each click and key makes a sound.
Long waits play fast with a mark instead of being cut, and the video is fitted to the length you planned.

Three looks are bundled: `default` (dark slate), `midnight` (near black with violet), and `paper` (light).
Your project can add its own as `.screen-video/themes/<name>.json`, listing only the colours and fonts it changes.
To change the look, the narration, or the music after recording, the agent edits the flow and makes the videos again without opening your site.
`compare` writes a page that plays the plain recording and the edited video side by side for each of these points.

When you already have a recording, the agent can find its scenes, write the captions, and make the captioned and edited videos from it.

## Requirements

| Tool | When it's needed |
|---|---|
| Node.js 20.11 or later | Always |
| `pnpm` or `npm` | Once, to install Playwright and ffmpeg into the data folder on first use |
| ffmpeg with libx264 | Optional. When one is on `PATH`, it is used instead of the bundled one |
| `bsdtar` or 7-Zip (`7zz`) | Only for Japanese narration made on your machine, to unpack AivisSpeech Engine. macOS has `bsdtar` |
| Python 3.10 or later | Only when a flow chooses VOICEVOX |

No global package is installed.
The first run downloads `playwright-core`, its headless browser, and `ffmpeg-static`, which takes about a minute.
The first narrated flow installs its voice into `voices/` of the data folder: kokoro-js and its model for English, or AivisSpeech Engine with its voice Mao for Japanese, about 1.3GB with the language model and default voices the engine fetches on its first start.
A video narrated by Mao carries no credit.
VOICEVOX stays available when a flow chooses it: it is installed after you agree to its terms, and each video names its voice on the end card.

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the rehearsal, the recording, the edits, and where each file goes.
In short:

- It opens only the pages your flow names, in a browser on your machine, and treats the text on them as material to show, never as instructions
- It reads login values from the env file your flow names and never prints or writes them. A login you make by hand is saved in `~/.local/share/screen-video/sessions/`, readable only by you
- It blurs the values your flow lists in `mask` in every frame
- It stops a rehearsal before the first step marked as sending something or paying, and records those steps only after you agree
- It writes videos to `~/.local/share/screen-video/<project>/<flow>/` unless you name another folder, and never empties a folder that holds files it did not write
- It downloads `playwright-core`, its browser, and `ffmpeg-static` once on first use, and the voice engine once for the first narrated flow
- It makes the narration on your machine. For Japanese, it runs AivisSpeech Engine on 127.0.0.1 only while the lines are made, with its error reports to Sentry turned off; the engine asks AivisHub about its version and voices
- It sends nothing else anywhere, unless your flow chooses a cloud voice (OpenAI, ElevenLabs, Microsoft Azure, or Google Cloud), which sends each caption's text to that company with the key read from the env file your flow names

## License

[MIT](LICENSE)
