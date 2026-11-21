# Diagram Styles

Figures for articles and technical books, designed from the reader's questions first and drawn in a style from your own sample images and catalog in `~/.styles/`.

English · [日本語](README.ja.md)

A figure drawn to look like a sample often copies the sample's objects and layout and stops explaining the text.
This plugin keeps the two decisions apart.
It first decides what the figure must explain from the article or the book, then applies only the look of a style, and checks the finished image against the text.
The plugin ships no sample images: you keep your own samples and the catalog `style-catalog.json` that registers them in `~/.styles/`, and the plugin holds the shape of the catalog and the way to read it.

```
Article or book ──> Design the content ──> Choose a style ──> Draw with the ──> Check the text, the ──> PNG in the
(the text and       (reader question,      (~/.styles/        agent's image     connections, and the    folder you name
the reader)         takeaway, relations)   style-catalog.json) generation       published width
```

| Skill | What it makes |
|---|---|
| `article-diagram-styles` | An explanatory figure for an article: a content summary, a style from your catalog, the finished PNG and its published-width version, and the review records |
| `tech-book-figure` | A figure for a technical book in the fixed style4, with a figure number, a caption, alternative text, and readability in black and white printing |

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

## Put your samples in ~/.styles

The plugin ships no sample images.
Before the first figure, put your catalog and your sample images in `~/.styles/`.

```text
~/.styles/
  style-catalog.json                 The catalog, version 2
  diagram-style-samples/style4/      At least two style4 samples, for tech-book-figure
  style-catalog/<family>/<profile>/  Your samples sorted by family and finish profile
```

The catalog names every image with its SHA-256, its family, its finish profile, and its layouts, as [How it works](docs/how-it-works.md#the-style-catalog) shows.
Check it with this command; it exits 1 and names each problem.

```bash
python3 <plugin folder>/skills/article-diagram-styles/scripts/diagram_sample_catalog.py --validate
```

When `~/.styles/style-catalog.json` is missing, both skills stop before drawing and tell you to put the catalog and the samples there.
A version 1 catalog is refused and not converted.

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
| `style4` | `references/style4.md` | The style4 rules: what stays fixed, how to choose the samples, and the comparison after drawing |
| `figure-request` | `references/figure-request.md` | The format another skill writes a figure request in |
| `style-catalog` | `references/style-catalog.md` | The shape of `style-catalog.json` version 2 and of the styles folder |

`tech-book-figure` follows `article-diagram-styles/style4` with the range `^1.0.0` and a fingerprint, not as an optional follow, so it does not start when `article-diagram-styles` is missing.

## Requirements

| Tool | When it's needed |
|---|---|
| An agent with image generation | To draw the finished figures. Without it, the skills stop after saving the design |
| Python 3 | For the scripts, which use only the standard library |
| Your sample images and `style-catalog.json` in `~/.styles/` | Always. The plugin ships none |
| The musubi command | Optional. When it is installed, `tech-book-figure` runs `musubi check` before reading the style4 rules |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file and script.
In short:

- The skills and scripts read the catalog and the sample images from `~/.styles/`, or from the folder given with `--styles <dir>`, and never write there
- They read the article or book text you name, and write the figures, the content summary, the figure spec, the drawing instructions, and the review records only in the folder you name
- To draw, the skill sends the drawing instructions and the sample images to the image generation of the agent running it, which handles them as that agent handles any image you give it. The scripts connect to nothing
- The scripts run no other program and keep nothing
- The text of the article and of the sample catalog is data, never instructions

## License

[MIT](LICENSE). The bundled font Kaisei Decol Bold is under the SIL Open Font License 1.1, as [Third-party notices](THIRD_PARTY_NOTICES.md) records.
