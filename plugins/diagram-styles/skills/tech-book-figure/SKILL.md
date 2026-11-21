---
name: tech-book-figure
description: Designs the figures of a commercially published technical book, deciding each figure's purpose and composition first and checking its role beside the text, its figure number, its caption, and its readability in black and white printing, then draws it as a PNG in the fixed style4 from the user's style4 samples in ~/.styles. Use when making, revising, or comparing a figure for a book.
---

# Tech book figure

A book figure is not decoration.
It shows in a short time the structure, order, comparison, or boundary that the text alone makes hard to follow.
Design the content of the figure first, then apply only the look of style4, and draw it.
What stays fixed across all figures is the visual language, not the composition; never choose the kind or layout of a figure from style4 or from a reference figure.

Talk to the user in the language they write in.
Write the labels in the figure in the language of the book.
This skill works in any agent that reads `SKILL.md`.
Where it says to ask the user, use the agent's own question tool when it has one, and otherwise ask in the chat with numbered options.
Run each step that lists or reads files as a shell command.

## The style4 rules

Write in the `style4` format of the `article-diagram-styles` skill: open the `article-diagram-styles` skill by name and read the file it names for `style4`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `article-diagram-styles` skill is not installed, do not start: tell the user that `article-diagram-styles` is missing and how to install it, then stop.

Read the whole style4 file before every figure, and apply only its colors, lines, lettering, space, and hand-drawn feel.
Decide the kind and layout of the figure from the purpose in the text.

## The style4 samples

The style4 samples are the user's images in `~/.styles/diagram-style-samples/style4/`, and the user's catalog `~/.styles/style-catalog.json` records the layouts of each one.
This skill ships no sample images and never creates, changes, or deletes anything under `~/.styles/`.

If `~/.styles/style-catalog.json` is missing, stop before drawing and tell the user to put the catalog and the sample images under `~/.styles/`, as the `style-catalog` format of `article-diagram-styles` describes.
List the images in that folder with a shell command, such as `ls ~/.styles/diagram-style-samples/style4/`.
If fewer than two images are in `~/.styles/diagram-style-samples/style4/`, stop before drawing and tell the user to put the style4 samples there.

## Steps

1. Read the text the figure goes into and who reads it
2. Write the conclusion the figure conveys in one sentence
3. Choose one role for the figure: structure, flow, cycle, comparison, branch and merge, hierarchy, boundary, state transition, screen explanation, or another role the text needs
4. Decide the main subject, the start, the end, the relations, the labels, and what goes back into the text
5. When one figure cannot explain it, split it into an overview and a detail figure
6. Read the style4 rules above and apply only the look
7. Choose two or more style4 samples close to the figure's role, as the style4 rules say. Do not use figures from the text, screenshots, or figures in progress in place of the style4 samples
8. Draw the finished figure with the image generation of the agent running this skill, one figure at a time. Pass the chosen style4 samples as reference images, and give the content design and the style4 look separately in the instructions. Say for each reference image whether it is a reference for the look or for the content and layout
9. After drawing, check the content, the technical accuracy, the text in the figure, the arrow connections, the space, and black and white printing
10. Place two or more style4 samples and two or more figures already accepted in the same book side by side and look at them. Do not accept a figure that meets any of the rejection conditions below; fix the instructions and draw again

If the image generation cannot take the style4 samples as reference images, stop before drawing and tell the user that this agent cannot draw style4 figures.
Do not draw from the name style4 and a description alone.

### When the agent has no image generation

If the agent running this skill has no image generation, finish steps 1 to 7, then write the content summary, the figure spec, and the drawing instructions into the folder the user names, and stop.
The content summary is `<figure>.summary.md` with steps 1 to 5, the figure spec `<figure>.spec.md` with the figure number, the caption, the alternative text, the composition, the labels, and the chosen style4 samples, and the drawing instructions `<figure>.prompt.txt` in the format below.
Tell the user which files you wrote, and to continue this skill in an agent that has image generation, naming the same folder.
Do not draw the finished figure with HTML or SVG in place of image generation, and do not call another agent or tool through a shell command to draw it.

### Continuing from a saved design

When the user continues in an agent with image generation and names a folder that holds a saved design, read the saved content summary, figure spec, and drawing instructions, and start from the drawing step without redoing the design.
Check first that the style4 samples the spec names are still in `~/.styles/diagram-style-samples/style4/`; when one is missing, choose again from the samples there.

## Choosing the composition

Do not fix the figures of a book to a row or to one template of boxes and arrows.
Choose the composition from the relation the text conveys.

| Role of the figure | Basic composition |
|---|---|
| A process in time order or one direction | Left to right, or top to bottom |
| A cycle or repetition | A ring |
| The difference between two options | Left and right contrast |
| A comparison by context or condition | Top and bottom, or a diagonal offset |
| Several checks or processes | Branch and merge |
| Parent and child, or containment | Hierarchy or nesting |
| Relations from a center to several elements | Radial |
| A change of state | A state transition that fits the number of states and the return paths |

