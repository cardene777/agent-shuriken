# The newsprint finish

`finish_profile: newsprint` of the `illustrated` family is a finish of past records.
When the catalog marks it `retired`, it is read only to compare past figures and is never chosen for new ones.
This page also describes the bundled typeface and ink treatment, which any HTML or SVG figure may use.

## The finish

Its samples are the images `sample_ids` of `newsprint` names in `~/.styles/style-catalog.json`; they are optional style vocabulary, never required and never copied.
What stays fixed is flat newsprint, engraved black ink lines and halftone, a restrained muted teal, and the shapes and dry-brush wear of type.
The samples are one style in several compositions, not several designs.

Choose the concrete objects from the subject.
Do not move the safes, desks, gears, or bookshelves of a sample onto another subject.
Build one figure from the handoffs, containment, merges, and changes of state of the needed subjects, and do not end with parts lined up at equal intervals.
Keep a character only when the user named it; a robot in a sample is not the default subject.
Newsprint is a finish of paper, ink, and type, not an order to draw old machines, wooden furniture, or a workshop.

## The style passed to the image generation

Decide the purpose, the subjects, the structure of meaning, the layout, the connections, and the places of the text for each figure first.
Then pass this style and draw a scene particular to the subject as one image.

```text
Finish Profile: newsprint
Style: flat warm-cream newspaper, charcoal engraved contours, coarse black halftone,
subtle paper pores, restrained muted-teal spot ink. One integrated editorial diagram.
Style input: the textual paper, ink, palette, line and lettering specification only.
Do not pass a finished reference scene as an image input. Start from the article content brief.
Subjects and composition: derive only from the target explanation. Do not copy the reference
scene, character, machinery, furniture, props or layout. Retain a character only when the user explicitly specified it.
Draw exact labels, technical connectors and boundaries as part of this complete image.
Integrate lettering and arrows with the illustration; verify every value and relation afterward.
Avoid: physical cut-paper relief, cast shadows, glossy 3D, sticker sheets, UI cards,
pseudo text, ornamental frames or props that obstruct the diagram.
```

Keep the same paper and ink, and change the composition to fit the claim: a ratio, a merge, a boundary, a cycle, or a comparison.
When a drawn object runs into the planned path of a line, do not lay text or lines over it; fix the scene or the placement.

## Type and ink for HTML or SVG

The real font and its license sit in this skill's `data/fonts/`: Kaisei Decol Bold and `OFL.txt`.
`scripts/newsprint_finish.py` finds the font relative to its own folder and never depends on a working `output/` folder or an operating system font.

```python
import sys
from pathlib import Path

D = Path("<folder that contains this SKILL.md>")
sys.path.insert(0, str(D / "scripts"))
from newsprint_finish import font_file, svg_defs

font = font_file()  # The bundled Kaisei Decol Bold; stops when it is missing.
definitions = svg_defs(width=1600, height=1000)
```

Rasterize the exact strings from the real file `font` and embed them in the SVG.
Put `definitions` at the top of the SVG, and wrap the letters and connections in this group.

```xml
<g filter="url(#newsprint-press)" mask="url(#press-pores)">
  <!-- Exact glyphs, arrows, boundaries, and numbers -->
</g>
```

The treatment adds paper grain from a fixed seed, a slight wobble of the outlines, wear, and ink spread.
It keeps the glyphs and line widths, and never drops letters or arrowheads.
Do not add paper feel with color or shadow alone; match letters, lines, and drawing as if printed on one paper.
Record the hash of the font and the treatment values used in the drawing record.

Check the figure with the article excerpt at full size and at the published width.
Judge first whether it answers the reader's question, then whether the labels, lines, ink, paper, and connections read.
Never reuse the subjects, words, or numbers of a sample as the basis of another figure.

## When the finished figure is generated

The letter shapes, paper, and ink above are a style specification for the finished figure.
Composing a real font and the print filter is a choice for HTML or SVG figures, not an order to replace the letters the image generation drew.
With image generation, draw the objects, letters, and connections as one image, and check its spelling, numbers, readability, and style apart.
