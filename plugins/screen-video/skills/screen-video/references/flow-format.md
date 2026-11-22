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
  "mask": [{ "css": ".account-email" }, { "text": "Jane Doe" }],
  "login": { "envFile": ".env.local", "basic": { "username": "DEMO_USER", "password": "DEMO_PASSWORD" } },
  "steps": [
    { "do": "open", "url": "/", "caption": "Start from the dashboard" },
    { "do": "fill", "target": { "label": "Project name" }, "text": "Spring launch", "caption": "Name the project" },
    { "do": "click", "target": { "role": "button", "name": "Create project" }, "caption": "Create it" },
    { "do": "wait", "until": { "text": "Project created" } },
    { "do": "click", "target": { "role": "button", "name": "Pay now" }, "caption": "Pay for the plan", "effect": { "kind": "pays", "note": "charges the test card 10 USD" } },
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
| `title`, `purpose`, `audience`, `length` | No | What the user answered when planning. The storyboard shows them |
| `outputs` | No | Some of `16:9`, `9:16`, and `gif`. Without it, only the 16:9 videos are made |
| `mask` | No | What to blur in every frame: `{"css": "<selector>"}` for elements, `{"text": "<text>"}` for any element or field holding that text |
| `login` | No | How to sign in, described below |
| `steps` | Yes | One or more steps, in order |

## Steps

Each step has `do` and may have `caption`, `timeout` (seconds), and `effect`.

| `do` | Other fields | What it does |
|---|---|---|
| `open` | `url` | Opens the address, relative to the flow's `url` or absolute |
| `click` | `target` | Moves the pointer to the target and clicks it |
| `fill` | `target`, and `text` or `env` | Types into the field. `env` names an env variable whose value is typed and never shown |
| `select` | `target`, `value` | Chooses an option in a list |
| `key` | `key` | Presses a key, such as `Enter` or `Escape` |
| `wait` | `until` | Waits until the page shows something, described below. The edited video cuts a long wait, keeping 0.4 seconds at each end |
| `hold` | `seconds` | Keeps the screen still, so a caption can be read |

A caption is the text shown while the step runs and until the next caption, or for 4 seconds when no caption follows.
Write each caption as a short sentence about what the viewer sees, in the language of the video.
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
`frame` looks inside the iframe whose address holds that text, such as a payment form.
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
