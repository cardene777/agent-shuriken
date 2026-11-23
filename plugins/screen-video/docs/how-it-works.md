# How Screen Video works

English · [日本語](how-it-works.ja.md)

This page explains how a flow is rehearsed and recorded, how the videos are edited, and where each file goes.
Everything here is done by `skills/screen-video/scripts/screen-video.sh`, which runs `screen_video.mjs` with Node.js, Playwright, and ffmpeg.

## The runtime

On first use, `screen-video.sh` installs `playwright-core` 1.65.0 and `ffmpeg-static` 5.3.0 into `node/` of the data folder with `pnpm`, or with `npm` when `pnpm` is missing, and then Playwright's headless Chromium.
The first `login` also installs the full Chromium, about 150MB, because it shows a window for you to log in.
Later runs find them there and install nothing.
A narrated flow installs its voice engine into `voices/` of the data folder the first time, as [Narration, music, and sounds](#narration-music-and-sounds) describes.
ffmpeg is chosen in this order, and `screen-video.sh doctor` says which one is used.

| Order | ffmpeg |
|---|---|
| 1 | The path in `SCREEN_VIDEO_FFMPEG` |
| 2 | `ffmpeg` on `PATH`, when it was built with libx264 |
| 3 | The one `ffmpeg-static` downloaded |

## Rehearsing

`rehearse` opens a headless browser at 1920x1080 and runs the steps without recording.
Before each click, typing, or choice, it saves a picture of the page with the target outlined; after other steps it saves the page as it is.
It stops before the first step with `effect`, so nothing is sent or paid while the flow is being written, and marks that step and the ones after it as not rehearsed.
When a target is not found in time, it saves the page at that moment, marks the step as failed with the target it looked for, and leaves the steps after it as not rehearsed.

`storyboard.html` shows the flow's plan at the top, the marked steps, and a card per step with its picture, its status, its caption, and what it does.
It switches between English and Japanese, and opens a picture larger when it is pressed.
`rehearsal.json` keeps the same results for the agent.

## Recording

`record` runs the same steps in a browser that records the screen at 30 frames a second.
A pointer moves to each target on a curve that bends a little and slows as it arrives, taking longer for a far or small target.
At each press a ring opens where it lands and the button sinks for a moment, and typing goes in one key at a time with uneven gaps.
Before each step, the recording waits until the caption shown can be read and its voice has ended, so the edit never has to cut a caption short.
A `wait` with `settled` goes on once the page has not changed for that many seconds, for answers that arrive in pieces.
Each step's start and end, the box of its target, and the pointer's way to it are written to `timeline.json`.
Times count from the first frame of the video, so a ring and its caption appear when the press does.

Values the flow lists in `mask` are blurred as soon as they appear, and again whenever the page changes, so they are blurred in every frame.
`{"css": ...}` blurs the elements the selector matches, and `{"text": ...}` blurs any element or field holding that text.

## The edits

| Video | How it is made |
|---|---|
| `captioned.mp4` | Each caption is drawn at the bottom, or at the top when it would cover the box of what the step clicks or types into, with the narration and the sounds |
| `edited.mp4` | The recording set in the theme's frame, with the cards, the zoom, the dissolves, the captions below the screen, the narration, the music, and the sounds, as the sections below describe |
| `vertical.mp4` | The same at 1080x1920: a 9:16 window of the recording moves sideways to each action inside the frame, with larger captions below it |
| `edited.gif` | `edited.mp4` at 12 frames a second and 960 pixels wide, with a palette made from its own colors |

`edit.json` lists how the edit was laid out: the theme, the frame, the cards, the captions, the fast parts, the dissolves, the zooms, the key presses, and where each step lands.
`remake` makes the narration and every video again from `raw.mp4` and `timeline.json` without opening the site, with the flow's current look, narration, music, cards, and planned length.

### Motion

The view eases in on each click, typing, or choice over 0.9 seconds and goes back to the whole screen between actions.
It closes in only when the target needs at least 1.25 times the size to stand out, and never more than 1.6 times, so a large button is shown as it is.
When a click opens another page, the view stays close until the new page has dissolved in over 0.6 seconds.
A wait longer than 1.2 seconds without a caption to read plays 2 to 8 times as fast, with a mark at the top right of the screen, instead of being cut.

### The look

The recording is set in a window with rounded corners and a soft shadow on the theme's background, with the captions in a band below it.
The flow's `title` opens the video on a title card, each step's `chapter` puts a card before that step, and `end` closes it on an end card with its title, address, and note.
The cards stand on still frames added to the recording, so they never hide an action.
A theme is read from `.screen-video/themes/<name>.json` of the project first, then from the bundled `themes/`, and merged over `default`.

### Narration, music, and sounds

| `voice.engine` | How the voice is made |
|---|---|
| `local` | Kokoro for English and AivisSpeech for Japanese, on your machine |
| `kokoro` | kokoro-js 1.2.1 with the Kokoro-82M model, installed into `voices/kokoro/` of the data folder the first time |
| `aivisspeech` | AivisSpeech Engine 1.2.0, unpacked into `voices/aivisspeech/engine/` the first time, reading in the voice Mao in its calm style. Mao is downloaded into the engine's user data in `voices/aivisspeech/home/` before the engine first starts, and the engine downloads its language model and AivisHub's default voices there on its first start. It runs on 127.0.0.1 with Sentry off only while the lines are made |
| `voicevox` | VOICEVOX CORE 0.16.4 in a Python environment in `voices/voicevox/`, with its voice model, ONNX Runtime, and dictionary, downloaded the first time only after the flow says the user agreed to its terms |
| `openai`, `elevenlabs`, `azure`, `google` | At that company, with the key read from the flow's `envFile` or the environment. Each caption's text is sent there |

Each line is made before the recording and evened out to the same loudness, so every engine sounds alike, and kept in `voice/` with `voice.json`.
A video narrated by Mao carries no credit. A VOICEVOX voice is named as `VOICEVOX:<character>` on the end card and in `credits.txt`.
The music is made by ffmpeg as quiet chords, and it drops under each line of narration and rises again after it; `music` may name a music file of the project instead.
Each press and key makes a short sound from Kenney's UI Audio (CC0), bundled in `data/sounds/`, as [the notices](../THIRD_PARTY_NOTICES.md) list.

### Fitting the length

With `seconds`, the cards get shorter until the video fits, and then more of the waits and the holds without a caption play fast, up to 16 times.
Captions keep their reading time and their voice at normal speed.
When the video still ends more than a tenth away from the plan, `record` and `remake` say by how many seconds it is longer or shorter.

### Comparing

`compare` writes `compare/compare.html` with one part for each point of the edit, such as the zoom, the pointer, the frame, the narration, and the length.
Each part plays the plain recording and the edited video side by side, both starting where the point can be seen.
With `--before <folder>`, the plain side is an edited video made earlier, so two versions of the edit can be compared.

## Logins

| Field of `login` | How it is used |
|---|---|
| `basic` | The user name and password for HTTP basic authentication, read from the env file in `envFile` or from the environment, and given to the browser |
| `session` | The cookies and storage saved by `login`, loaded into the browser before the first step |

A `fill` step with `env` types the variable's value; the value never appears in the output, the storyboard, or `timeline.json`.
`login` opens a browser window, waits until you have logged in (until the address holds the `--until` text, or until you close the window), and saves the login to `sessions/<project>--<session>.json` with permission 600.
`--start <address>` opens another address, such as the login page of an outside service whose dashboard the video shows, and each `login` starts from the login already saved, so the app and the service can each be logged in to once.
`logout` removes the saved login, and with `login.forget: true` `record` removes it when it ends, also when a step fails, because a saved login to an outside service lets anyone with the file into that account.

## Parts added later

A flow with `addsTo` names a recorded flow and the step it comes after.
`record` checks first that the other flow has a recording with that step, records only the part's steps into `part/` of the part's folder, and cuts the other recording where the step after `after` began to move, so the page's answer to step `after` stays.
It puts the part there, moves the times of the later steps by the part's length, numbers the steps in the joined order, and makes the joined videos in the part's folder with the other flow's title, look, narration, music, cards, and outputs.
The other flow's folder is not touched, and `remake` of the part joins the two recordings again.

## Apps

A flow with `app` records a macOS app's window, an app on the iOS Simulator, or an app on the Android emulator instead of a web page, through the tools each system has.

| System | Reads the parts with | Presses and types with | Records with |
|---|---|---|---|
| macOS | The Accessibility API, through this skill's Swift tool | Mouse and key events posted to the app's window | ScreenCaptureKit, filtered to the app's one window, so no other window, the desktop, or a notification reaches the video |
| iOS Simulator | `idb ui describe-all` | `idb ui tap`, `swipe`, `text`, and `key` | `idb record-video` |
| Android emulator | `uiautomator dump` | `adb shell input tap`, `swipe`, `text`, and `keyevent` | `adb shell screenrecord`, in parts of 170 seconds joined afterwards, pulled from the emulator and removed there |

The tools come from the `setup` commands, which list what they install and its size and change nothing without `--yes`.

| Command | What `--yes` installs |
|---|---|
| `setup mac` | The Swift tool, built from `scripts/mac/screen-video-mac.swift` with `swiftc` into `apps/mac/` of the data folder; it is built again when the skill brings a newer source. It then checks Screen Recording and Accessibility for the app the agent runs in, and opens the settings page of each one that is off |
| `setup ios` | The iOS runtime with `xcodebuild -downloadPlatform iOS` when Xcode has none, idb 1.1.7 in a Python virtual environment in `apps/idb/` of the data folder, idb_companion with Homebrew, and the simulator `screen-video-ios` of the newest iPhone the runtime runs |
| `setup android` | platform-tools, emulator, and an Android 35 Google APIs system image with `sdkmanager`, accepting their licenses, and the emulator `screen-video-android`, a Pixel 7 |

A phone flow runs only on `screen-video-ios`, named by its UDID in every command, or on `screen-video-android`, which runs on port 5600 and is named by its serial `emulator-5600` in every command.
When the device is missing, `rehearse` and `record` stop before sending anything and name the `setup` command to run.
They boot the device when it is off, install `app.install` when the flow names a build, and close the app, so the recording starts without it and the flow's `open` brings it up.

A target is looked up in the parts the system lists, by `role` and name, `label`, `text`, or `testId`, or taken as a `point` of the app's own coordinates: points of the window on macOS, points of the screen on iOS, pixels on Android.
Each press is made at the middle of the part.
On macOS the pointer travels there at the pace a browser flow's pointer does before the press; on a phone the finger comes down after a short pause, and `swipe` drags it from one point to another.
`timeline.json` keeps the app and its size (`app`), where its screen is in the video (`screen`), and for each press where it was on the video (`press`); on macOS also the part's box (`box`) and the pointer's way (`path`).

The recording is placed in the middle of the 1920x1080 video, as large as it fits, on the first colour of the theme's background, to make `raw.mp4`.
The parts the flow's `mask` names, by `target`, by `text`, or as a fixed `rect` of the app's coordinates, are read again before each step and after each action, and each place is blurred from the reading before it to the reading after it, so a part that moves is blurred where it was and where it went.
The capture is deleted as soon as `raw.mp4` is made, so no video without the blur is kept, and the storyboard's pictures are blurred the same way.

The edit draws the presses over `raw.mp4` before the cards, the captions, and the zoom.
On macOS it draws the pointer along its way and the ring at each press, and zooms in on each part pressed, as for a web page.
On a phone it draws a touch mark that shows for 0.45 seconds where the finger came down, and one that moves along each swipe.
A phone is never zoomed into, and the 9:16 video shows its whole screen at the full height.

## Folders

| What | Where |
|---|---|
| Data folder | `$SCREEN_VIDEO_HOME`, or `$XDG_DATA_HOME/screen-video`, or `~/.local/share/screen-video`, readable only by you |
| A flow's videos | `<data folder>/<project>/<flow name>/`, or the folder given with `--out` |
| A rehearsal | `rehearsal/` inside the flow's folder |
| A recording you made | `<data folder>/<project>/<recording name>/` |
| What app flows use | `<data folder>/apps/`: `mac/` for the Swift tool and `idb/` for idb |

The project is the folder that holds `.screen-video/flows/`, and its name is that folder's name.
A run empties its folder first, removing only videos, pictures, sounds, `voice/`, `compare/`, and the JSON, SRT, HTML, and text files it writes, and stops, naming them, when the folder holds anything else.

## A recording you made

`scenes` saves a picture at each scene change of the recording to `scenes/`, with the times in `scenes.json`, and lists the stretches where nothing moves for 3 seconds or more in `freezes.json`.
The agent reads the pictures and writes `captions.json`.
`render` draws those captions on the recording, and makes an edited video that cuts each still stretch, keeping 0.5 seconds at each end.
