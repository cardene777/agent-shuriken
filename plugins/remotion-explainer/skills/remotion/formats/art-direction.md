# Art direction

Make pictures that belong to the subject, instead of fitting the parts of a template onto it.
Use reference videos to learn composition, density, motion, and how information is shown.
Never copy their screens, their assets, or the art that belongs to them.

## The production record

`production.json` in the user's project is the one editable record of the video.
These skills never go past a gate in it that is not approved.

| Field | Written | Read |
|---|---|---|
| `artDirection` | At the art direction gate, before anything is implemented, with the fields below | By every later step; implementation does not start while a field is missing |
| `compositionRough` | After the user approves the full silent rough: the rough MP4, its compiled hash, the review result, and `approved: true` | Before the final art and the visual boards; when `approved` or the rough's compiled hash is missing, implementation does not start |
| `visual.staticAssets[]` | By `png-asset-production`, only after the rough is approved, as `formats/static-art.md` describes | Never while the rough is built; afterwards only accepted entries |
| `visual.paperScribe` | The same structure as `paperboard.json`, when the video uses the paper-scribe language of `formats/paper-scribe.md` | With `formats/paperboard.md` |
| Its approval gates | The person's approval of the style and density of the reference scene, and of the full rough | Before the video grows past the reference scene, and before the final art is used |

## `artDirection`

```json
{
  "designPattern": {"id": "sewn-route", "referenceTraits": ["one setting kept for the whole video"]},
  "patternAdaptation": {
    "setting": "A sorting floor between the warehouse shelf and the street",
    "metaphor": "Each lane is a pocket that holds the parcels bound for one street",
    "openingImage": "One parcel on the shelf with a blank label",
    "handoffImage": "The parcel in the pocket of lane 3"
  },
  "visualPremise": "The route of a parcel told as pieces sewn onto one board",
  "visualGrammar": {
    "drawing": "Cut shapes with thick dark edges and a light stitch",
    "depth": "The board and the pieces sewn onto it",
    "typography": "Short sewn tags next to the object they name",
    "palette": [{"role": "board", "color": "#1f4d4a"}, {"role": "primary", "color": "#e9b949"}],
    "space": "The route runs left to right and keeps the right third free for the next move",
    "camera": "Moves only to follow the parcel or to read its label"
  },
  "connectorGrammar": "One approved arrow with an outer edge, a core, a stitch, and a sewn head",
  "objectLexicon": [
    {
      "id": "parcel",
      "role": "The box the customer is waiting for",
      "shapeRationale": "A taped box with a label face, so the label can be read and changed",
      "states": ["unlabeled", "labeled", "delivered"],
      "operations": ["scanned", "labeled", "sorted into a lane"],
      "result": "The viewer can read where the parcel goes"
    }
  ],
  "motionLexicon": [
    {"objectId": "parcel", "motion": "travels along the belt into its lane", "meaning": "the sorter chose its lane"}
  ],
  "scenePromise": [
    {"sceneId": "sort", "newVisualDiscovery": "The label decides which lane takes the parcel", "handoff": "Lane 3 holds the parcel"}
  ],
  "stageTheme": {
    "id": "felt-applique",
    "assetStyleId": "felt-applique",
    "stagePrimitives": ["felt-board", "felt-pocket", "felt-tag", "felt-connector", "annotation"],
    "containerPolicy": "The subject's reason for a pocket",
    "labelPolicy": "The baseline rule for pockets of the same kind",
    "connectorPolicy": "When a connector may appear, for static relations only",
    "tracePolicy": "Only outlines made from accepted PNGs"
  },
  "referenceTraits": ["Abstract traits only"]
}
```

| Field | Holds |
|---|---|
| `designPattern` | The `id` of the pattern the user chose, such as `hand-drawn-narrative` of `formats/hand-drawn-narrative.md`, and the abstract `referenceTraits` it carries over |
| `patternAdaptation` | The pattern translated to the subject: the `setting`, the `metaphor`, the `openingImage`, and the `handoffImage` carried to the end. It never takes over the pattern's screens or assets |
| `visualPremise` | The metaphor, world, or visual language the subject is explained in |
| `visualGrammar` | The rules of `drawing`, `depth`, `typography`, `palette` (a `role` and a `color` each), `space`, and `camera` |
| `connectorGrammar` | The material of connectors and arrows: the outer edge, the core, the stitch or brush stroke, the ports, the arrowhead, the drawing order, and whether it sits in front of or behind the art. A plain SVG marker or a single line is not allowed |
| `objectLexicon[]` | Each main object: its `id`, its `role` in the subject, the `shapeRationale` for its form, its `states`, its `operations`, and the `result` the viewer can read after them. A generic icon name is not allowed |
| `motionLexicon[]` | The `motion` allowed for each object (`objectId`) and its `meaning`. Drift, breathing, and a constant pulse are not allowed |
| `scenePromise[]` | For each scene (`sceneId`), the `newVisualDiscovery` it shows for the first time and the `handoff` it passes on |
| `stageTheme` | Only when the user chose a stage theme, as below |
| `referenceTraits` | Only the abstract traits learned from references, never a screen, a drawing, or an asset |

## Stage themes

Set `stageTheme` only when the user explicitly chose it.
It needs the same ID in `assetStyleId`, and it is never chosen from the style of the PNGs alone.
A theme decides only the physical structure of the stage.
It does not decide the subject's PNGs, the causes in a scene, the composition, or the handoff.
`formats/felt-applique.md` describes the one theme these skills support, and the `check-stage-theme` check of this skill checks it in `production.json`.

## It passes when

- The form, role, operation, and result of each main object can be explained. A tracking tag, a generic card, or a text label is never the main object
- Each scene has its own visual job. The same composition is used again only when it helps the causes read
- Each motion explains a change of state, an operation, a handoff, or where to look
- The reference scene is not a shrunken digest of the whole video, but one finished scene for reading the hardest causal link
- What scenes share to keep one style is the rules of line, color, spacing, and motion, not the same composition or the same set of parts
- A design pattern defines how a setting is placed, how a picture is built, how dense the lines are, and the grammar of motion, not the surface colors. The setting, people, props, and metaphor of each subject are always designed anew
- Even with a stage theme, pockets and frames are used only to read containment, storage, or comparison in the subject. They never turn every scene into the same row of cards, or into frames that sort PNGs

## It fails when

- Changing the subject only means renaming the house, the person, the paper, and the arrow
- The difference between scenes is only the colors, the headings, or the background
- Objects sway, drift, or pulse without meaning
- One screen of a reference video is copied as it is, or the assets of a protected work are traced
- Frames of the same kind, or their label baselines, vary in height to follow the aspect ratio of their PNGs. A difference in height without a reason in the subject fails
