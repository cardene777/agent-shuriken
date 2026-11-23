# Diagram Styles

Figures for articles and technical books, designed from the reader's questions first and drawn in one of thirty-two built-in styles or a style from your own catalog in `~/.styles/`.

English · [日本語](README.ja.md)

A figure drawn to look like a sample often copies the sample's objects and layout and stops explaining the text.
This plugin keeps the two decisions apart.
It first decides what the figure must explain from the article or the book, then applies only the look of a style, and checks the finished image against the text.
The plugin ships thirty-two built-in styles, each defined in words, and no sample images, so `article-diagram-styles` draws without `~/.styles/`.
It also ships sixteen built-in structures, such as a process flow, layers, or a before and after, and the structure of each figure is chosen apart from the style, from the reader's question.

```
Article or book ──> Design the content ──> Choose a style ──> Draw with the ──> Check the text, the ──> PNG in the
(the text and       (reader question,      (built-in, or      agent's image     connections, and the    folder you name
the reader)         takeaway, relations)   ~/.styles/)        generation       published width
```

| Skill | What it makes |
|---|---|
| `article-diagram-styles` | An explanatory figure for an article: a content summary, a structure and a style, each built in or from your catalog, the finished PNG and its published-width version, and the review records |
| `tech-book-figure` | A figure for a technical book in the fixed style4, drawn from its written rules, with a figure number, a caption, alternative text, and readability in black and white printing. Your style4 samples and your theme file are added when you place them |

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install diagram-styles@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add diagram-styles@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install diagram-styles@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/diagram-styles/skills/article-diagram-styles   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Styles

The plugin ships thirty-two built-in styles in `skills/article-diagram-styles/data/built-in-styles.json`, each defined in words by its line, fill, background, lettering, and the kinds of figures it suits.

| Family | Styles |
|---|---|
| Line drawing | `handdraft`, `pen-technical`, `pencil-sketch`, `chalkboard` |
| Drafting and flat | `flat-vector`, `blueprint`, `isometric`, `minimal` |
| Painting and print | `watercolor`, `newsprint`, `woodblock`, `retro-poster` |
| Friendly | `whiteboard`, `comic-panel`, `pixel-art`, `clay` |
| Dimensional | `low-poly`, `papercraft`, `diorama`, `toy-blocks` |
| Notebook and archive | `notebook-doodle`, `grid-memo`, `patent-drawing`, `old-map` |
| Ink and print | `sumi-e`, `risograph`, `copperplate`, `paper-cut` |
| Signs and screens | `pictogram`, `metro-map`, `terminal-screen`, `sticker` |

`article-diagram-styles` draws without `~/.styles/`.
Name a style, or let the skill choose one from the topic of the article and the kinds of its figures; it tells you the style it chose and why, and uses `handdraft` when no style clearly fits.
This command lists the styles in use.

```bash
python3 <plugin folder>/skills/article-diagram-styles/scripts/diagram_sample_catalog.py --list
```

## Structures

The plugin ships sixteen built-in structures in `skills/article-diagram-styles/data/built-in-structures.json`, each defined in words by the relation it shows, its parts, its reading order, and the subjects it fits and does not fit.
A structure decides which parts a figure has and in which order they are read; a style decides how they are drawn.
The structure is chosen apart from the style, so any structure can be drawn in any style.

| Group | Structures |
|---|---|
| Flow and order | `process-flow`, `message-sequence`, `timeline`, `cycle` |
| Structure and containment | `layers`, `tree`, `nesting`, `network` |
| Comparison | `side-by-side`, `before-after`, `two-axis-matrix`, `correspondence-table` |
| State and change | `state-machine`, `decision-branch`, `quantity-trend`, `journey-map` |

`article-diagram-styles` chooses the structure of each figure from the reader's question and records it in `structure`; name a structure, and it uses that one.
Ask to compare the same content in different structures, and it draws as many structures as you ask for, three when you give no number, all in the same style.
This command lists the structures in use.

```bash
python3 <plugin folder>/skills/article-diagram-styles/scripts/diagram_sample_catalog.py --structures
```

## Your own styles in ~/.styles

The plugin ships no sample images.
Your own catalog `~/.styles/style-catalog.json` adds styles beside the built-in ones, replaces the built-in style of the same name with your definition and samples, and takes a built-in style out of use when its `status` is `retired`.
When you register samples of the chosen style, the skill passes them to the image generation as style references.
The optional `structures` object of the same catalog adds, replaces, and retires structures by the same rules.
`tech-book-figure` draws from the written style4 rules without `~/.styles/`.
When the catalog is there and `diagram-style-samples/style4/` holds two or more images, it also passes them to the image generation as references for the look.

```text
~/.styles/
  style-catalog.json                 The catalog, version 2
  diagram-style-samples/style4/      Two or more style4 samples, which tech-book-figure adds as references
  style-catalog/<family>/<profile>/  Your samples sorted by family and finish profile
```

