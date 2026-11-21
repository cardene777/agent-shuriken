---
name: article-diagram-styles
description: Designs an explanatory figure for an article from the questions its reader would have, applies a drawing style from the user's style catalog in ~/.styles as a separate step, and draws and checks the PNG. Use when a skill that writes an article asks for its figures, or when the user asks to compare drawing styles on the same figure.
---

# Article figures

The finished figure lets a reader who reads it with the article text follow how objects correspond, how values change, and where conditions and boundaries lie.
Rich drawing, closeness to a style sample, or passing the format checks does not make a figure finished.

Talk to the user in the language they write in.
Write the labels in the figure in the language of the article.
This skill works in any agent that reads `SKILL.md`.
Where it says to ask the user, use the agent's own question tool when it has one, and otherwise ask in the chat with numbered options.

All files of this skill are next to this `SKILL.md`.
Below, the absolute path of that folder is written as `D`.
Run each script as a shell command, and put `D=<folder that contains this SKILL.md>` at the start of the same shell command.

## Styles and files

This skill ships no sample images.
The user keeps the style catalog `style-catalog.json` and the sample images under `~/.styles/`, laid out as [the style catalog](references/style-catalog.md) describes.
Read the catalog and the samples only from `~/.styles/`, unless the user names another styles folder; then pass that folder to the scripts with `--styles <dir>`.

Before designing, check the catalog with a shell command.

```bash
D=<folder that contains this SKILL.md>; python3 "$D/scripts/diagram_sample_catalog.py" --validate
```

If `~/.styles/style-catalog.json` is missing, stop before drawing and tell the user to put the catalog and the sample images under `~/.styles/`, as [the style catalog](references/style-catalog.md) describes.
When the check fails for another reason, show the user the lines it prints and stop before drawing.
Never create, change, or delete anything under `~/.styles/`; the user keeps those files.

Write the figures, the content summary, the figure spec, the drawing instructions, and the review records only in the folder the user names, or in the folder named in the figure request of the calling skill.

## Reading the request

Use the `article` mode by default.
A request for several figures for an article, or for figures in other styles, asks for the points the article explains and the number of figures; do not turn it into the same figure painted over in several styles.
Use the `style-comparison` mode only when the user says to compare styles on the same content and layout, and do not count comparison candidates as finished figures of the article.
When another skill asks for figures, it writes the request in [the figure request format](references/figure-request.md).
When the user says not to ask in between, take it as delegating production decisions, and do not record that the user approved each image.

## Designing from the article

1. Take the article file, the heading the figure goes under, and the text before and after it from the request. Do not cut the figure loose from the article and widen its subject.
2. **Before opening any sample image**, decide the question the reader wants answered, the one sentence the figure makes clear, the relation the text alone makes hard to follow, the objects and relations the figure keeps, and the layout. Save them as the content summary in `content-brief.json` and run `python3 "$D/scripts/validate_content_brief.py" <brief>` as a shell command. [The content brief](references/content-first.md) gives its format.
3. Decide the subjects and their forms from the article. To explain an implementation, a state, or data, draw its keys, values, records, arrays, boundaries, and where processing happens. Add people, devices, chips, and the like only when their role answers the reader's question, and never to fill space.
4. Choose a layout that shows this figure's relation through containment, a shared axis, correspondence, branching, or a before and after. A layout name records the design; it does not order you to fit a ready-made layout. Boxes may stand for storage areas and data structures; do not swap boxes for metaphors or illustrations just to avoid them.

Keep the content summary and the style specification apart.
When you want to change the subjects or the layout after seeing a sample, go back to the article and the reader's question and check the reason.
Do not change them because of what a sample shows, where it places things, or how much it holds.

## Elements and space

Do not judge a figure by how much of the canvas it fills.
Place the needed objects and relations at a readable size first, then decide the space.
Enlarging a figure with few elements and giving a figure with much information a wide area are different decisions.

- A figure of short phrases or a few objects uses text about the size of the article text, and keeps space around the objects and inside the outer frame. Do not blow up the heading to fill empty space
- A figure with much information spreads its objects, conditions, and connections until they read. Do not cut information to match density, and do not enlarge a small figure to the density of a large one
- A frame of paper or an area surrounds the content and its groups. Do not add scrolls, large enclosures, ornaments, or objects to fill the leftover canvas
- Once the text is readable, adjust the spacing between elements, the reading path, and the outer margin before enlarging the whole figure. Fit the canvas proportions to the content when needed
- In the drawing instructions, state whether the figure has few or many elements, the text size, and how much space goes between elements and inside the frame. Do not ask in every figure to fill the canvas or to use the full published width
- Redo the size and placement only when the figure does not read at the published width. Reject a figure that stretches a few elements to the frame, and do not reject a figure only for its space or for a density different from a sample

## Applying a style

Choose from [the styles](references/style-families.md) and the `finish_profiles` of `~/.styles/style-catalog.json`, using only profiles whose `status` is `active`.
Do not ask again for a style the user or the request already named.
Keep the article's drawing style across its figures, unless the user names several styles.

**A style name and its written specification are enough to draw.**
A sample image is neither a required input nor the correct answer.
Open a sample only when needed and only after the content is fixed, and put its line, fill, paper, palette, and lettering into words.
When the user picks a real image as the style reference, it may be passed to the image generation after the content design is done.
In the drawing instructions and the records, tell the content apart from the style-only reference, and never move the reference's subjects, labels, values, or layout into the figure.
Give the reviewer the same style specification and reference images.

A style specification may fix the line, fill, background, palette, lettering, and print treatment.
It does not fix the kinds or number of subjects, the setting, the layout, the reading order, the amount of information, or a shared label band.
Do not judge a figure by being bolder than a sample or holding as many objects as a sample.

