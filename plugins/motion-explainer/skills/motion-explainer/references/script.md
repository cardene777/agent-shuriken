# Script format

A script is one JSON file that says what a video shows: who speaks, which things are on screen, what happens to them scene by scene, and the figures under the video that answer a question each.
Every word on screen comes from the script, and every picture from the theme or from the `images` of the script.
`examples/cache/script.json` and `examples/redelivery/script.json` are two whole scripts to start from.
`scripts/schema.py` lists every field below, and `build.py` refuses a field it does not list, naming the field.

## The script

| Field | Needed | What it holds |
|---|---|---|
| `lang` | yes | `en` or `ja`, the language of the page and of the player's buttons |
| `title` | yes | The title of the video, shown at the top of the frame and the page |
| `subtitle` | no | A shorter line under the title in the frame |
| `lead` | no | One sentence above the video that says what it follows |
| `cast` | no | The cast members by id, below |
| `images` | no | The pictures of this script alone by name, below |
| `objects` | no | The things on screen by id, below. An id holds no dot |
| `scenes` | yes | The scenes in order, below |
| `figures` | no | Up to eight figures under the video, below |

## `cast`

| Field | Needed | What it holds |
|---|---|---|
| `character` | yes | The id of a character of the theme |
| `label` | no | The name shown under the figure and before the line under the video |
| `tone` | no | The color of the name tag, a color name of the theme such as `primary` |
| `scale` | no | A size of this cast member alone; leave it out so the cast stands at one size |

The same character can be cast twice under two ids with two labels.

## `images`

| Field | Needed | What it holds |
|---|---|---|
| `file` | yes | The path of a PNG, WebP, JPEG, or SVG file, from the folder of the script |
| `px` | no | The longest side a raster picture is shrunk to, 1600 when left out |
| `quality` | no | The WebP quality of a raster picture, 82 when left out |

A name the theme already holds is refused, and an SVG drawing that runs a script or loads from outside is refused as in the theme.
Draw the states of a thing as separate pictures with one canvas size, such as `cache-empty.svg` and `cache-kept.svg`.

## `objects`

Every object has a `type`, one of the five below.
A beat names an object by its id, and a part of an object by the id of the object, a dot, and the id of the part, such as `card.pay` or `chart.boss`.

### `prop`: one picture with states

| Field | Needed | What it holds |
|---|---|---|
| `type` | yes | `prop` |
| `image` | yes | The picture shown first, its `base` state |
| `states` | no | Other pictures by state name, such as `{"kept": "cache-kept"}`; `swap` turns to one |
| `width` | no | The width in frame pixels, 160 when left out |
| `label` | no | The name of the thing, under the picture |

### `nodes`: things in rows, joined by lines

| Field | Needed | What it holds |
|---|---|---|
| `type` | yes | `nodes` |
| `title` | no | A name over the chart |
| `levels` | yes | The rows from the top, each a list of nodes |
| `edges` | no | `tree` (one trunk, one bus, one drop to each child), `string` (a tag hung from a thing by a string), or `false` for no lines; `tree` when left out |
| `gap` | no | The room between nodes in a row, 22 when left out |
| `rowGap` | no | The room between rows, 34 when left out |
| `size` | no | The picture size of every node, 86 when left out |

A node:

| Field | Needed | What it holds |
|---|---|---|
| `id` | no | The id a beat names the node by |
| `label` | no | The name under the picture |
| `sub` | no | A smaller second line of the name |
| `image` | no | The picture; a node without one shows a dashed box with a question mark until a state gives it one |
| `states` | no | Other pictures by state name |
| `hidden` | no | `true` keeps the node and its line out of sight until `show` |
| `tag` | no | `true` draws the node as a paper tag with a hole instead of a picture |
| `chip` | no | `true` draws the node as a large name alone |
| `float` | no | `true` puts the node beside the row instead of in it |
| `tone` | no | The color of the tag, a color name of the theme |
| `rot` | no | The tilt of a tag in degrees |
| `size` | no | The picture size of this node alone |
| `parent` | no | The id of a node of an earlier row it hangs from; the first node of the row above when left out |

The lines are measured from the layout, so a node popping in and a chart sliding into place keep the same lines as at rest.
A row whose nodes are all hidden takes no room, so a chart grows as its rows appear.

### `holder`: a rail, a folder, or a tray with things on it

