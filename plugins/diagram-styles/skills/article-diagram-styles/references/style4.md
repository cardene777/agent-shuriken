# The style4 rules

Read this whole file every time you draw or revise a style4 figure.
Do not guess the look from the name style4 or from these words; use the style4 samples as real reference images.

## The style4 samples

The style4 samples are the images the user keeps in `~/.styles/diagram-style-samples/style4/`.
The plugin ships none of them.
List them with a shell command and resolve each one to an absolute path, for example with `realpath`.
When fewer than two images are there, stop before drawing and tell the user to put the style4 samples in that folder.
When the image generation cannot take them as reference images, stop before drawing; never draw from the name style4 and a description alone.

## What stays fixed

- A white ground and wide space
- Thin hand-drawn lines with a natural wobble, based on black
- Letters and numbers that look handwritten
- A few accents, mostly teal and orange
- Modest hatching, dotted lines, and small icons that add meaning
- Relations that can still be followed by position, shape, line style, and labels when the color is lost

Decide the claim and the composition of a figure from the text.
Do not copy the people, robots, clocks, or other objects of a sample into a figure whose subject has nothing to do with them.

## What stays fixed and what does not

Every figure keeps the white ground, the hand-drawn lines, the handwritten letters, the limited palette, the hatching, small icons particular to the subject, and the way space is used.
The number of boxes, the direction they run in, left and right symmetry, rings, branches, and hierarchies are not fixed.

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

## Choosing the references

Choose at least two style4 samples for each figure.
Read the `layouts` that `~/.styles/style-catalog.json` records for the image whose `original_paths` name the sample, and prefer samples whose layouts are close to the figure's role.

| Figure | Samples to prefer |
|---|---|
| A flow | Samples recorded with a flow or a left-to-right layout |
| Roles or connections | Samples recorded with a map, a boundary, or a role layout |
| A comparison or a difference | Samples recorded with a comparison layout, and one sample close in composition |
| A state transition | Samples recorded with a state or a flow layout |
| Anything else | Open every sample and choose the two or more whose lines, letters, and space are closest |

When the catalog records no layouts for a sample, open the samples and choose by eye.

## Comparing after drawing

Place the style4 samples, the drawn figure, and the accepted figures of the same book side by side at the same scale.
Do not accept the figure until every question below is answered yes.

1. Do the letters and lines alone make it look like the same series of figures?
2. Were meaningless ornaments left out without losing the hand-drawn feel?
3. Has it avoided falling back to a generic flowchart of rectangles and arrows?
4. Do the colors, hatching, dotted lines, and small icons help tell the subjects apart?
5. Does it sit with the accepted figures of other chapters even as a thumbnail?
6. Does it keep the series' look while choosing a composition that fits the relation in the text?
7. Has it avoided forcing figures with different roles into the same row or box layout?
