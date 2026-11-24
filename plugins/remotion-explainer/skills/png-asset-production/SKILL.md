---
name: png-asset-production
description: Makes the original transparent PNG art of every object a Remotion explainer video shows for its subject, one PNG per object and state, in one material style with felt-applique as the default, and checks each asset manifest with the Python standard library. Uses the agent's image generation tool when there is one, and otherwise lists the pictures to make with their prompts and checks the PNGs the user provides. Use when an approved list of the objects a video needs calls for art that moves as a whole, or when remotion sends art back to be made. Never makes a whole scene, a poster, a route diagram, or a screen.
---

# PNG asset production

This skill makes original PNG art with transparency, one object or one state of an object per file.
It never makes a flattened scene, a poster, a route diagram, a UI screen, or a picture that explains on its own.
Every object of the subject, including the main diagram, the people, the documents, the goods, the tools, and each state of them that does not deform, is its own PNG layer, and Remotion owns only the time, the placement, the camera, the relations, and the motion.
Talk to the user in the language they write in.

The files are next to this `SKILL.md`, and other skills follow three of them through musubi.

| Content | File | What it holds |
|---|---|---|
| `material-styles` | `formats/material-styles.md` | The five material styles, the `custom` style, and what each one looks like and excludes |
| `asset-manifest` | `formats/asset-manifest.md` | The fields of `asset-manifest.json`, one per object |
| `check-asset-manifest` | `scripts/check-asset-manifest.py` | The check of a manifest and the PNGs it names |

`examples/asset-manifest.json` shows the form of a manifest.

## Choose the material style

Read `formats/material-styles.md` before writing a prompt, and take one `styleId`.
When the user names none, use `felt-applique`.

| `styleId` | Name |
|---|---|
| `felt-applique` (default) | Felt applique |
| `torn-paper-collage` | Torn paper collage |
| `ink-wash-linework` | Ink linework with light washes |
| `clay-relief` | Clay relief |
| `ceramic-miniature` | Ceramic miniature |

`custom` is allowed only when the user supplies a new contract: the material, the grammar of the silhouettes, three to five physical cues, the roles of the palette, and what it excludes.
Never invent a style without saying so, and never let a PNG style redesign the video.
Ask the user which style to use only when the request leaves it open and the video calls for another look: in Claude Code with AskUserQuestion, with `felt-applique` as the recommended option, and in other agents in the chat, waiting for the answer.

A material style never chooses a stage theme.
When the calling skill has chosen a stage theme, such as the felt applique stage of `remotion`, follow what the calling skill says of the theme, and keep the art to the subject's objects.

## Write the list of assets first

Before making any image, write one row for every object and state of the subject that shows on screen: `assetId`, the object's role, the scene where it appears, the state it shows, the motion it may make as a whole, and the explanation it must not carry.
A route, a transition, or a whole scene is never one asset; each part that moves on its own is.
Never let Remotion draw an object of the subject with its own SVG or CSS in place of a PNG.

When the calling skill has chosen a stage theme, add `assetStyleId`, `stageThemeId`, and `themeSeparation` to every row.
`themeSeparation` says that the PNG is the subject's original art and that Remotion makes the stage apart from it.
How the video uses the art is decided by the calling skill, such as `remotion`.

## Make each asset

1. Write a prompt for each row from the contract of the chosen style. Ask for one separate PNG per role and state, never for a scene, a contact sheet, labels, arrows, routes, or a background. When an object changes its drawn inner form, make a before and an after PNG instead of having Remotion redraw it.
2. Make the original on one flat chroma background, or with true transparency, and keep the untouched raw PNG. Keep the silhouette centered with a clear margin, with no text, frame, arrow, scenery, or second copy of the object unless the role needs one.
   - When the agent has an image generation tool, such as the `imagegen` skill of Codex, use it.
   - When it has none, print the rows as a numbered list, each with its `assetId`, the file name to save, and the full prompt, tell the user to make the pictures with any image tool they have and put them in the project's artwork folder, and wait. Then go on from step 3 with the PNGs the user provides, which pass the same checks.
3. Make the PNG with transparency. When the image tool gave a chroma background, remove it with the tool's own chroma removal when it has one, such as `remove_chroma_key.py` of the `imagegen` skill; otherwise ask the user for a PNG with transparency. Never crop by guessed fixed sizes.
4. Look at the alpha PNG on white, on dark, and on the neutral background of its scene. Refuse fringe, baked-in scenery, a cut-off silhouette, an unreadable form, fake UI, a generic icon, or a style that is only a recolor.
5. Write `asset-manifest.json` by `formats/asset-manifest.md`, and run the check with Python 3:
   `python3 <skill>/scripts/check-asset-manifest.py artwork/parcel-asset-manifest.json`
   Here `<skill>` is the path of this skill's folder. It prints one JSON object and exits 0 when the manifest passes, 1 with issues, and 2 when it is called wrongly or cannot read the manifest. Fix every issue and run it again.
6. When the shot draws the object in before painting it, hand the accepted alpha PNG, never its raw chroma source, to the `png-outline-tracing` skill, and record its handoff in the manifest:

Write in the `outline-timing` format of the `png-outline-tracing` skill: open the `png-outline-tracing` skill by name and read the file it names for `outline-timing`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `png-outline-tracing` skill is not installed, do not start: tell the user that `png-outline-tracing` is missing and how to install it, then stop.

Never trace a whole scene, and never use an SVG trace in place of original art.

When `python3` is missing, tell the user to install Python 3 and stop.

## What Remotion may do with the art

The PNG may move, scale, crop, mask, and fade as a whole, and its inner parts never deform.
Remotion adds only what is not illustration: arrows, connector paths, masks, a temporary outline, emphasis, captions, and camera moves.
A stage theme the caller chose may add a surface that holds things for a reason, such as a felt board, a pocket, a sewn label, or the theme's connector, and still never draws a document, a person, an icon, a card, a token, a chart, or the main diagram in place of art.
Give the caller the path of each manifest, and of each outline handoff it asked for.

## Done when

The raw PNG, the alpha PNG, the three composites, and a manifest that passes the check exist for every row.
Until the composites have been looked at, call the asset a candidate, not finished or reusable art.

## What it reads, writes, and sends

It reads the manifests and the PNGs of the user's project, and writes the PNGs, the composites, and the manifests there.
The check reads only the manifest and the files it names, and sends nothing.
The prompts go only to the image generation tool of the agent, and only when the agent has one.
