# How Excalidraw Diagram works

English · [日本語](how-it-works.ja.md)

This page explains what the plugin reads and writes, how the script lays a diagram out, every rule it checks, and how the SVG and PNG are made.
Everything here is done by the scripts in `skills/excalidraw-diagram/scripts/`, which use only the Python standard library.
`excalidraw_diagram.py` is the command; the other files hold the spec reader, the layout, the checks, the SVG and PNG steps, and the Mermaid converter.

## Commands

| Command | What it does |
|---|---|
| `build <spec.json or diagram.mmd>` | Reads the spec, lays it out, checks it, and writes `<name>.excalidraw`, `<name>.svg`, and `<name>.png` next to the spec, or in `--out`, named after the spec or `--name` |
| `check <file.excalidraw>` | Checks any Excalidraw scene against the rules below and changes nothing |
| `render <file.excalidraw>` | Writes `<name>.svg` and `<name>.png` from a scene, for example one edited in the Excalidraw editor, without changing the scene |
| `mermaid <diagram.mmd or ->` | Turns Mermaid text into a spec, printed or written to `-o` |

`--png auto` (the default) makes a PNG when it can, `--png skip` leaves it out, and `--png require` exits 4 when it cannot.
`--scale` sets how many PNG pixels each SVG pixel gets: 1, 2 (the default), or 3.

| Exit code | Meaning |
|---|---|
| 0 | Done |
| 1 | A check failed, or an arrow or label found no room. Nothing was written |
| 2 | The input is invalid: bad JSON, an invalid spec, Mermaid outside the subset, or a file that is not a scene |
| 3 | An output file exists that may not be replaced, as described under "Files it never replaces". Nothing was written |
| 4 | `--png require` was given and no PNG could be made. The other files were written |

## The spec

The agent writes the spec as JSON; the script rejects unknown keys, ids that do not exist, and values outside the lists below, and names every problem at once.

| Key | Values |
|---|---|
| `type` | `graph` (default) or `sequence` |
| `title` | Optional title, drawn at 28 px above the diagram |
| `direction` | Graphs only: `down` (default) or `right` |
| `order` | Graphs only: `auto` (default) reorders the nodes in a tier when that makes fewer arrows cross; `listed` keeps the order of the spec exactly |
| `style` | `clean` (default): straight outlines and Helvetica in the editor. `sketch`: Excalidraw's hand-drawn outlines and its hand-drawn font in the editor |
| `fill` | `solid` (default) or `hachure` |
| `node_gap` | Space between nodes in one tier, 40 to 400, default 60 |
| `tier_gap` | Space between tiers, 60 to 600, default 80 |
| `nodes` | `id`, `label`, and optional `lines`, `shape` (`box`, `ellipse`, `diamond`, `table`), `color`, `group`, `tier` |
| `edges` | `from`, `to`, and optional `label`, `line` (`solid`, `dashed`, `dotted`), `head` (`end`, `both`, `none`) |
| `groups` | `id`, `label`, and optional `color` and `tier` |
| `participants` | Sequence only: `id`, `label`, and optional `lines` and `color` |
| `messages` | Sequence only: `from`, `to`, and optional `label`, `line` (`solid`, `dashed`), `head` (`end`, `none`) |

Colors are `gray` (default), `blue`, `green`, `red`, `orange`, `yellow`, `violet`, and `teal`, each with an outline, a fill for shapes, and a paler fill for zones.
A spec holds at most 80 nodes and 160 edges, or 20 participants and 160 messages, and every line of text at most 120 characters.

## How a graph is laid out

