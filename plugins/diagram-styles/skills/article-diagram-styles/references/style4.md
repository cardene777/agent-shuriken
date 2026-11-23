# The style4 rules

Read this whole file every time you draw or revise a style4 figure.
The words on this page are enough to draw style4.
The user's style4 samples are an add-on: when they are placed, the image generation also receives them as reference images for the look, and the plugin ships none of them.
Never draw from the name style4 alone; give the look below in words in the drawing instructions every time.

## How style4 is drawn

- Ground: plain white, with wide space around and between the objects. No paper color, texture, frame band, or shadow
- Lines: thin black pen lines with the natural wobble and slight changes of pressure of a hand-drawn line. Corners are rounded by hand. Never as uniform as a CAD drawing or a presentation template, and never bolder than the letters
- Letters: letters and numbers that look handwritten, dark black, rounded, and even enough to read at the printed size, placed beside or inside the objects they name. Never a common sans-serif or uniform vector type
- Palette: black as the base, a gray for hatching and dotted lines, and a few accents, mostly teal and orange. An accent marks the subject, range, or result that carries meaning, never every frame
- Fills: modest hatching and light rubs of the accent colors, only on the ranges, groups, and results that carry meaning. No filled heading bands, large solid cards, or gradients
- Marks: short arrows with hand-drawn heads, dotted lines for optional or indirect relations, and small icons particular to the subject, such as a document, a key, a database, or a clock, when they help tell the subjects apart. No meaningless ornaments
- Print: every relation still reads by position, shape, line style, and labels when the color is lost

A following skill may replace the ground, the black of the lines and letters, the gray, the first accent and its light fill, and the handwritten letters with the user's own colors and typeface.
Everything else on this page stays as written.

## What stays fixed and what does not

Every figure keeps the white ground, the hand-drawn lines, the handwritten letters, the limited palette, the hatching, small icons particular to the subject, and the way space is used.
The number of boxes, the direction they run in, left and right symmetry, rings, branches, and hierarchies are not fixed.
Decide the claim and the composition of a figure from the text.
Do not copy the people, robots, clocks, or other objects of a sample into a figure whose subject has nothing to do with them.

Choose the composition from the relation in the text.

| Relation | Composition |
|---|---|
| A process in time order or one direction | Left to right, or top to bottom |
| A cycle or repetition | A ring |
| The difference between two options | Left and right contrast |
| A comparison by context or condition | Top and bottom, or a diagonal offset |
| Several processes or checks | Branch and merge |
| Parent and child, or containment | Hierarchy or nesting |
| A center and several elements | Radial |
| A change of state | A state transition that fits the number of states and the return paths |

Use a row only when the reading direction is natural, as for time order or a left and right comparison.
Do not move the layout of a sample or of a reference figure of the book to a figure with another role.

## The style4 samples, when they are placed

The style4 samples are the images the user keeps in `~/.styles/diagram-style-samples/style4/`, and the catalog `~/.styles/style-catalog.json` records the layouts of each one.
Use them only when the catalog exists and two or more images are in that folder.
List them with a shell command and resolve each one to an absolute path, for example with `realpath`.
When the catalog is missing, when fewer than two images are there, or when the image generation cannot take reference images, draw from the words above alone, and tell the user which was missing.

Choose at least two style4 samples for each figure.
Read the `layouts` that the catalog records for the image whose `original_paths` name the sample, and prefer samples whose layouts are close to the figure's role.

| Figure | Samples to prefer |
|---|---|
| A flow | Samples recorded with a flow or a left-to-right layout |
| Roles or connections | Samples recorded with a map, a boundary, or a role layout |
| A comparison or a difference | Samples recorded with a comparison layout, and one sample close in composition |
| A state transition | Samples recorded with a state or a flow layout |
| Anything else | Open every sample and choose the two or more whose lines, letters, and space are closest |

When the catalog records no layouts for a sample, open the samples and choose by eye.

## Comparing after drawing

Place the drawn figure beside the style4 samples when they were used, and beside the accepted figures of the same book when it has any, at the same scale.
Without either, read the figure against the look above, one line at a time.
Do not accept the figure until every question below is answered yes.

1. Do the letters and lines alone make it look like the same series of figures?
2. Were meaningless ornaments left out without losing the hand-drawn feel?
3. Has it avoided falling back to a generic flowchart of rectangles and arrows?
4. Do the colors, hatching, dotted lines, and small icons help tell the subjects apart?
5. Does it sit with the accepted figures of other chapters even as a thumbnail?
6. Does it keep the series' look while choosing a composition that fits the relation in the text?
7. Has it avoided forcing figures with different roles into the same row or box layout?
