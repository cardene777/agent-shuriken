# Text and connections

An article figure is drawn as a finished image by image generation by default.
Do not switch to HTML or SVG only because it holds identifiers or numbers.
Use the same figure spec with sources for either way of drawing.

## Before drawing

Put every label shown into `facts` with its `text`, `kind`, `source`, and `locator`.
Put `from`, `to`, `kind`, `source`, `locator`, and `exact` into `relations`.
When exact values or technical relations appear, set `exact_content: true`, apart from how the figure is drawn.
Mark an example from the article as an example, and never take it for a real value of the specification.

A figure drawn by image generation has `rendering_mode: generated`.
Have the objects, the letters, the arrows, the lines, and the fills drawn as one image.
Do not first make an empty box diagram with fixed coordinates and sizes and ask only for the texture of its frames.

## After drawing

Record the finished image as `source_file` and the drawing instructions as `generation_prompt_file`.
`validate_figure_spec.py` checks only the sources and that the files exist; it does not judge whether the image is correct.

The reviewer opens the source at each `source` and `locator`, reads the rule, and records what the source says in `source_checks`.
Then they look at every `fact` and every `relation` in the finished PNG one by one.
They check the spelling of formal names, the numbers, the brackets, and every start, end, arrowhead, and containment, and record what they read in `verified_facts` and `verified_relations` of the review.
Fix the candidate on any typo, missing or extra item, or unclear connection, and check the fixed image.
When the image's hash changes, never reuse an earlier look.
Check that it reads as a figure at the published width too.

## When drawing from source

When the user asks for it, or the figure calls for HTML or SVG, set `rendering_mode: deterministic` and record the source as `source_file`.
Record a font file and its weight only when a real font was used; the skill's `data/fonts/` holds one, Kaisei Decol Bold.
Check that each fact matches the source with `--require-source-labels`, and look at the drawn PNG as well.
With either way of drawing, never treat a passing format check as passing the style or the explanation.
