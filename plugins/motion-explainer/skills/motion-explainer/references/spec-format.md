# Spec format

A spec is one JSON file next to a folder of SVG files.
The agent writes both for each subject: the JSON says what happens, and the SVG files are the art.
`motion_explainer.py check` reads the spec and every SVG it names, and `render` inlines them into one HTML page.

## Top level

| Field | Required | What it holds |
|---|---|---|
| `lang` | yes | `en` or `ja`, the language of the readers. It picks the interface words |
| `title` | yes | The name of the page, at most 40 wide |
| `lead` | yes | One sentence under the title that says what the video shows, at most 120 wide |
| `direction` | yes | The art direction of this subject (below) |
| `narrator` | yes | The character who says the line of each scene (below) |
| `parts` | yes | The objects on the stage, one to twelve (below) |
| `scenes` | yes | The running example, two to twelve scenes in order (below) |
| `figures` | no | The figures under the player, each answering one question (below) |

Width counts a CJK character as 2 and any other character as 1.

## `direction`

The art direction is written before any SVG, so every part of one subject shares one look.

| Field | Required | What it holds |
|---|---|---|
| `summary` | yes | One or two sentences: the world the art borrows from, the shapes, the line, and the mood |
| `stage` | yes | The background color of the stage, as `#rrggbb` |
| `accent` | yes | The color that marks a part that changes in a scene, as `#rrggbb` |

## `narrator`

| Field | Required | What it holds |
|---|---|---|
| `name` | yes | What the narrator is called, at most 16 wide |
| `art` | yes | The path of the narrator's SVG, relative to the spec |
| `states` | yes | The narrator's expressions, such as `calm`, `alert`, and `glad`. The first is where it starts |

## `parts`

| Field | Required | What it holds |
|---|---|---|
| `id` | yes | Lower-case letters, digits, and `-`, unique in the spec |
| `name` | yes | The label under the part, at most 20 wide |
| `art` | yes | The path of the part's SVG, relative to the spec |
| `states` | yes | The states the part can be in. The first is where it starts |
| `at` | yes | `[x, y]`, the top left of the part on the stage, in percent of the stage's width and height |
| `size` | yes | `[w, h]`, the size of the part, in percent of the stage's width and height |

## The SVG files

Each file is one `<svg>` with a `viewBox`.
An element with `data-when="<state> <state>"` shows only while the part (or the narrator) is in one of those states, so one drawing holds every state and only what differs is drawn twice.
Elements without `data-when` always show.

`check` refuses a file that:

- names a state in `data-when` that the part does not declare
- holds `<script>`, `<foreignObject>`, `<iframe>`, `<object>`, `<embed>`, or `<image>`
- has an attribute starting with `on`
- has an `href` or `xlink:href` that does not start with `#`
- has `url(` that does not point at `#`, or `@import`

So the page loads nothing from outside and runs nothing but its own player.

## `scenes`

| Field | Required | What it holds |
|---|---|---|
| `id` | yes | Lower-case letters, digits, and `-`, unique in the spec |
| `chapter` | yes | The name of the chapter button, at most 16 wide |
| `line` | yes | The one sentence the narrator says, at most 80 wide |
| `narrator` | yes | The narrator's state in this scene |
| `set` | no | `{"<part id>": "<state>"}`, the parts that change state |
| `move` | no | `{"<part id>": [x, y]}`, the parts that move, in percent of the stage |
| `ms` | no | How long the scene plays, from 800 to 20000 milliseconds. 2800 when left out |

A part keeps its state and place from the scene before.
The player marks only the parts whose state or place differs from the scene before, so each scene shows one change.

## `figures`

Every figure has `question` (at most 60 wide, ending in `?` or `？`), `answer` (one sentence, at most 120 wide), and `kind`.
The figures draw the same SVG as the video, so they share its look.

| `kind` | Fields | What it draws |
|---|---|---|
| `still` | `scene`, `labels` (`{"<part id>": "<text>"}`) | The stage at the end of that scene, with a label beside each named part |
| `flow` | `steps` (two to six of `{"part", "state", "text"}`) | The parts in the named states, in order, joined by arrows |
| `compare` | `sides` (two of `{"title", "part", "state", "points"}`) | Two parts side by side, each with its title and one to four points |
| `table` | `columns`, `rows` | A table whose rows have as many cells as there are columns |
