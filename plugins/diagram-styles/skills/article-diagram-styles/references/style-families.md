# The styles

This skill ships sixteen built-in styles in `data/built-in-styles.json`, each defined in words: its `line`, `fill`, `background`, `lettering`, and the kinds of figures it `suits`.
The user's catalog `~/.styles/style-catalog.json` may add styles beside them, replace one with the user's own definition and samples, or retire one, as [the style catalog](style-catalog.md) describes.
`python3 scripts/diagram_sample_catalog.py --list` prints every style in use with its source, and `--show <style>` prints one style's written specification and the user's samples of it.

| Family | Styles | What carries the figure |
|---|---|---|
| `line-drawing` | `handdraft`, `pen-technical`, `pencil-sketch`, `chalkboard` | Drawn lines, with light and local color |
| `drafting-and-flat` | `flat-vector`, `blueprint`, `isometric`, `minimal` | Exact geometry and flat areas |
| `painting-and-print` | `watercolor`, `newsprint`, `woodblock`, `retro-poster` | A painted or printed surface |
| `friendly` | `whiteboard`, `comic-panel`, `pixel-art`, `clay` | Playful materials |

## Choosing a style

A style the user or the figure request names comes first.
Without one, read the topic of the article and the kinds of its figures, compare them with the `suits` of each style in use, choose one style for the whole article, and tell the user the style and the reason.
When no style clearly fits, use `handdraft`, the hand-drafted technical sketch.
A style that is neither built in nor in the catalog, or one the catalog retired, is never drawn; show the user the list and let them choose.
Never guess a style from an old number or a folder name of an image.

## Full specifications

Three styles have a page with the full specification, named by their `specification` field.
For every other style, its `line`, `fill`, `background`, and `lettering` are the specification.

| Style | Specification | Reference images |
|---|---|---|
| Hand-drafted technical sketch | [Hand-drafted](handdraft.md) | The user's samples of `handdraft`, when the catalog registers any |
| Pen technical illustration | [Pen technical](pen-technical.md) | The user's samples of `pen-technical`, when the catalog registers any |
| Newsprint | [Newsprint](newsprint.md) | The user's samples of `newsprint`, when the catalog registers any |
| style4, for book figures | [style4](style4.md) | The images in `~/.styles/diagram-style-samples/style4/` |

## Applying the specification

Keep the paper and background, outlines, fills, colors, and letters the same.
Decide the kind and number of subjects, the setting, the placement, the layout, and the amount from each figure's article and the reader's question.
Do not add the robots or time axes of a sample to every figure; take only how the needed subjects are drawn.
Keep the round dark letters and light hatching of the hand-drafted sketch, and the black core and local rubbing of the pen illustration.
Neither drawing everything in pale pencil nor drawing bold comic outlines reproduces the pen illustration.

Fix the content summary first.
The user's samples of the chosen style may then be passed as style-only image inputs.
Keep them apart from the figure being redrawn or a layout draft, and record the role of each input in the drawing instructions and the run record.
Compare the content, the text, and the connections at full size and at the published width, then compare the drawing feel with the samples when there are any.
Never record a passing check as the user's approval of an image.

Do not bring back a `retired` style as a choice; keep its records and images for comparing past records.
`python3 scripts/diagram_sample_catalog.py --validate` checks that the built-in styles, the catalog, and the images agree.
