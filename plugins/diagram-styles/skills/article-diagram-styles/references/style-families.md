# The styles

Use only the finish profiles whose `status` is `active` in `~/.styles/style-catalog.json` for new figures.
When the catalog holds the two finishes below, use `illustrated/pen-technical` for the usual explanatory figure, and `technical-sketch/handdraft` for a figure that shows data structures, storage, conditions, amounts, and boundaries directly.
For any other active profile, its `line`, `fill`, `background`, and `lettering` in the catalog are the specification.

| Style | Specification | Reference images |
|---|---|---|
| Pen technical illustration | [Pen technical](pen-technical.md) | The images `sample_ids` of `pen-technical` names |
| Hand-drafted technical sketch | [Hand-drafted](handdraft.md) | The images `sample_ids` of `handdraft` names |
| Newsprint (retired) | [Newsprint](newsprint.md) | Read only for past records |
| style4, for book figures | [style4](style4.md) | The images in `~/.styles/diagram-style-samples/style4/` |

Keep the paper and background, outlines, fills, colors, and letters the same.
Decide the kind and number of subjects, the setting, the placement, the layout, and the amount from each figure's article and the reader's question.
Do not add the robots or time axes of a sample to every figure; take only how the needed subjects are drawn.
Keep the round dark letters and light hatching of the hand-drafted sketch, and the black core and local rubbing of the pen illustration.
Neither drawing everything in pale pencil nor drawing bold comic outlines reproduces the pen illustration.

Fix the content summary first.
The user's chosen real images may then be passed as style-only image inputs.
Keep them apart from the figure being redrawn or a layout draft, and record the role of each input in the drawing instructions and the run record.
Compare the content, the text, and the connections at full size and at the published width, then compare the drawing feel with the real reference images.
Never record a passing check as the user's approval of an image.

Do not bring back a `retired` profile as a choice; keep its records and images for comparing past records.
Never guess a style from an old number or a folder name of an image.
`python3 scripts/diagram_sample_catalog.py --validate` checks that the catalog and the images agree.