Use a row only when the reading direction is natural, as for time order or a left and right comparison.
Do not choose a row because a reference figure is a row.
Even for the same role, change the space and placement for the number of items, the main path, and the return paths.

## Fixing the style reference

- The style4 samples are only the images in `~/.styles/diagram-style-samples/style4/`
- Pass at least two style4 samples as reference images, and list their paths in the `Reference Samples` line of the instructions
- Figures already accepted in the book may be used to keep chapters consistent, but never in place of the style4 samples
- Screenshots, screen layouts, figures in progress, and the figure being revised are references for content or layout only
- Do not ban icons or all ornaments at once. Leave out meaningless ornaments, but keep the hand-drawn letters, the natural wobble of the lines, the modest hatching, and the small meaningful icons, which are part of style4

## Rejection conditions for visual identity

Do not accept a figure that meets any of these, even when its white ground, palette, and line width each look right.

- The letters look like a common sans-serif or uniform vector type, clearly unlike the handwriting of the style4 samples
- The lines and rounded corners are as uniform as a CAD drawing or a presentation template, with no hand-drawn wobble
- It is made only of rectangles and arrows, with no small icon, line style, or hatching that identifies the subject
- It is forced into a row or a left and right symmetry that does not fit the relation in the text, so a cycle, branch, hierarchy, or return path is hard to read
- Several figures of a chapter repeat the same box layout whatever their roles
- The teal, orange, and blue accents are used mechanically as frame colors, without the meaning and texture of the style4 samples
- The space, text size, or density of shapes is far from the style4 samples or the accepted figures of the book
- Placed side by side as thumbnails, it looks like a common flowchart, a business document, or a vector slide figure

## Design rules for publication

- Give each figure one claim, and split a complex system into subsystems
- Explain the purpose in the text before the figure, and its meaning and limits after it
- A figure visualizes a relation or an order the text explained; it is not a summary of the text
- Keep the text in the figure to short noun or verb phrases. Move long explanations, reasons, cautions, and exceptions back into the text
- Do not add conditions of a specification or an implementation in the figure alone. Check the figure against the claims of the text and the specification
- Do not pack different kinds of information, such as a screen, an API, a data model, and a state transition, into one figure without a reason
- When a color carries meaning, make the same distinction with line style, shape, position, or a label
- Do not use light-colored text or low-contrast lines, and never use pale yellow for text
- Even when the colors stay for the online edition, accept a figure only when it reads printed in black and white
- Explain every abbreviation in the figure in its caption or the text
- Make the figure number and caption match the reference in the text, and put a short explanation right after the figure
- Prepare alternative text, so that a reader who cannot see the figure still gets its claim

## What stays out of a figure

- Long explanations of more than five items in one figure
- A paragraph of the text pasted as it is
- The details of operating steps, exception conditions, every field of an API, or every column of a database
- Comparison axes with different purposes, or several main paths
- Generic summary bands such as "Point", "Note", or "Key point"
- A legend that tells things apart by color alone

## The drawing instructions

Write the content and the look apart, in this form.

```text
Purpose: Show that design, implementation, and tests are aligned on the specification
Diagram role: Structure
Composition: Short arrows from the specification in the center to design, implementation, and tests
Labels: Specification, Design, Implementation, Tests
Move to text: The detailed role of each artifact and the exception conditions
Fixed Style: style4 (fixed)
Reference Samples: absolute paths of two or more style4 samples
Book Consistency References: absolute paths of two or more accepted figures of the same book
Visual Profile: white ground, thin hand-drawn lines, wide space, black as the base with teal and orange as supporting colors
Avoid: long text, tables, note fields, overlapping arrows, distinctions by color alone, conditions not in the text
```

Decide `Composition` yourself.
Take `Visual Profile` from the style4 rules, and do not change the composition to fit the style name.
Pass the same images as listed in `Reference Samples` to the image generation as reference images.
When you also pass figures of the book, list them apart from the style4 samples in `Book Consistency References`.

## Done when

- The text refers to the figure, and the figure has a number and a caption
- The figure's claim agrees with the text, the specification, and the design
- The text in the figure reads at the printed size
- Lines, arrows, and labels do not overlap, and every start and end is correct
- It reads in black and white printing without relying on color differences
- The alternative text conveys the figure's claim
- The PNG is saved in the folder the user names and was looked at on screen
- Two or more style4 samples and two or more accepted figures of the book were placed side by side, and the figure meets none of the rejection conditions
- The composition fits the figure's role and does not copy a reference figure's layout without a reason

## Design principles this follows

These public guides were summarized: simplify the figure, keep the text and the figure close, give a short caption, and keep the meaning in black and white.

- Google Technical Writing: Illustrating
- Concordia OpenText: Visuals
- IEEE Author Center Books: Create Original Graphics
- Seismological Society of America: Art Guidelines
- Microsoft Style Guide: Graphics, Design, and Media
