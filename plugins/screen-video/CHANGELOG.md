# Changelog

Releases of the screen-video plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.2.0] - 2026-11-23

- Titles, chapter and end cards, and captions wrap into lines of about the same length, breaking Japanese between phrases, and are drawn in a page whose `lang` is the flow's language (or Japanese, for captions with kana or kanji when `render` has no flow). Before, a long Japanese title could leave one or two characters alone on its last line
- Japanese narration made on the user's machine uses AivisSpeech Engine 1.2.0 with its voice Mao in the calm style, and the videos carry no credit. The first narrated Japanese flow installs the engine and Mao into `voices/aivisspeech/` of the data folder; the engine runs on 127.0.0.1 with its error reports to Sentry turned off, only while the lines are made. `voice.engine: "aivisspeech"` chooses it outright, and `voice.voice` picks another installed voice as `speaker/style`. VOICEVOX stays available as `voice.engine: "voicevox"`, with its terms and credit as before
- A target with `frame` is looked for in every iframe whose address holds that text, nested ones too, until one of them holds it within the step's `timeout`. Before, a step failed at once while a payment form was still loading, or looked in another iframe from the same host that held no field

## [0.1.0] - 2026-11-22

- The `screen-video` skill plans a video of a web app with the user (what it is for, who watches it, how long it is, which videos to make, what is private, and which steps send something or pay), writes it as a flow file in `.screen-video/flows/` of the project, rehearses it into a storyboard of pictures, and records it only after the user has seen the storyboard
- `screen-video.sh` has the commands `setup`, `doctor`, `inspect`, `check`, `rehearse`, `record`, `remake`, `login`, `scenes`, and `render`. On first use it installs `playwright-core` 1.65.0, its headless browser, and `ffmpeg-static` 5.3.0 into `node/` of the data folder, and it prefers an ffmpeg on `PATH` with libx264
- A recording writes `raw.mp4`, `captioned.mp4` with each step's caption placed away from what the step points at, `edited.mp4`, `timeline.json`, `captions.srt`, `edited.srt`, and `edit.json`, plus `vertical.mp4` at 1080x1920 and `edited.gif` when the flow's `outputs` asks. Press times line up with the video because they count from its first frame
- `edited.mp4` eases in on each action, moves the pointer on a curve that slows near its target, shows a ring and sinks the button at each press, dissolves between pages, and plays long waits fast with a mark instead of cutting them. `vertical.mp4` and `edited.gif` get the same look
- The screen sits in a frame on a theme's background, with a title card, a card before each `chapter`, and an end card from `end`. Three themes are bundled (`default`, `midnight`, `paper`), and a project adds its own in `.screen-video/themes/`
- `voice` reads each caption, or the step's `say`, aloud: Kokoro for English and VOICEVOX for Japanese on the user's machine, installed into `voices/` of the data folder on first use, or OpenAI, ElevenLabs, Microsoft Azure, or Google Cloud when the flow chooses one. VOICEVOX is installed only after the user agrees to its terms, and its voice is credited on the end card and in `credits.txt`
- Quiet music made by ffmpeg plays under the narration and ducks under each line, or a music file of the project's plays instead, and each press and key makes a sound from Kenney's UI Audio (CC0), bundled
- Each captioned step lasts until its caption can be read and its voice has ended, a `wait` can go on once the page has `settled`, and `seconds` fits the edited video to a planned length, saying by how much it is off when it cannot
- `voices` makes the narration ahead of a recording, `remake` applies the flow's current look, narration, music, and length to the last recording, and `compare` writes a page with the plain and edited videos side by side for each point
- Values listed in the flow's `mask` are blurred in every frame. Login values are read from the env file the flow names and are never printed or written, `check` refuses plain text typed into a password field, and a login made by hand is saved with `login` in the data folder, readable only by the user
- A rehearsal stops before the first step marked with `effect`, and `record` runs marked steps only with `--confirm-effects`. A run stops, naming them, instead of emptying a folder that holds files it did not write
- `scenes` and `render` caption and edit a recording the user made, from pictures of its scene changes and the captions the agent writes

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/screen-video--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/screen-video--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/screen-video--v0.1.0