Draw people only when being a person explains a relation in the article.
Draw an AI agent as a cute non-human character, and do not replace it with a person because the style changed.
Do not draw people with realistic faces or bodies.

## Drawing

Draw the finished figure with the image generation of the agent running this skill, as one image.
From the article, fix the objects, the claim, the exact labels, the numbers, and the needed connections and conditions; do not fix the coordinates or sizes of each object or draw identical boxes, so that objects, text, arrows, and fills are drawn in one style.
Do not draw everything in the excerpt; limit the explanation to the relation the content summary chose, and do not fill unspecified attributes with empty records or other protocol fields.

- A figure with identifiers, numbers, tables, state transitions, or technical connections can still be drawn by image generation. Write the `facts` and `relations` with their sources, and pass the short labels as they are. [Text and connections](references/deterministic-technical-diagrams.md) gives the steps
- Do not generate only a background or a frame and lay it over a ready-made box diagram. When you correct text locally or combine images, check that the letters, lines, and objects of the whole figure still match
- Use HTML or SVG only when the user asks for a figure that can be redrawn from source, or when the figure clearly calls for it. Technical text alone is not a reason to switch. Record the method you used, and never claim a real font for letters the image generation drew
- Save the finished PNG, the published-width version, the drawing instructions, the figure spec, the content summary, and the review. A figure drawn by image generation has `rendering_mode: generated` and may still have `exact_content: true`; its `source_file` is the finished image and its `generation_prompt_file` the drawing instructions
- The figure spec's `purpose` is the summary's `takeaway`, tied to the content by `content_brief_sha256`. Run `python3 "$D/scripts/validate_figure_spec.py" <spec>` as a shell command, adding `--require-source-labels` only for HTML or SVG figures. The format check does not replace looking at the text and connections in the finished image

### When the agent has no image generation

If the agent running this skill has no image generation, finish the design, then write the content summary, the figure spec, and the drawing instructions into the folder the user names, and stop.
The content summary is `content-brief.json`, the figure spec `<figure>.figure.json` with `rendering_mode: generated`, and the drawing instructions `<figure>.prompt.txt`, which name the style reference images by their paths under `~/.styles/`.
Tell the user which files you wrote, and to continue this skill in an agent that has image generation, naming the same folder.
Do not draw the finished figure with HTML or SVG in place of image generation, and do not call another agent or tool through a shell command to draw it.

### Continuing from a saved design

When the user continues in an agent with image generation and names a folder that holds a saved design, read the saved content summary, figure spec, and drawing instructions, and start from the drawing step without redoing the design.
Check the summary with `validate_content_brief.py` first; when the article excerpt no longer matches the article, tell the user and design again.

## Checking the finished figure

Give an independent reviewer the **article excerpt, the reader question, the finished PNG, and the published-width version** first.
Do not give the samples or the maker's view of how good the figure looks first.
If the agent cannot start a separate reviewer, review the figure yourself in a separate pass that reads only the article excerpt, the reader question, the finished PNG, and the published-width version, and tell the user that the review was not independent.

First try to answer the reader's question concretely from the figure, and record from which positions and connections the objects, values, conditions, and changes read.
A figure whose nouns and arrows can only be read aloud does not explain enough.
Send back for correction any object that plays no role, any metaphor that misleads, any needed relation left out, and any mismatch with the article.
Then compare every label, number, bracket, and connection between the finished image and the spec one by one, and send errors back to the drawing step.
Judge readability at the published width apart from how well the style is reproduced.
When the request carries a style over from earlier figures, open the earlier finished images too and compare whether objects, text, arrows, and fills are drawn as one.
Paper grain, halftone, or hatching alone does not pass a style, and a copy of the subjects or layout is not asked for.

Save `anchor-candidate-review.json` with `schema_version: 2`.
Record the evidence for the fit to the article and the content summary, the answer to the reader's question, the relations that carry meaning, the absence of needless objects, readability at the published width, the exactness of the text and connections in the image, and the use of the style specification.
Do not show the figure until `python3 "$D/scripts/validate_anchor_candidate.py" --review <review>` passes as a shell command.
A sample-match check from an old record does not pass a new candidate.

## Several figures

Plan the place, the reader's question, and the content summary of every figure of the article first, if you like.
Produce one figure at a time: draw, combine, check at the published width, compare the content, and review it before starting the next. Do not draw figures in parallel.
Open the PNG directly to check a figure; do not start a local server.

When the first finished figure sets the finish for the rest, keep the user's approval of an image apart from delegated production.
A new `visual-contract.json` has `schema_version: 2` and fixes the description of the style; `style_reference` is optional, and the drawing style records no object density.
Check it with `validate_visual_contract.py`.
When the user names several styles for an article, keep one contract per style and apply it to the later figures of that style after its first figure is finished.
The shared `composition-ledger.json` lists the contract IDs it uses in `visual_contract_ids` and ties each figure to its contract; never force one style onto a figure of another style.
Record each figure's claim and layout in `composition-ledger.json`, and check it with `validate_composition_ledger.py`.
Do not change a layout only because the same layout repeats; check instead that no two figures make the same point and that each answers a different question of the article.
There is no quota of layout kinds per number of figures.

Do not use a figure the user rejected for its quality or purpose as a quality reference later, and do not treat it as finished because its format checks still pass.
After a correction, check the changed parts and their direct regressions again, without reviewing unrelated figures or the whole article again.
Record when each image generation starts, and keep the time spent generating, combining, and checking apart.
When a generation does not return, check whether an image was saved before trying once more.
