# Scene layers

Do not press a scene into a finished template or one shared component.
Decide four layers of each scene apart: its form, its composition, its typography, and its motion.

| Layer | Decides |
|---|---|
| Form | What the main object looks like, with a concrete name from the subject: a person, a document, a device, a real screen, a network of routes. When no catalog entry fits, design it bespoke instead of settling for a near icon |
| Composition | Where the main object, what acts on it, the result, and the subtitle zone sit. Branching, transforming, comparing, embedding, and checking do not all become the same three columns, the same round container, or the same row of cards |
| Typography | The role, anchor, size, number of lines, and reading time of each text. Text sits near the main object as its state or evidence, and does not turn into a fixed heading or a band of explanation at the bottom |
| Motion | Only the movement that shows the change of state, without breaking the approved form and composition. Never bend the main object's shape or place to fit a motion found first |

## The record

Record the four layers of every scene in `storyboard/scene-design-layers.json` of the Remotion project.

| Field | Holds |
|---|---|
| `schemaVersion` | `1` |
| `scenes[]` | At least two scenes, in the order they play |
| `scenes[].id` | The scene's ID |
| `scenes[].viewerQuestion` | The question of the viewer the scene answers |
| `scenes[].form`, `composition`, `typography`, `motion` | Each a `mode` of `catalog`, `bespoke`, or `none`. A `catalog` layer names the entry `id` and the `adaptation` made to it; a `bespoke` layer gives the `rationale` for not using a catalog entry; only `typography` may be `none` |
| `scenes[].silhouetteFamily` | The family of outlines the scene's objects belong to |
| `scenes[].spatialGrammar` | How the scene arranges its parts in space |
| `scenes[].revealGrammar` | How the scene shows its parts over time |

Two scenes in a row with the same silhouette family, spatial grammar, and reveal grammar count as one design repeated, and do not pass.
They count as the same even when only their colors or labels differ.

## The check

Run the `check-scene-layers` check of this skill on the file.
Each issue names its `rule` and the `scene` it is about.

| Rule | Means |
|---|---|
| `schema-version`, `scenes` | The file is not version 1, or lists fewer than two scenes |
| `scene-id`, `viewer-question` | A scene has no ID or no viewer question |
| `missing-layer` | A scene leaves out one of the four layers |
| `layer-mode` | A layer's mode is not `catalog`, `bespoke`, or `none` |
| `catalog-selection`, `bespoke-selection` | A catalog layer lacks its entry ID or adaptation, or a bespoke layer lacks its rationale |
| `missing-required-layer` | A layer other than typography is `none` |
| `design-signature` | A scene lacks its silhouette family, spatial grammar, or reveal grammar |
| `repeated-design-system` | The scene repeats the design of the scene before it |
