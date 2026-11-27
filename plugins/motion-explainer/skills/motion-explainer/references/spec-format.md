# Spec format

A spec is one JSON file next to a folder of SVG files.
The agent writes both for each subject: the JSON says what happens, and the SVG files are the art of the parts.
The cast takes its bodies from `characters/` of the skill, so the spec names a body, not a drawing.
`motion_explainer.py check` reads the spec and every SVG it names, and `render` inlines them, the body sheets, and the effects core into one HTML page.

## Top level

| Field | Required | What it holds |
|---|---|---|
| `lang` | yes | `en` or `ja`, the language of the readers. It picks the interface words |
| `title` | yes | The name of the page, at most 40 wide |
| `lead` | yes | One sentence under the title that says what the video shows, at most 120 wide |
| `direction` | yes | The art direction of this subject (below) |
| `cast` | yes | Who says the line of each scene, one to four (below) |
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

## `cast`

| Field | Required | What it holds |
|---|---|---|
| `id` | yes | Lower-case letters, digits, and `-`, unique in the cast |
| `body` | yes | One of `robot`, `android`, `guide`, and `drone`, each used by at most one cast member |
| `name` | yes | What the cast member is called, shown under the body and in the bubble, at most 16 wide |
| `at` | no | `[x, y]`, the top left of the body on the stage, in percent. Without it, the cast member stands under the stage beside the bubble |

A body is a pixel-art sheet of four square poses side by side, in the order `wait`, `explain`, `surprised`, and `cheer`, with a transparent background.
On the stage a body takes 13 percent of the stage width and 23.11 percent of its height, so `x + 13` and `y + 23.11` stay at most 100.
`check` refuses the old `narrator` field and names `cast` in its place.

State names in `parts` use lower-case letters, digits, and `-`.

## `parts`

| Field | Required | What it holds |
|---|---|---|
| `id` | yes | Lower-case letters, digits, and `-`, unique in the spec |
| `name` | yes | The label under the part, at most 20 wide |
| `art` | yes | The path of the part's SVG, relative to the spec |
| `states` | yes | The states the part can be in. The first is where it starts |
| `at` | yes | `[x, y]`, the top left of the part on the stage, in percent of the stage's width and height |
| `size` | yes | `[w, h]`, the size of the part, in percent of the stage's width and height |

The stage is 16:9, and `x + w` and `y + h` stay at most 100, here and after every move.
The drawing keeps the shape of its `viewBox` inside its box, and the mark and the name label of a part hug the drawing.

## The SVG files

Each file is one `<svg>` with a `viewBox`, at most 100,000 bytes.
An element with `data-when="<state> <state>"` shows only while the part is in one of those states, so one drawing holds every state and only what differs is drawn twice.
Elements without `data-when` always show.
Ids may repeat across files: each copy on the page gets its own ids, and `href="#..."` and `url(#...)` follow them.

`check` refuses a file that:

- names a state in `data-when` that the part does not declare
- holds `<script>`, `<foreignObject>`, `<iframe>`, `<object>`, `<embed>`, or `<image>`
- holds `<style>`, which would restyle the whole page; styles go in attributes
- holds an element that is not a drawing element, such as `<a>` or `<animate>`
- has an attribute starting with `on`
- has an `href` or `xlink:href` that does not start with `#`
- has `url(` that does not point at `#`, `@import`, or `javascript:`
- declares a DOCTYPE or an entity

So the page loads nothing from outside and runs nothing but its own player.

## `scenes`

| Field | Required | What it holds |
|---|---|---|
| `id` | yes | Lower-case letters, digits, and `-`, unique in the spec |
| `chapter` | yes | The name of the chapter button, at most 16 wide |
| `line` | yes | The one sentence the speaker says, at most 80 wide |
| `speaker` | no | The `id` of the cast member who says the line. The first cast member when left out |
| `pose` | no | The speaker's pose: `wait`, `explain`, `surprised`, or `cheer`. `explain` when left out; every other cast member waits |
| `fx` | no | The effect of the scene (below) |
| `set` | no | `{"<part id>": "<state>"}`, the parts that change state |
| `move` | no | `{"<part id>": [x, y]}`, the parts that move, in percent of the stage |
| `ms` | no | How long the scene plays, from 800 to 20000 milliseconds. 2800 when left out |

A part keeps its state and place from the scene before.
The player marks only the parts whose state or place differs from the scene before, so each scene shows one change.
`check` refuses a scene that changes no part and keeps the speaker and the pose of the scene before.

### `fx`

| Field | What it holds |
|---|---|
| `burst` | A part id. An impact burst goes off behind that part, with chips flying off it |
| `word` | One sound-effect word: `don` (impact), `pon` (pop), `kachi` (click), `shu` (swish), `zuza` (skid), or `gogo` (rumble) |
| `at` | A part id the word lands next to. The `burst` part when left out |

`fx` holds at least one field, and a `word` needs `burst` or `at`.
The effects go off once the moved parts have landed, and a part that moves lands in smoke puffs without any field.
Opening a chapter and reduced motion fire no effect.
The effects come from the bundled Sakuga VFX core, drawn on a canvas behind the parts for the burst and over the page for the rest.

## `figures`

Every figure has `question` (at most 60 wide, ending in `?` or `？`), `answer` (one sentence, at most 120 wide), and `kind`.
The figures draw the same SVG as the video, so they share its look.

| `kind` | Fields | What it draws |
|---|---|---|
| `still` | `scene`, `labels` (`{"<part id>": "<text>"}`, one to six) | The stage at the end of that scene, with a numbered mark on each named part and its label in the list beside the stage |
| `flow` | `steps` (two to six of `{"part", "state", "text"}`) | The parts in the named states, in order, joined by arrows |
| `compare` | `sides` (two of `{"title", "part", "state", "points"}`) | Two parts side by side, each with its title and one to four points |
| `table` | `columns` (one to five), `rows` (one to twelve) | A table whose rows have as many cells as there are columns |

A page holds at most eight figures.
The widths are at most 40 for a label, 30 for the text of a step, 24 for the title of a side and for a column, 40 for a point, and 48 for a cell.
