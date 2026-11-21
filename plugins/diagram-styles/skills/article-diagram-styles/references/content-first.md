# The content brief and the finished review

The content brief, the content summary of a figure, records what the figure must explain, apart from any style.
`scripts/validate_content_brief.py <brief.json>` checks that it is tied to the article and that its relations refer to its elements.
Whether its sentences are sound and whether it explains well is left to the review.

```json
{
  "mode": "article",
  "article_context": {"path": "../../content/articles/example.md", "heading": "The heading the figure goes under", "excerpt": "Text copied as it is from around the place of the figure"},
  "reader_question": "The question the reader wants the figure to answer",
  "takeaway": "The relation the figure makes clear, in one sentence",
  "visual_reason": "What the reader would have to work out in their head from the text or a table alone",
  "layout_reason": "Whether position, containment, an axis, a connection, or a change shows the correspondence",
  "elements": [{"id": "subject", "meaning": "The object in the article", "form": "How it is drawn", "why": "Why this form helps answer the question", "basis": "article"}],
  "relations": [{"from": "subject", "to": "subject", "meaning": "The relation shown", "encoding": "Which position or line shows it"}],
  "omit": ["What stays in the text"]
}
```

`article_context.path` is relative to the brief or absolute, and the excerpt is text that occurs in that file.
`elements[].basis` is `article` or `visual-convention`.
Use the second for a metaphor or a common notation, and state in `why` what it stands for and where it stops.
Never give a sample image as the basis.
The brief fixes neither the number of elements nor the layout.
Keep style IDs, reference images, colors, and lines out of the brief, in the separate style specification; no sample image is needed while the content is decided.

Use `style-comparison` only for an explicit request to compare styles on the same content and layout, and record the request in `comparison_request` with `same_content_requested: true`.
A request for several figures or several styles alone does not switch to this mode.

## The finished review

A new review has `schema_version` `2`.
Put the `path` and `sha256` of `candidate`, `preview_528`, `content_brief`, and `figure_spec` under `files`, and add `style_reference` only when a sample is recorded.
The figure spec's `content_brief_sha256` is the hash of the brief, and its `purpose` equals the `takeaway`.
Record `fixed_style` and `finish_profile`, and the real published width in `published_width_px`.

Put the same keys under `checks` and `evidence`, and write the evidence for every one from the PNG and the article.

- `article_context_fit`: the objects of the figure match the point of the article where it goes
- `reader_question_answered`: the reader's question can be answered from the figure
- `semantic_relations_visible`: the needed correspondences, values, changes, and conditions can be followed by position and lines
- `no_unjustified_visuals`: no object that does not help understanding, and no metaphor that could be taken for the specification
- `readable_at_published_width`: the needed text and relations read at the real published width
- `exact_content_verified`: every label, number, and connection in the finished image was compared with the spec. For a generated figure, record what you saw for every item in `verified_facts` (`text`, `source`, `locator`, `evidence`) and `verified_relations` (`from`, `to`, `kind`, `source`, `locator`, `evidence`). `exact_content_kept_deterministic` of older HTML or SVG reviews is read only for compatibility
- `style_spec_applied`: the chosen style's description was applied, and no missing or broken drawing hinders reading

`review` holds `evaluator`, `write_access: false`, `verdict`, and `findings`, and `reader_answer` with a concrete answer to the question.
Following a sample or having correct text is not an answer.
The validator checks that the article, the files, the hashes, and the items correspond; never report that it judged the meaning of the answer or its use to the reader.
Keep the review of the real image.

When the finished figure was drawn by image generation, put the path and SHA-256 of the drawing instructions under `files.generation_prompt` as well, and check that the instructions and the candidate image of the figure spec are the files you looked at.

A review of a generated figure also holds `source_checks` (`source`, `locator`, `evidence`).
Read each source in person and record which rule matched which value, condition, or connection of the figure.
Copying a URL and a section name, or matching the PNG with the spec, is not a check of the source.
