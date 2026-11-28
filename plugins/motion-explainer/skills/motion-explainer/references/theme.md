# Theme format

A theme is a folder that holds `theme.json` and the pictures it names, as paths from the folder.
It sets the look of every video built with it: the colors, the font, the characters with their faces, and the pictures of things the video shows.
The skill ships one theme, `themes/pixel`, with four pixel-art bodies; another plugin passes its own folder to `build.py`.
`scripts/schema.py` lists every field below and refuses a field it does not list.

## `theme.json`

| Field | Needed | What it holds |
|---|---|---|
| `name` | no | The name of the theme |
| `font` | yes | The CSS font list of the video, such as `"\"Hiragino Sans\", system-ui, sans-serif"` |
| `colors` | yes | The colors of the video, below |
| `fx` | no | The colors of the effects, below |
| `floorY` | yes | The line the cast stands on, in pixels of the 896 x 504 frame, from 1 to 504 |
| `mark` | no | The name of an image shown before the title, such as a logo |
| `characterScale` | no | How many frame pixels one pixel of a face picture takes, 1 when left out. Every character keeps this one scale, so the cast stands at one size |
| `pixelated` | no | `true` keeps the sharp pixels of pixel art: the faces are not smoothed, and they are stored without loss |
| `characters` | yes | The characters, by id, below |
| `images` | no | The pictures of things, by name, below |

## `colors`

Every color is a CSS color. The engine names each one as a CSS variable of the same name.

| Field | What it colors |
|---|---|
| `ink` | Text and outlines |
| `sub` | Quieter text, such as a placeholder or a caption |
| `line` | Thin lines and empty boxes |
| `paper` | Cards and the inside of screens |
| `bg` | The background of the frame |
| `panel` | The bar of a browser frame and the tray of slots |
| `slotLine` | The dashed outline of an empty slot or an empty picture |
| `primary` | The main color: step numbers, buttons, chart lines when `edge` is left out, the bar at the bottom |
| `primary2` | The shadow of `primary` |
| `primarySoft` | A pale `primary` for tags and pills |
| `accent` | The color of change: marks on a screen, stamps, the default button |
| `accent2` | The shadow of `accent` |
| `accentSoft` | A pale `accent` for a check that failed |
| `yellow` | Highlights, such as a node or a label being pointed at |
| `yellowSoft` | A pale highlight behind marked text |
| `ok` | A check that passed |
| `okSoft` | A pale `ok` behind a passed check |
| `edge` | The lines of a chart |

## `fx`

| Field | What it colors |
|---|---|
| `fill` | The inside of bursts and puffs |
| `shade` | The shade of bursts and puffs |
| `line` | The outline of bursts and shards |
| `ink` | The dark parts of an effect |
| `accent` | The bright parts of an effect |
| `sfx` | Two colors of a sound-effect word: its fill and its edge |

## `characters`

A character is one figure with several faces; the script casts it under an id of its own.
Every face of one character is cut by the box that holds all of them, so the faces swap without a jump.

| Field | Needed | What it holds |
|---|---|---|
| `faces` | yes | Each face by name, as the path of a PNG, WebP, or JPEG with a transparent background |
| `default` | no | The face shown before any line, the first face when left out |
| `head` | no | Where the bubble sits, as a part of the character's height above its feet, 1 when left out |
| `scale` | no | A scale of this character alone, on top of `characterScale` |

The faces are the poses of the character too: the four bodies of `themes/pixel` have `wait`, `explain`, `surprised`, and `cheer`.

## `images`

| Field | Needed | What it holds |
|---|---|---|
| `file` | yes | The path of a PNG, WebP, JPEG, or SVG file |
| `px` | no | The longest side the picture is shrunk to, 200 when left out. Give about twice the size it shows at |
| `crop` | no | `false` keeps the whole canvas; the picture is cut to what is visible when left out |
| `group` | no | A name shared by the layers of one thing, such as the back and the front of a folder; they are cut by one box so they stay in register |
| `jpeg` | no | `true` stores a large opaque picture, such as a background, as JPEG |

An image named `background` fills the frame behind everything, and images named `ok` and `ng` are the marks of passed and failed checks.
An SVG file is inlined as it is, and the build refuses one that runs a script, has an event handler, holds a `foreignObject`, or loads anything from outside.

### Anchors

A picture can name points on it in a JSON file next to it with the same name, such as `rail.json` next to `rail.png`.

| Field | What it holds |
|---|---|
| `anchors` | Each point by name, as `[x, y]` in pixels of the picture file |

A holder hangs its items from, or stands them on, the line of the anchor its `anchor` names, such as `hang` on a rail or `rim` on a folder.
The build turns the pixels into parts of the picture after it is cut.