1. Every node is sized from its text so the text, with its first line in bold as the SVG draws it, has at least 20 px on each side: a box is at least 160 by 60 px, an ellipse 140 by 60, and a diamond 140 by 80, and sizes are rounded up to 10 px. A diamond is twice as wide and tall as its text needs, because text fits only in its middle half. A `table` is a header with the label over a white body with the lines, left-aligned
2. Text is measured without font files, from the average width of each kind of character (narrow, wide, capital, and East Asian characters, which count as a full em) plus 6 % to spare, so the estimate is never smaller than the real text
3. Each node gets a tier: the one in the spec, or one more than the deepest node with an arrow into it. Arrows that close a loop are left out of this count, so the first node of a loop stays on top
4. Nodes in one tier start in the order of the spec and are centered on the same line, with `node_gap` between them and `tier_gap` between tiers. A gap grows to fit a label that has to sit in it: the label's size along the arrow plus 48 px. Tiers going down are aligned at their tops, and tiers going right at their left edges
5. With `order` `auto`, the tiers are then reordered to cut crossings between neighboring tiers. A sweep down moves each node to the average position of the nodes it links to in the tier above, and a sweep up does the same with the tier below; nodes without such links keep their place, equal positions keep the order of the spec, and up to four rounds of sweeps run. A link to a zone counts at the node inside it. The new order is kept only when it has fewer crossings than the order of the spec, so a diagram without crossings keeps its order. With `listed`, this step is skipped
6. A group is laid out the same way inside its zone first, with its own tiers reordered the same way, and the zone then takes part in the outer layout as one item, so zones never overlap each other or nodes outside them. A zone keeps 50 px around its nodes, has its label 16 px from its left and 10 px from its top, and is wide enough for its label

## How arrows are drawn

- An arrow leaves the side of its shape that faces the other shape, and both ends stop 12 px outside the outline. An arrow back against the flow goes around the side its two ends lean toward: the left when both sit, on average, left of the middle of the diagram, and otherwise the right (the top or the bottom when the flow goes right). An arrow that answers one going the other way runs beside it instead. A loop back to the same node leaves and re-enters across the flow
- Arrows that share a side are spread along it. Two sides that face each other and carry the same arrows get matching ports so the arrows run straight. A diamond has one port per tip, and extra arrows move to a free tip on the side of their other end
- Between its ends an arrow is routed along horizontal and vertical lines: the edges of every shape grown by 10 px, the middles of the gaps between them, and the ports. The route is the cheapest path where each pixel costs 1 (1.25 along a shape's edge line), each bend costs 40, running on the same line as another arrow costs 400 per step plus 4 per shared pixel, running along a zone's dashed outline costs 3 per pixel, and each point where it crosses an arrow routed before it, or passes within 8 px of the end of one, costs 150. Arrows are routed shortest first. Bends prefer the middle between the two ends
- Arrows with bends are written with `roundness: null`, so the Excalidraw editor draws straight stretches with sharp corners instead of smoothing them into a curve
- Each label is placed beside the longest straight stretch of its arrow first, 8 px from the line, at the middle or further along, above or below a horizontal stretch and right or left of a vertical one. A spot is taken only when the label touches no shape outline (it may sit wholly inside a zone), stays 10 px from a zone's dashed outline on either side, and keeps clear of other text (4 px) and of every line (3 px)

When the scene fails a check, the script first routes the arrows again at the same spacing without the cost for crossing, because steering around one arrow can push two others onto one line.
When an arrow or a label still finds no room, the script lays the diagram out again with 1.5 and then 2.25 times the gaps, and says so.
When that fails too, it stops with exit code 1 and names the arrow.

## How a sequence diagram is laid out

Participants sit in a row with the same height, at least 60 px apart and far enough apart for the labels between them.
Each has a dashed lifeline.
Messages go one per row from top to bottom, as horizontal arrows between lifelines, with the label centered above the arrow in the first gap it crosses.
A message to oneself is a small loop to the right of the lifeline with its label beside it.
Message arrows are not bound, because Excalidraw binds arrows to shapes, not to lines.

## The checks

The checks run on the finished scene, the same way for a file the plugin wrote and for one edited in the Excalidraw editor.
Each problem names the shapes by their text.

| Rule | A problem when |
|---|---|
| `format` | An element has no id, an id is used twice, a position or size is not a number, a text has no text or font size, or an arrow or line has fewer than two points |
| `reference` | A text, binding, or `boundElements` entry points at an element that does not exist or does not point back |
| `overlap` | Two shapes share area without one holding the other |
| `spacing` | Two shapes that are not nested and not in the same Excalidraw group are less than 40 px apart |
| `zone-padding` | A shape that holds other shapes (a zone) keeps less than 50 px around one of them |
| `text-fit` | Text bound to a shape is larger than the room inside it: the shape minus 5 px on each side, or for an ellipse and a diamond the largest rectangle inside them, minus the same |
| `text-center` | Text bound to a shape is more than 2 px from the shape's middle on an axis it is centered on |
| `font-size` | Any text is under 16 px |
| `text-overlap` | Free text crosses a shape's outline (it must be wholly inside or wholly outside, 4 px from the outline, or 8 px from a zone's outline so it does not read as sitting on it), or two texts overlap |
| `label-on-line` | An arrow or line passes through free text, or through an arrow label other than its own |
| `arrow-through` | An arrow or line passes through a shape other than a zone |
| `arrow-end` | An arrow end is inside a shape, closer than 8 px to the shape it is bound to, or more than 30 px from it |
| `unbound` | An arrow end is within 30 px of a shape but not bound to it, so it would not follow the shape |
| `curve` | An arrow or line with more than two points has a roundness, so Excalidraw would draw it as a curve |
| `arrow-overlap` | Two arrows or lines run along the same horizontal or vertical stretch for more than 2 px |

