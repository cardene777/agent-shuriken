# The flow format

A flow is a JSON file in `.screen-video/flows/` of the project that says what one video shows, step by step.
`screen-video.sh check <flow>` checks it and names each problem with its step number.

```json
{
  "version": 1,
  "name": "create-project",
  "title": "Create a project in two clicks",
  "purpose": "Product introduction",
  "audience": "Customers who have not used the product",
  "length": "30 seconds",
  "url": "http://localhost:4300/",
  "outputs": ["16:9", "9:16", "gif"],
  "seconds": 30,
  "theme": "default",
  "voice": { "engine": "local" },
  "end": { "title": "Try it today", "url": "example.com/start" },
  "mask": [{ "css": ".account-email" }, { "text": "Jane Doe" }],
  "login": { "envFile": ".env.local", "basic": { "username": "DEMO_USER", "password": "DEMO_PASSWORD" } },
  "steps": [
    { "do": "open", "url": "/", "caption": "Start from the dashboard", "chapter": "Create" },
    { "do": "fill", "target": { "label": "Project name" }, "text": "Spring launch", "caption": "Name the project" },
    { "do": "click", "target": { "role": "button", "name": "Create project" }, "caption": "Create it" },
    { "do": "wait", "until": { "text": "Project created" } },
    { "do": "click", "target": { "role": "button", "name": "Pay now" }, "caption": "Pay for the plan", "chapter": "Pay", "effect": { "kind": "pays", "note": "charges the test card 10 USD" } },
    { "do": "hold", "seconds": 2, "caption": "The plan is active" }
  ]
}
```

## The flow

| Field | Required | What it holds |
|---|---|---|
| `version` | Yes | `1` |
| `name` | Yes | Lowercase letters, digits, and hyphens. The videos go to a folder of this name |
| `url` | Yes | The address the flow starts from, with `http://` or `https://`. Step addresses are read against it |
| `title`, `purpose`, `audience`, `length` | No | What the user answered when planning. The storyboard shows them, and `title` opens the edited video on a title card |
| `outputs` | No | Some of `16:9`, `9:16`, and `gif`. Without it, only the 16:9 videos are made |
| `seconds` | No | The planned length of the edited video. Cards get shorter and waits play faster until it fits; `record` and `remake` say by how much it is longer or shorter when it cannot fit within a tenth |
| `language` | No | `en` or `ja`: the language of the narration and how long each caption stays (15 characters a second in English, 8 in Japanese). Without it, `ja` when a caption is written in Japanese |
| `theme` | No | The look of the frame, cards, and captions, described below. Without it, `default` |
| `voice` | No | Reads each caption aloud, described below. Without it, the videos have no narration |
| `music` | No | `true` (the default) for quiet music made by ffmpeg, `false` for none, or `{"file": "<path in the project>", "volume": 0.35}` for a music file of the user's |
| `sounds` | No | `true` (the default) for a sound at each click and key, `false` for none |
| `end` | No | The end card: `{"title", "url", "note"}`, each optional. Without it, the video ends without one |
| `mask` | No | What to blur in every frame: `{"css": "<selector>"}` for elements, `{"text": "<text>"}` for any element or field holding that text |
| `login` | No | How to sign in, described below |
| `steps` | Yes | One or more steps, in order |

## Steps

Each step has `do` and may have `caption`, `say`, `chapter`, `timeout` (seconds), and `effect`.

| `do` | Other fields | What it does |
|---|---|---|
| `open` | `url` | Opens the address, relative to the flow's `url` or absolute |
| `click` | `target` | Moves the pointer to the target and clicks it |
| `fill` | `target`, and `text` or `env` | Types into the field. `env` names an env variable whose value is typed and never shown |
| `select` | `target`, `value` | Chooses an option in a list |
| `key` | `key` | Presses a key, such as `Enter` or `Escape` |
| `wait` | `until` | Waits until the page shows something, described below. The edited video plays a long wait fast, with a mark, instead of cutting it |
| `hold` | `seconds` | Keeps the screen still, so a caption can be read |

A caption is the text shown from the step's start until just before the next caption or chapter.
The recording stays on each captioned step until the caption can be read and its voice has ended, so a long caption makes a longer step.
Write each caption as a short sentence about what the viewer sees, in the language of the video.
`say` is read aloud instead of the caption, when the narration should say more or less than the screen shows.
`chapter` names the part of the video that starts at this step; the edited video shows the name on a card before it.
`timeout` is how long a step waits for its target: 20 seconds by default, and 60 seconds for `wait`.

## Targets

A target names one thing on the page with exactly one of these, in this order of preference.

