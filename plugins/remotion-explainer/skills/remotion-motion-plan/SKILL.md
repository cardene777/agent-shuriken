---
name: remotion-motion-plan
description: Plans the motion of a Remotion explainer video before the rough cut, and holds the contracts and Node.js checks that other skills follow through musubi. The choreography plan gives each scene a view grammar, a camera, objects that appear when needed and change state, and a rough cut that matches the final cut; the continuous choreography plan carries one subject from scene to scene instead of clearing the board; the motion language plan picks one recipe per scene from a catalog of twelve, each backed by a verified entry of the user's motion evidence library, a list of watched videos with time ranges. Use when another skill says to follow remotion-motion-plan, or when planning or checking how the scenes of a Remotion video move.
---

# Remotion motion plan

This skill plans how the scenes of a Remotion explainer video move, before anything is rendered, and holds content that other skills follow through musubi: four contracts and a check for each.
Talk to the user in the language they write in.

The files are next to this `SKILL.md`.

| Content | File | What it holds |
|---|---|---|
| `choreography` | `formats/choreography.md` | `storyboard/choreography-plan.json`: the view grammar, camera, object lifecycles, motion beats, handoff, and review frames of each scene, and the rule that the rough cut matches the final cut |
| `continuous-choreography` | `formats/continuous-choreography.md` | `storyboard/continuous-choreography-plan.json`: the subjects followed through the video, what each scene takes over and hands on, and how the view changes |
| `motion-language` | `formats/motion-language.md` | The catalog of twelve main recipes, the supporting means, and `storyboard/motion-language-plan.json`, which picks a recipe per scene |
| `motion-evidence` | `formats/motion-evidence.md` | The user's motion evidence library: watched videos with time ranges, the recipes they show, and when to research a new one |
| `check-choreography` | `scripts/check-choreography.mjs` | The check of a choreography plan |
| `check-continuous-choreography` | `scripts/check-continuous-choreography.mjs` | The check of a continuous choreography plan |
| `check-motion-language` | `scripts/check-motion-language.mjs` | The check of a motion language plan against the user's library |
| `check-motion-evidence` | `scripts/check-motion-evidence.mjs` | The check of a motion evidence library |

`examples/` holds a plan of each kind and an example library, for a short video about a parcel that goes from a dock through a scanner and a sorter to a door.
The entries of the example library are made up to show the form; a user's plan cites only entries of the user's own library.

## Plan the motion

1. Read the viewer's questions and the scenes of the video from the brief or the storyboard the user or the calling skill gives.
2. Read `formats/choreography.md` and write `storyboard/choreography-plan.json`. Run its check until it passes.
3. Read `formats/continuous-choreography.md` and write `storyboard/continuous-choreography-plan.json`, so each scene takes over the subject the scene before it hands on. Run its check until it passes.
4. Open the user's library, `motion-evidence-library.json` in `${REMOTION_EXPLAINER_HOME:-$HOME/.local/share/remotion-explainer}`. When it does not exist, make the folder readable only by the user and start an empty library, as the next section shows, then run `check-motion-evidence` on it.
5. Read `formats/motion-language.md` and write `storyboard/motion-language-plan.json`, choosing for each scene a recipe that a verified entry of the library shows. Run `check-motion-language` with the plan and the library until it passes.
6. When no verified entry shows the recipe a scene needs, follow "When the library lacks a recipe" below, then go back to step 5.
7. Show the user the three plans as plain sentences per scene: the question, what appears, what changes, what stays, and what is handed on. Change them until the user agrees, and run the checks again after every change.

## Start a library

```bash
home="${REMOTION_EXPLAINER_HOME:-$HOME/.local/share/remotion-explainer}"
mkdir -p "$home" && chmod 700 "$home"
[ -f "$home/motion-evidence-library.json" ] || printf '{"schemaVersion": 1, "entries": []}\n' > "$home/motion-evidence-library.json"
chmod 600 "$home/motion-evidence-library.json"
```

## When the library lacks a recipe

1. Search for a video that shows the motion, using general words for the kind of motion or a public subject. Never search with names, internal terms, or text from the user's files.
2. Add what you found as a `candidate` entry with its platform, creator, title, and address, and say that it was not watched.
3. A candidate becomes `verified` only after its video was played and the time range and the motion on screen were written down. When you cannot play video, ask the user to watch the time range you name and tell you what moves; write their words into the entry.
4. Run `check-motion-evidence` on the library after every change.

Never cite a candidate entry in a plan, and never copy the art style, interface, characters, or layout of a source.

## Run a check

The checks need Node.js 18 or later and use only its built-in modules, so nothing is installed.
When `node` is missing, tell the user to install Node.js 18 or later, which Remotion needs too, and stop.
Run them from the root of the Remotion project, with the path of this skill's folder in place of `<skill>`.

```bash
node <skill>/scripts/check-choreography.mjs storyboard/choreography-plan.json
node <skill>/scripts/check-continuous-choreography.mjs storyboard/continuous-choreography-plan.json
node <skill>/scripts/check-motion-evidence.mjs "${REMOTION_EXPLAINER_HOME:-$HOME/.local/share/remotion-explainer}/motion-evidence-library.json"
node <skill>/scripts/check-motion-language.mjs storyboard/motion-language-plan.json "${REMOTION_EXPLAINER_HOME:-$HOME/.local/share/remotion-explainer}/motion-evidence-library.json"
```

Every check prints one JSON object with `check`, `decision` (`pass` or `revise`), `issueCount`, and `issues`, each issue with its `rule`, the `scene` or library `entry` it is about, and a `message`.
A check exits 0 when the file passes, 1 when it needs revising, and 2 when it was called the wrong way or could not read a file, with the reason on standard error.
Each format file lists the rules its check reports.

## What it reads, writes, and keeps

The checks read only the files named on the command line, treat their contents as data, and send nothing anywhere.
The skill writes the three plans under `storyboard/` of the user's project, and keeps the library in the data folder above, readable only by the user, until the user deletes it.
A search for a video sends only the general words of step 1 of "When the library lacks a recipe".