Warnings do not fail the check. `crossing` names every pair of arrows that cross or touch, counting a point where they meet, where one ends on the other, or where they come within 3 px, and says how many such points there are. Some graphs cannot be drawn without a crossing, so `build` and `check` still exit 0 and print each pair on a line starting with `Warning: crossing:`.

Notes do not fail the check either: boxes that hold one line of text, shapes much larger than their text, text with emoji, and element types the checks do not cover (images, frames, and freehand drawings).

## What the file holds

The `.excalidraw` file is the JSON format the Excalidraw editor saves: `type`, `version` 2, `source`, `elements`, `appState`, and `files`.
Every element carries the fields the editor writes itself.

- Element ids come from the spec: `node:<id>` and `node:<id>:text`, `node:<id>:fields` for a table's body, `zone:<group>`, `edge:<n>` and `edge:<n>:label`, `participant:<id>`, `message:<n>`, and `title`
- Text in a shape is bound to it (`containerId`), so it moves with the shape; labels of arrows and zones are grouped with their arrow or zone
- A text element in Excalidraw has one font, size, and weight for all its lines, so a node's name and its detail lines look the same in the editor. Only the SVG and PNG draw the name bold
- Arrows are bound at both ends with `focus` 0 and `gap` 12, and the shapes list them in `boundElements`, so they follow when a shape moves
- Boxes and zones have rounded corners; tables, diamonds, and ellipses do not. Text uses Excalidraw font 2 (Helvetica) in the clean style and font 5 (its hand-drawn font) in the sketch style
- Seeds come from the ids and the timestamp is fixed, so the same spec always gives the same file
- A top-level `generator` entry holds a SHA-256 digest of the elements, `appState`, and `files`. The editor drops this entry when it saves, which is how the plugin tells that a file was edited

## The SVG and the PNG