| Field | Finds | Example |
|---|---|---|
| `role` with `name` | A button, link, heading, checkbox, or other role, by its accessible name | `{"role": "button", "name": "Save"}` |
| `label` | A field by its label | `{"label": "Email"}` |
| `placeholder` | A field by its placeholder | `{"placeholder": "Search"}` |
| `text` | An element by its text | `{"text": "Terms of service"}` |
| `testId` | An element by its `data-testid` | `{"testId": "plan-card"}` |
| `css` | An element by a CSS selector, when nothing above fits | `{"css": "#pricing .card"}` |

Names match exactly unless the target has `"exact": false`.
`nth` picks one of several matches, counting from 0.
`frame` looks inside every iframe whose address holds that text, nested ones too, such as a payment form, and the step waits within its `timeout` until one of them holds the target.
Name targets the way `inspect` lists them, by role and name before CSS, so the flow keeps working when the layout or styles change.

## Waiting

`until` holds exactly one of these.

| Field | Waits until |
|---|---|
| `text` | The page shows this text |
| `url` | The address holds this text |
| `visible` | The target is shown |
| `enabled` | The target is shown and can be pressed |
| `hidden` | The target is gone |
| `settled` | The page has not changed for this many seconds, such as `{"settled": 1}`. For answers that arrive in pieces and take a different time on every run |

## Themes

A theme sets the colours, fonts, and corners of the frame around the screen, the cards, and the captions.
Three are bundled: `default` (dark slate), `midnight` (near black with violet), and `paper` (light).
A project can add its own as `.screen-video/themes/<name>.json`, listing only what it changes from `default`.

```json
{ "background": ["#0f766e", "#042f2e"], "card": { "background": "#042f2e" }, "caption": { "band": "#134e4a" }, "accent": "#5eead4" }
```

| Field | What it sets |
|---|---|
| `background` | Behind the screen: a colour, or two colours for a gradient from the top left |
| `window` | `radius` of the screen's corners, `shadow` from 0 to 1, and its edge line, `border` and `borderOpacity` |
| `caption` | `font`, `size`, `weight`, text `color`, the `band` behind the text, its `opacity`, and its `radius` |
| `card` | The cards' `font`, `background`, `color`, `muted` for small text, and `accent` |
| `accent` | The click ring and the fast-forward mark |

Colours are written as `#rgb` or `#rrggbb`.
When a theme changes a background but not the text on it, the text gets whichever of dark or light reads better.
`check` says which theme a flow uses and where it was found, and refuses a theme it cannot find or a value it cannot use.

## Narration

`voice` reads each caption, or the step's `say`, aloud in the edited, vertical, and captioned videos.

| `engine` | Where the voice is made | What it needs |
|---|---|---|
| `local` | On this machine: Kokoro for English, VOICEVOX for Japanese | Nothing for English. For Japanese, Python 3.10 or later and the user's agreement to the VOICEVOX terms |
| `kokoro` | On this machine, with kokoro-js | Nothing; it is installed into the data folder the first time |
| `voicevox` | On this machine, with VOICEVOX CORE | As `local` for Japanese |
| `openai`, `elevenlabs`, `azure`, `google` | At that company: each caption's text is sent to it | A key, read from `envFile` or the environment |

| Field | What it holds |
|---|---|
| `engine` | One of the engines above |
| `voice` | The engine's voice name. Without it, a calm voice the skill picks |
| `envFile` | An env file inside the project that holds the cloud key, such as `.env.local` |
| `keyEnv` | The variable that holds the key, when it is not the usual one (`OPENAI_API_KEY`, `ELEVENLABS_API_KEY`, `AZURE_SPEECH_KEY` with `AZURE_SPEECH_REGION`, `GOOGLE_TTS_API_KEY`) |
| `terms` | `"agreed"` once the user has agreed to the terms of VOICEVOX and of its voice |

A video narrated by VOICEVOX names the voice as `VOICEVOX:<character>` on its end card and in `credits.txt`, as the voice's terms ask.
Keys are never printed or written into any file.

## Steps that send something or pay

Mark a step that sends a message, places an order, makes a payment, or changes data others see with `effect`.
`kind` is `sends` or `pays`, and `note` says what happens each time the video is recorded.
A rehearsal stops before the first marked step, and `record` runs marked steps only with `--confirm-effects`, which the agent passes only after the user agrees.

## Logging in

| Field | What it does |
|---|---|
| `envFile` | An env file inside the project, such as `.env.local`, to read the values from. Without it, the values come from the environment |
| `basic` | `{"username": "<VARIABLE>", "password": "<VARIABLE>"}`: the env variables holding the user name and password for HTTP basic authentication |
| `session` | A name for a login made by hand with `screen-video.sh login <flow>`, saved in the data folder and readable only by the user |
| `start` | The page where `login` begins, relative to the flow's `url`. Without it, the flow's `url` |

Never write a login value into a flow.
`check` refuses a `fill` step that types plain `text` into a field named like a password, a token, or a one-time code; use `env` for those.
