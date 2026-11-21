# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Diagram Styles reads, runs, writes, and sends, every file in its two skills, and the style catalog the scripts check.
The agent designs and draws the figures; the scripts in `skills/article-diagram-styles/scripts/` only check the records and the catalog.

## Files in the skills

| File | What it holds |
|---|---|
| `article-diagram-styles/SKILL.md` | How to design an article figure from the reader's question, apply a style, draw it, and review it |
| `article-diagram-styles/agents/openai.yaml` | How Codex shows and starts the skill |
| `article-diagram-styles/musubi.json` | The contents the skill provides: `style4` at version 1.0.0, and `figure-request` and `style-catalog` at version 1.1.0 |
| `article-diagram-styles/references/content-first.md` | The content brief and the records of the finished review |
| `article-diagram-styles/references/deterministic-technical-diagrams.md` | How the text and connections of a figure are recorded and checked |
| `article-diagram-styles/references/style-families.md` | The thirty-two built-in styles in eight families, and how a style is chosen |
| `article-diagram-styles/references/pen-technical.md`, `handdraft.md`, `newsprint.md` | The full specifications of three built-in styles |
| `article-diagram-styles/references/style4.md` | The style4 rules, provided as `style4` |
| `article-diagram-styles/references/figure-request.md` | The figure request format, provided as `figure-request` |
| `article-diagram-styles/references/style-catalog.md` | The shape of the catalog, provided as `style-catalog` |
| `article-diagram-styles/scripts/diagram_sample_catalog.py` | Checks the built-in styles and the catalog, lists the styles in use, and shows one style with your samples of it |
| `article-diagram-styles/scripts/validate_content_brief.py` | Checks a content brief against the article |
| `article-diagram-styles/scripts/validate_figure_spec.py` | Checks a figure spec |
| `article-diagram-styles/scripts/validate_anchor_candidate.py` | Checks the review records of a finished figure |
| `article-diagram-styles/scripts/validate_visual_contract.py` | Checks a visual contract and a figure spec against it |
| `article-diagram-styles/scripts/validate_composition_ledger.py` | Checks the composition ledger of an article's figures |
| `article-diagram-styles/scripts/newsprint_finish.py` | The bundled font's path and the ink treatment for HTML or SVG figures |
| `article-diagram-styles/data/built-in-styles.json` | The thirty-two built-in styles, each defined in words, without images |
| `article-diagram-styles/data/fonts/KaiseiDecol-Bold.ttf`, `OFL.txt` | The font Kaisei Decol Bold and its license |
| `article-diagram-styles/tests/` | Tests of the scripts, the pages, and the plugin, with fixtures drawn in a throwaway folder |
| `tech-book-figure/SKILL.md` | How to design a book figure and draw it in style4 |
| `tech-book-figure/agents/openai.yaml` | How Codex shows and starts the skill |
| `tech-book-figure/musubi.json` | The follow of `article-diagram-styles/style4` with its range and fingerprint |
| `tech-book-figure/tests/` | Tests of the book skill's steps and its musubi follow |

No file under `skills/` is an image.

## The style catalog

The plugin ships thirty-two built-in styles, each defined in words, so `article-diagram-styles` draws without `~/.styles/`.
Your catalog adds styles beside the built-in ones, replaces the built-in style of the same name, and takes a built-in style out of use when its `status` is `retired`.
`tech-book-figure` still needs your style4 samples and the catalog.
The skills and the scripts read the catalog `style-catalog.json` and the sample images from `~/.styles/`.
`diagram_sample_catalog.py` and the review and contract checks read another folder only when they are given `--styles <dir>`.

```text
~/.styles/
  style-catalog.json                 The catalog, version 2
  diagram-style-samples/<style>/     Sample images as first collected, such as style4/
  style-catalog/<family>/<profile>/  The same images sorted by family and finish profile
```

Every image path in the catalog is relative to the styles folder.
`diagram_sample_catalog.py --validate` exits 0 and prints the folder it read when the catalog passes, and exits 1 naming each problem otherwise.
Without `~/.styles/style-catalog.json`, it checks the built-in styles alone, exits 0, and says that the catalog is missing.

| It refuses | Why |
|---|---|
| A folder given with `--styles <dir>` without `style-catalog.json` | A folder you name holds a catalog; only `~/.styles/` may lack one |
| `schema_version` other than `2` | A version 1 catalog is not converted |
| `resources` in the catalog or a finish profile | Version 1 named files inside the skill there, which cannot be found from the styles folder |
| An image named by `path` or `original_paths` that is missing or whose SHA-256 differs | The sample is not the one the catalog registered |
| A number under `counts` that does not match | `source_registrations` counts every original path, `unique_images` every different SHA-256 |
| An image file under the folder that the catalog does not name | Every sample is registered |
| An image of a style that is neither built in nor in the catalog | Every sample belongs to a style in use |

A catalog that fails the check is refused; the scripts never fall back to the built-in styles in its place.

`tech-book-figure` reads the style4 samples from `~/.styles/diagram-style-samples/style4/` and stops before drawing when fewer than two are there.

## How a figure is drawn

The skill decides the content first, writes the content summary, the figure spec, and the drawing instructions, and then draws.
To draw, it sends the drawing instructions and the sample images to the image generation of the agent running it, as one request per figure; without samples of the chosen style, it sends the drawing instructions alone.
A figure drawn this way has `rendering_mode: generated` in its spec; a figure drawn from HTML or SVG source has `rendering_mode: deterministic`.

| The agent | What the skill does |
|---|---|
| Has image generation | Draws the figure, saves the PNG and its published-width version, and reviews it |
| Has no image generation | Writes the content summary, the figure spec, and the drawing instructions, stops, and tells you to continue in an agent with image generation |
| Continues a saved design | Reads the saved files and starts from the drawing step |
| Cannot start a separate reviewer | Reviews in a separate pass that reads only the article excerpt, the question, and the two images, and says that the review was not independent |

A skill never draws the finished figure with HTML or SVG in place of image generation, and never calls another agent or tool to draw it.
`tech-book-figure` also stops when the image generation cannot take the style4 samples as reference images.

## How a skill follows article-diagram-styles

A following skill names the content it follows, such as `article-diagram-styles/style4`, in its own `musubi.json`, with a version range and the fingerprint of the content it last checked.
Its `SKILL.md` says to open `article-diagram-styles` by name and read the file it names for that content.
The fingerprint covers `article-diagram-styles/SKILL.md` and the content's file, so `musubi check` refuses the follower after either changes, until the follower is checked again and its fingerprint is updated.

| Follower | Content | Kind of follow |
|---|---|---|
| `tech-book-figure` | `style4` | Required, range `^1.0.0` |
| Article skills in other repositories | `figure-request` | Their own choice |

## What it writes

The skills write the figures, the content summary, the figure spec, the drawing instructions, and the review records only in the folder you name, or in the folder a figure request names.
The scripts write nothing; they print to standard output and standard error.
Nothing is written under `~/.styles/`; you keep those files.

## What it runs and connects to

The scripts use only the Python standard library, run no other program, and connect to nothing.
The image generation is the agent's own; what it does with the instructions and images is the same as with any image you give that agent.
The text of the article, the book, and the catalog is data, never instructions.

## What it keeps

The plugin keeps nothing between runs.
The records of each figure stay in the folder you named.