| Field | Needed | What it holds |
|---|---|---|
| `type` | yes | `holder` |
| `back` | yes | The picture behind the things |
| `front` | no | A picture in front of them, such as the front of a folder |
| `anchor` | no | The anchor of `back` that gives the line, `hang` when left out |
| `line` | no | The line as a part of the height of `back`, when the picture has no anchor |
| `stand` | no | `true` stands the things on the line; they hang from it when left out |
| `width` | no | The width of `back` in frame pixels, 440 when left out |
| `itemWidth` | no | The width of every thing, 110 when left out |
| `labels` | no | `below` or `above`: where the names sit, on one level line for all things |
| `label` | no | The name of the holder itself |
| `items` | yes | The things, below |

A thing on a holder:

| Field | Needed | What it holds |
|---|---|---|
| `id` | no | The id a beat names it by |
| `image` | yes | The picture of the thing |
| `states` | no | Other pictures by state name, such as an empty hanger that later holds a suit |
| `x` | yes | Where it sits across the holder, from 0 at the left to 1 at the right |
| `width` | no | The width of this thing alone |
| `label` | no | Its name |
| `sub` | no | A smaller second line of the name |
| `hidden` | no | `true` keeps it out of sight until `show` |
| `tone` | no | The color of its tag |

### `screen`: the picture of a real page in a window

| Field | Needed | What it holds |
|---|---|---|
| `type` | yes | `screen` |
| `image` | yes | The capture of the page, as tall as the page is |
| `states` | no | Other captures by state name |
| `frame` | no | `browser` (a bar with an address) or `phone`, `browser` when left out |
| `address` | no | The address in the bar |
| `width` | no | The width of the window in frame pixels, 620 when left out |
| `view` | no | The height of the window over its width; a taller page shows its top and `focus` moves to the rest |
| `marks` | no | Places on the page by id, below |

A mark is a rect `[x, y, w, h]` in parts of the page, or an object:

| Field | Needed | What it holds |
|---|---|---|
| `rect` | yes | `[x, y, w, h]` in parts of the width and the height of the page |
| `kind` | no | `field` (a box that `type` writes into with a cursor) or `pill` (a round label); a plain outline when left out |

### `card`: a small screen or panel made of parts

| Field | Needed | What it holds |
|---|---|---|
| `type` | yes | `card` |
| `title` | no | The heading of the card |
| `note` | no | A smaller line after the heading |
| `band` | no | A color name: the heading becomes a colored band |
| `dot` | no | The color of the dot before the heading, `primary` when left out |
| `frame` | no | `browser` or `phone` around the card |
| `address` | no | The address in the bar of a `browser` frame |
| `width` | no | The width in frame pixels, 320 when left out |
| `parts` | no | The parts from the top, below |

Every part has `type`, an optional `id` that a beat names it by, and `hidden` to keep it out of sight until `show`.

| Part `type` | Fields | What it shows |
|---|---|---|
| `text` | `text`, `style` | Words; `style` is `title`, `lead`, `sub`, or `body`, `body` when left out. `**words**` makes them bold |
| `button` | `text`, `tone` | A button, `accent` when `tone` is left out |
| `row` | `parts`, `justify` | Parts side by side; `justify` is `start`, `center`, or `end` |
| `tags` | `items` | Pills, each with `id`, `text`, `tone`, and `hidden` |
| `checks` | `items`, `style` | A list of checks, each with `id` and `text`; `set` gives one the state `ok` or `ng`. `style` `plain` drops the boxes |
| `slots` | `count`, `cols`, `height`, `image`, `numbered` | Empty slots that `fill` fills with `image` one by one; `numbered` shows a number in each |
| `counter` | `start`, `total`, `unit` | A count such as 3/20; `count` and `fill` move it |
| `image` | `image`, `states`, `width`, `height` | A picture with states |
| `field` | `label`, `placeholder` | An input box that `type` writes into |

## `scenes`

A scene is what the frame shows between two cuts.
Scenes in a row with the same `chapter` make one step of the bar at the bottom, and a click on a step plays it from its start.

| Field | Needed | What it holds |
|---|---|---|
| `chapter` | no | The name of the step this scene belongs to, shown under the title |
| `cast` | no | The cast members on screen, by id or as `{"id": ..., "side": ...}` |
| `objects` | no | The objects on screen, one column each |
| `layout` | no | The objects as columns, each a list from the top, such as `[["browser"], ["cache", "origin"]]`; it wins over `objects` |
| `zoom` | no | The largest scale of the objects, 1.3 when left out |
| `gap` | no | The pause before the scene in milliseconds, 300 when left out |
| `beats` | yes | What happens, in order, below |

A cast member in `cast`:

| Field | What it holds |
|---|---|
| `id` | The id of the cast member |
| `side` | `left` or `right`; the cast alternates from the left when left out |

The cast stands in columns at the left and right edges, and the objects share the room between them, scaled to fit, so nothing overlaps.

## Beats

Every beat has `do`, the action, and may have these fields:

