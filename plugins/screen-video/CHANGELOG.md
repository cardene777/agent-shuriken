# Changelog

Releases of the screen-video plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The `screen-video` skill plans a video of a web app with the user (what it is for, who watches it, how long it is, which videos to make, what is private, and which steps send something or pay), writes it as a flow file in `.screen-video/flows/` of the project, rehearses it into a storyboard of pictures, and records it only after the user has seen the storyboard
- `screen-video.sh` has the commands `setup`, `doctor`, `inspect`, `check`, `rehearse`, `record`, `remake`, `login`, `scenes`, and `render`. On first use it installs `playwright-core` 1.65.0, its headless browser, and `ffmpeg-static` 5.3.0 into `node/` of the data folder, and it prefers an ffmpeg on `PATH` with libx264
- A recording writes `raw.mp4`, `captioned.mp4` with each step's caption placed away from what the step points at, `edited.mp4` that zooms in on each action and cuts the waits, `timeline.json`, and `captions.srt`, plus `vertical.mp4` at 1080x1920 and `edited.gif` when the flow's `outputs` asks. Press times line up with the video because they count from its first frame
- Values listed in the flow's `mask` are blurred in every frame. Login values are read from the env file the flow names and are never printed or written, `check` refuses plain text typed into a password field, and a login made by hand is saved with `login` in the data folder, readable only by the user
- A rehearsal stops before the first step marked with `effect`, and `record` runs marked steps only with `--confirm-effects`. A run stops, naming them, instead of emptying a folder that holds files it did not write
- `scenes` and `render` caption and edit a recording the user made, from pictures of its scene changes and the captions the agent writes