The SVG is drawn by the script from the scene, with 24 px of margin and the scene's background color.
It draws rectangles, ellipses, diamonds, text, arrows with their heads, and lines; other element types are left out and named.
Shapes have clean outlines, the first line of text in a shape (a node's name) is bold, and text uses fonts already on the viewer's machine (a sans-serif list that includes Japanese fonts, or a monospace list for Excalidraw's code fonts), so it does not imitate the hand-drawn look.
The second line of the SVG is a comment with a SHA-256 digest of the rest of the file.

The PNG is a screenshot of the SVG taken by a browser that is already installed.
The browser is found in this order:

1. The path in `EXCALIDRAW_DIAGRAM_BROWSER`; the value `none` turns the PNG off
2. Playwright's `chrome-headless-shell`, if Playwright already put one in `~/Library/Caches/ms-playwright` or `~/.cache/ms-playwright`
3. Google Chrome, Chromium, or Microsoft Edge in `/Applications` or `~/Applications` on macOS, in the usual install folders on Windows, or on the `PATH`

The browser runs headless with a new profile in the system's temporary folder, deleted when it finishes, with background networking, sync, extensions, and crash reports turned off, and with a rule that makes every host name fail to resolve.
It opens only the local SVG, with the window set to the SVG's size and `--scale` as the device scale factor; the scale is lowered when a side would exceed 16000 px.
The PNG is kept only when the browser finishes within 90 s and the image has exactly the expected size, and it gets a text chunk with a SHA-256 digest of its image data.
When no browser is found or the screenshot fails, the reason is printed after `PNG skipped:`, and the `.excalidraw` file and SVG are still written.

## Files it never replaces

Before writing, `build` and `render` look at each output file that already exists.

| File | Replaced without asking when |
|---|---|
| `.excalidraw` | Its `generator` digest still matches its content, so nobody has saved or edited it since the plugin wrote it |
| `.svg` | Its digest comment still matches the rest of the file |
| `.png` | Its text chunk still matches its image data |

Any other existing file stops the command with exit code 3 before anything is written, and the agent asks you before running again with `--replace`.
`render` never writes the `.excalidraw` file it reads.
`mermaid -o` does not replace any existing file without `--replace`.
Files are written to a temporary file in the same folder and then renamed, so a failed write never leaves half a file.

## What it keeps

| What | Where | Until |
|---|---|---|
| The spec, the `.excalidraw` file, the SVG, and the PNG | The folder you chose, usually `docs/images/` in a project | You delete them |
| The browser profile for one PNG | The system's temporary folder | The PNG is made or fails |

Nothing else is written, and no settings or history are kept.

## The Mermaid subset

Flowcharts start with `flowchart` or `graph` and `TD`, `TB`, or `LR` (`BT` and `RL` are refused).

| Mermaid | Spec |
|---|---|
| `A[text]`, `A(text)`, `A[(text)]`, `A[[text]]`, `A{{text}}`, `A>text]` | A box |
| `A([text])`, `A((text))` | An ellipse |
| `A{text}` | A diamond |
| `"quoted text"` inside the brackets, and `<br>` | Text with brackets in it, and a line break: the first line is the label, the others are `lines` |
| `-->`, `---`, `-.->`, `-.-`, `==>`, `===`, `<-->` | An arrow, a line without a head, a dashed arrow, a dashed line, an arrow, a line, an arrow with two heads |
| `-->|label|`, `-- label -->`, `-. label .->`, `== label ==>` | An arrow with a label |
| `A --> B --> C`, `A & B --> C` | One arrow per pair |
| `subgraph id [Title]` ... `end` | A group, one level deep |
| `classDef`, `class`, `style`, `linkStyle`, `click`, `%%` comments, `%%{init}%%` | Ignored, and named in a note |

Sequence diagrams start with `sequenceDiagram`.

| Mermaid | Spec |
|---|---|
| `participant A`, `participant A as Label`, `actor A as Label` | A participant |
| `A->>B: text`, `A-->>B: text` | A message with an arrow, solid or dashed |
| `A->B: text`, `A-->B: text` | A message without a head, solid or dashed |
| `A-)B`, `A--)B` | A message with an arrow, solid or dashed |
| `autonumber`, `title Text` | Numbered labels, and the title |
| `activate`, `deactivate`, and `+`/`-` after the arrow | Ignored, and named in a note |

Anything else, such as `loop`, `alt`, notes, arrows ending in `x` or `o`, nested subgraphs, and other diagram types, stops the conversion with the line number.

## What it never does

- Download or install anything, start an MCP server or a container, or use the network
- Send your diagrams, specs, or code anywhere
- Replace a file it did not write, or that changed since, without `--replace`
- Change a scene it is asked to check or render
- Copy Excalidraw's code or fonts: the plugin writes the open file format with its own code

## Environment variables

| Variable | Use |
|---|---|
| `EXCALIDRAW_DIAGRAM_BROWSER` | The browser to use for the PNG, or `none` to make no PNG. Tests point it at a stand-in |