| Field | What it holds |
|---|---|
| `do` | The action, one of the table below |
| `wait` | The milliseconds after the beat before, which takes its natural time when left out |
| `hold` | How long this beat holds the screen, instead of its natural time |
| `fx` | An effect fired as the beat plays, below |
| `fxAt` | The object or part the effect fires at, instead of the target |

A beat fires its effect only when it plays.
A jump to a step, and a reader who asks for reduced motion, set the end state of each beat and fire no effect.

| Action | Fields | What it does |
|---|---|---|
| `say` | `who`, `text`, `face`, `act`, `emote` | The cast member says one short sentence in a speech bubble, with a face, a move, and a mark over the head |
| `face` | `who`, `face` | Changes the face, one of the faces of the character |
| `act` | `who`, `act` | Moves the figure: `hop`, `shake`, `write`, or `still` |
| `emote` | `who`, `emote` | Shows `!`, `?`, or `♪` over the head, or takes it off with `null`; a new scene takes it off |
| `enter` | `who`, `side` | Brings one cast member or a list of them on screen |
| `exit` | `who` | Takes one cast member or a list of them off screen |
| `show` | `target`, `column` | Shows a hidden part, or adds an object to the scene, in the column `column` or a new one |
| `hide` | `target` | Hides a part, or takes an object out of the scene |
| `press` | `target`, `text`, `tone` | Presses a button, and may change its words and color |
| `set` | `target`, `state`, `items` | Gives a part a state such as `ok`, `ng`, `done`, or `need`; for slots, `items` names the slot numbers |
| `mark` | `target`, `on` | Highlights a part, or takes the highlight off with `on` `false` |
| `text` | `target`, `text`, `sub`, `tone` | Rewrites the words of a part, a node's name, or a mark |
| `swap` | `target`, `state` | Turns a thing to another state picture, or back with `base` |
| `clear` | `target` | Puts one part or a list of them back as they started |
| `shake` | `target` | Shakes an object or a part |
| `fly` | `text`, `image`, `width`, `from`, `to`, `land` | Flies a picture, or a slip with words, from one object or cast member to another, and fires `land` where it lands |
| `stamp` | `target`, `text`, `image` | Stamps words on an object, pressed by the picture `image`, `stamp` when the theme has one |
| `focus` | `target`, `mark`, `rect`, `pad` | Moves and zooms a screen so a mark or a rect fills the window; without either it shows the top again |
| `tap` | `target` | Moves the pointer to a mark of a screen and clicks it |
| `fx` | `target` | Fires only its effect at the target |
| `fill` | `target`, `from`, `to`, `step`, `counter` | Fills slots one by one up to `to`, every `step` milliseconds, and moves the counter named by `counter` |
| `count` | `target`, `from`, `to`, `step`, `state`, `fxEvery` | Counts a counter up to `to`, gives it `state` at the end, and fires the effect every `fxEvery` numbers |
| `type` | `target`, `text`, `step` | Types the words into a field or a mark one character at a time |

## `fx`

`fx` is a word alone, such as `"don"`, or an object:

| Field | What it holds |
|---|---|
| `word` | A sound-effect word: `don`, `pon`, `kachi`, `shu`, `zuza`, or `gogo` |
| `size` | The size of the word, 88 when left out |
| `dx` | How far right of the center the word sits |
| `dy` | How far below the center the word sits, -46 when left out; give a negative number to put it over the thing |
| `rot` | The tilt of the word in radians, -0.12 when left out |
| `burst` | A burst with shards, `true` or its radius |
| `kira` | `true` adds a sparkle |
| `kdx` | How far right of the center the sparkle sits, 40 when left out |
| `puff` | `true` adds puffs of dust at both feet of the thing |
| `slash` | `true` adds a slash across the thing |
| `ring` | `true` adds a ring around the thing |

## `figures`

A figure sits under the video and answers one question with one sentence, drawn from the same objects as the video.

| Field | Needed | What it holds |
|---|---|---|
| `kind` | yes | `still`, `flow`, `compare`, or `table` |
| `question` | yes | The question the figure answers |
| `answer` | yes | One sentence that answers it |

| Kind | Fields | What it draws |
|---|---|---|
| `still` | `scene`, `labels` | The frame at the end of the scene numbered `scene` (from 0), with numbered marks on the things `labels` names, and their labels in a list |
| `flow` | `steps` | Two to six pictures in a row with arrows, each a step with `target`, `state`, and `text` |
| `compare` | `sides` | Two sides, each with `title`, a picture from `target` and `state`, and `points` as a short list |
| `table` | `columns`, `rows` | A table of one to five columns and one to twelve rows |

`target` in a step or a side names an object or a part with a picture, and `state` one of its states.
