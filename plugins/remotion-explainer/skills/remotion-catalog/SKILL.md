---
name: remotion-catalog
description: Fetches outside Remotion examples whose licenses allow the use, each at a pinned commit, into the plugin's data folder, and searches them by form, composition, typography, or motion, one layer at a time, returning each entry with its source repository, commit, license, and file. Never runs code from a source, and leaves out a source whose license evidence is missing. Use when choosing the look, layout, type treatment, or motion of a scene in a Remotion video, when another skill says to follow remotion-catalog, or when looking for a built Remotion example to borrow a mechanism from.
---

# Remotion catalog

This skill keeps a catalog of built Remotion examples from outside repositories, and finds the ones whose form, composition, typography, or motion fits a scene.
Talk to the user in the language they write in.

The files are next to this `SKILL.md`, and other skills follow two of them through musubi.

| Content | File | What it holds |
|---|---|---|
| `selection` | `formats/selection.md` | How to search the four layers apart, what to choose in each, and how to borrow from an entry without copying a scene |
| `catalog` | `scripts/catalog.mjs` | The command that fetches the sources, builds the catalog, and searches it |

`data/sources.json` lists the sources: each repository, the commit it is pinned to, its license, the file that shows the license, the folders left out, and how its examples are read.

## Find entries for a scene

1. Read `formats/selection.md`, and write the one sentence it asks for.
2. When the catalog has not been built, or `data/sources.json` changed since, fetch and build it as the next section shows.
3. Search each layer with English words from the sentence, one search per layer:
   `node <skill>/scripts/catalog.mjs search --layer composition compare two routes`
4. Read the results: each has its `id`, `source`, `title`, `file`, the absolute `path` of that file in the data folder, its `layers`, and its `license`. Open the files of the entries that fit, and read how the mechanism is built.
5. Choose by the rules of `formats/selection.md`, and give the calling skill, or the user, the ID of each chosen entry and what was adapted. When nothing fits a layer, say that the layer is `bespoke` and why.

Here `<skill>` is the path of this skill's folder.
The search words are English, because the entries are indexed from English names, descriptions, and code; translate the user's words first.
`--limit <n>` changes the number of results, 12 by default.

## Fetch and build the catalog

```bash
node <skill>/scripts/catalog.mjs sync
node <skill>/scripts/catalog.mjs build
```

Before the first `sync`, tell the user that it downloads the repositories named in `data/sources.json` from GitHub into the data folder.
`sync` fetches each source with `git` at its pinned commit only, leaves out the folders its entry excludes, and never runs code from a source.
It leaves out, with the reason, a source whose commit is not a full commit hash, whose license is not MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, 0BSD, CC0-1.0, or Unlicense, or whose license evidence is missing at that commit, and then exits 1.
`build` reads the fetched sources and writes `catalog.json`; a source that is not fetched at its pinned commit is skipped with the reason.
Neither command follows a symbolic link in a source, so a source cannot point the catalog at a file outside it.
To use another list of sources, pass `--sources <file>` to both; it takes the same form as `data/sources.json`.

The data folder is `catalog/` in `${REMOTION_EXPLAINER_HOME:-$HOME/.local/share/remotion-explainer}`, readable only by the user.
`sync` names in `unlisted` any folder of a source no longer listed; the catalog does not use it, and the user may delete it.

Every command prints one JSON object, and exits 2 with the reason on standard error when it is called the wrong way or cannot read a file.
When `node` or `git` is missing, tell the user to install it and stop; the command needs Node.js 18 or later.

## Borrow from an entry

- Never run the code of a source, install its packages, or run its scripts in the data folder; read its files only
- Copy into the user's project only the part that builds the mechanism, and rewrite its subject, copy, colors, and coordinates for the target video
- Keep the license notice of what you copy: the copyright and license for MIT, and the license with a note of the changes for Apache-2.0
- Never take sounds, videos, or images from a source unless its notices name their license

## What it reads, writes, and sends

It reads `data/sources.json`, or the list passed with `--sources`, and the files of the fetched sources.
It connects to the repositories of the list with `git`, sends nothing else, and writes only under the data folder above.
The fetched sources and the catalog stay there until the user deletes them.