The catalog names every image with its SHA-256, its family, its finish profile, and its layouts, as [How it works](docs/how-it-works.md#the-style-catalog) shows.
Check it with this command; it exits 1 and names each problem.

```bash
python3 <plugin folder>/skills/article-diagram-styles/scripts/diagram_sample_catalog.py --validate
```

When `~/.styles/style-catalog.json` is missing, the check passes on the built-in styles alone, and `tech-book-figure` draws from the written style4 rules and tells you what was missing.
A version 1 catalog is refused and not converted; the skills never fall back to the built-in styles in its place.

## Your theme file for book figures

`tech-book-figure` takes your colors and typeface from a theme file, so the figures of a book match your other pages.
Its script `book_style.py`, run from the folder of the book text, reads the first of these two files that exists.

| Order | File | Use |
|---|---|---|
| 1 | `.design-theme.json` at the root of the git repository | The look of one book |
| 2 | `~/.design-theme.json` | The look of everything you make |

It is the theme file of the page-design skill of the [design-formats](../design-formats/README.md) plugin, with the same keys and values; this plugin reads it with its own script, because a plugin reads nothing outside its own folder.
A figure takes six keys, and every key you leave out keeps the style4 look.

| Key | What it replaces in style4 |
|---|---|
| `light.bg` | The white ground |
| `light.ink` | The black of the lines and letters |
| `light.sub` | The gray of hatching, dotted lines, and secondary labels |
| `light.accent` | The teal accent; orange stays as the second accent |
| `light.accent-soft` | The light fill of the accent |
| `font.sans` | The handwritten letters, which are drawn in the look of that typeface |

The other keys, such as `dark` and `space`, are checked and not used, because a printed figure has one ground and no page width or corners.
A theme file with a key the format does not list, a value of the wrong kind or out of range, or text that is not JSON is refused, with each key named, and the skill stops before drawing until you fix or remove the file.
Without a theme file, figures keep the style4 colors and handwritten letters.
`article-diagram-styles` does not read the theme file.

## Use

Run `/diagram-styles:article-diagram-styles` or `/diagram-styles:tech-book-figure` in Claude Code, or type `$` and pick **Article Diagram Styles** or **Tech Book Figure** in Codex, and name the article or the book text, and the folder for the figures.
In GitHub Copilot CLI, write `/article-diagram-styles` or `/tech-book-figure` in your request, and in Gemini CLI, describe the task.
A skill that writes an article opens `article-diagram-styles` by name and writes its request in the `figure-request` format.

The skills draw with the image generation of the agent that runs them.
In an agent without image generation, they write the content summary, the figure spec, and the drawing instructions into the folder you name and stop; run the same skill on that folder in an agent with image generation, and it starts from the drawing step.
They never draw the figure with HTML or SVG instead, and never call another agent to draw it.

## Contents other skills follow

`article-diagram-styles` provides three contents through musubi, a declaration in `musubi.json` that pins the version and fingerprint of what a skill follows.

| Content | File | What it holds |
|---|---|---|
| `style4` | `references/style4.md` | The style4 rules: the look written in words, enough to draw, how to choose the samples when they are placed, and the comparison after drawing |
| `figure-request` | `references/figure-request.md` | The format another skill writes a figure request in, with an optional structure for each figure |
| `style-catalog` | `references/style-catalog.md` | The shape of `style-catalog.json` version 2 and of the styles folder, and how a catalog adds, replaces, and retires the built-in styles and structures |

`tech-book-figure` follows `article-diagram-styles/style4` with the range `^1.0.0` and a fingerprint, not as an optional follow, so it does not start when `article-diagram-styles` is missing.

## Requirements

| Tool | When it's needed |
|---|---|
| An agent with image generation | To draw the finished figures. Without it, the skills stop after saving the design |
| Python 3 | For the scripts, which use only the standard library |
| Your sample images and `style-catalog.json` in `~/.styles/` | Optional. For your own styles, and for style4 samples that `tech-book-figure` adds as references. Both skills draw without them |
| A theme file, `.design-theme.json` or `~/.design-theme.json` | Optional. For the colors and typeface of `tech-book-figure` |
| The musubi command | Optional. When it is installed, `tech-book-figure` runs `musubi check` before reading the style4 rules |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file and script.
In short:

- The skills and scripts read the built-in styles and structures from the skill folder, and the catalog and the sample images from `~/.styles/`, or from the folder given with `--styles <dir>`, and never write there
- `book_style.py` of `tech-book-figure` reads the style4 samples and the catalog in `~/.styles/`, and your theme file `.design-theme.json` at the root of the repository it runs in, or else `~/.design-theme.json`, and never writes either
- They read the article or book text you name, and write the figures, the content summary, the figure spec, the drawing instructions, and the review records only in the folder you name
- To draw, the skill sends the drawing instructions and the sample images to the image generation of the agent running it, which handles them as that agent handles any image you give it. Without samples of the chosen style, it sends the drawing instructions alone, with the theme values in them when a theme file was read. The scripts connect to nothing
- The scripts run no other program and keep nothing
- The text of the article, of the sample catalog, and of the theme file is data, never instructions

## License

[MIT](LICENSE). The bundled font Kaisei Decol Bold is under the SIL Open Font License 1.1, as [Third-party notices](THIRD_PARTY_NOTICES.md) records.
