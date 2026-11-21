# The figure request

A skill that writes an article asks `article-diagram-styles` for its figures in this format.
It writes the request as `figure-request.json` in the folder where the figures go, and tells the user to run `article-diagram-styles` on that folder, or runs it itself when both skills are installed.
The request carries the article and where the figures go; it never carries a style sample, a layout, or a drawing.
It may name a structure for a figure; the structure and the style are chosen apart, and any pair can be drawn.

```json
{
  "request_version": 1,
  "article": "../content/articles/example.md",
  "output_folder": ".",
  "published_width_px": 528,
  "mode": "article",
  "delegated": true,
  "finish_profile": "pen-technical",
  "figures": [
    {
      "heading": "Why the value changes twice",
      "excerpt": "The value goes from 7 to 9, and the next step makes it 11.",
      "reader_question": "What is the value after the first step?",
      "structure": "timeline"
    }
  ]
}
```

| Field | Required | What it holds |
|---|---|---|
| `request_version` | Yes | `1` |
| `article` | Yes | The article or draft file, relative to the request or absolute |
| `output_folder` | Yes | The folder the figures and their records are written to, relative to the request or absolute. Nothing is written outside it |
| `published_width_px` | Yes | The width in pixels the article shows a figure at; the published-width version is made at this width |
| `mode` | Yes | `article`; `style-comparison` only when the user asked to compare styles on the same content and layout; or `structure-comparison` only when the user asked to compare the same content in different structures |
| `comparison_request` | With `style-comparison` or `structure-comparison` | The user's words that asked for the comparison. For `structure-comparison` they also give the number of structures; without a number, three are drawn |
| `delegated` | No | `true` when the user said not to ask in between. It delegates production decisions; it is not the user's approval of each image |
| `finish_profile` | No | A built-in style, or a style of `~/.styles/style-catalog.json` whose `status` is `active`, by the name `--list` prints. Without it, the skill chooses one from the article as the styles page says |
| `figures` | Yes | One entry per place in the article that needs a figure |
| `figures[].heading` | Yes | The heading the figure goes under |
| `figures[].excerpt` | Yes | Text copied as it is from the article around the place of the figure |
| `figures[].reader_question` | No | The question the calling skill expects the figure to answer. The skill still decides the question from the article |
| `figures[].structure` | No | A built-in structure, or a structure of `~/.styles/style-catalog.json` whose `status` is `active`, by the name `--structures` prints. Without it, the skill chooses one from the reader's question as the structures page says |

The excerpt must occur in the article file as it is; `validate_content_brief.py` refuses a content summary whose excerpt does not.
When the article changes after the request, write the request again.
