# How Screen Video works

English · [日本語](how-it-works.ja.md)

This page explains how a flow is rehearsed and recorded, how the videos are edited, and where each file goes.
Everything here is done by `skills/screen-video/scripts/screen-video.sh`, which runs `screen_video.mjs` with Node.js, Playwright, and ffmpeg.

## The runtime

On first use, `screen-video.sh` installs `playwright-core` 1.65.0 and `ffmpeg-static` 5.3.0 into `node/` of the data folder with `pnpm`, or with `npm` when `pnpm` is missing, and then Playwright's headless Chromium.
Later runs find them there and install nothing.
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
A pointer moves to each target before it is pressed, and a ring shows where each press lands.
Each step's start and end, and the box of its target, are written to `timeline.json`.
Times count from the first frame of the video, so a ring and its caption appear when the press does.

Values the flow lists in `mask` are blurred as soon as they appear, and again whenever the page changes, so they are blurred in every frame.
`{"css": ...}` blurs the elements the selector matches, and `{"text": ...}` blurs any element or field holding that text.

## The edits

| Video | How it is made |
|---|---|
| `captioned.mp4` | Each caption is drawn at the bottom, or at the top when it would cover the box of what the step clicks or types into |
| `edited.mp4` | Each `wait` longer than 0.8 seconds is cut, keeping 0.4 seconds at each end. The view closes in on each action's box and goes back to the whole screen between actions, and the captions move to the joined times |
| `vertical.mp4` | A 9:16 window of the recording moves sideways to each action, scaled to 1080x1920, with larger captions at the bottom |
| `edited.gif` | `edited.mp4` at 12 frames a second and 960 pixels wide, with a palette made from its own colors |

`edit.json` lists the kept parts and the zooms, and `remake` makes every video again from `raw.mp4` and `timeline.json` without opening the site.

## Logins

| Field of `login` | How it is used |
|---|---|
| `basic` | The user name and password for HTTP basic authentication, read from the env file in `envFile` or from the environment, and given to the browser |
| `session` | The cookies and storage saved by `login`, loaded into the browser before the first step |

A `fill` step with `env` types the variable's value; the value never appears in the output, the storyboard, or `timeline.json`.
`login` opens a browser window, waits until you have logged in (until the address holds the `--until` text, or until you close the window), and saves the login to `sessions/<project>--<session>.json` with permission 600.

## Folders

| What | Where |
|---|---|
| Data folder | `$SCREEN_VIDEO_HOME`, or `$XDG_DATA_HOME/screen-video`, or `~/.local/share/screen-video`, readable only by you |
| A flow's videos | `<data folder>/<project>/<flow name>/`, or the folder given with `--out` |
| A rehearsal | `rehearsal/` inside the flow's folder |
| A recording you made | `<data folder>/<project>/<recording name>/` |

The project is the folder that holds `.screen-video/flows/`, and its name is that folder's name.
A run empties its folder first, removing only videos, pictures, and the JSON, SRT, HTML, and text files it writes, and stops, naming them, when the folder holds anything else.

## A recording you made

`scenes` saves a picture at each scene change of the recording to `scenes/`, with the times in `scenes.json`, and lists the stretches where nothing moves for 3 seconds or more in `freezes.json`.
The agent reads the pictures and writes `captions.json`.
`render` draws those captions on the recording, and makes an edited video that cuts each still stretch, keeping 0.5 seconds at each end.
