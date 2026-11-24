# Material styles

Each asset is made in exactly one material style.
A style describes the art direction of the object alone, not the video's background, layout, type, or way of explaining.
When no style is stated, use `felt-applique`.

| `styleId` | Name |
|---|---|
| `felt-applique` (default) | Felt applique |
| `torn-paper-collage` | Torn paper collage |
| `ink-wash-linework` | Ink linework with light washes |
| `clay-relief` | Clay relief |
| `ceramic-miniature` | Ceramic miniature |
| `custom` | A style the user supplies, described at the end |

Choosing a material never chooses a stage theme.
The `felt-applique` material makes felt objects; the felt stage is a stage theme of the `remotion` skill, and only the caller's explicit choice of that stage theme brings it in.

## `felt-applique`

| Part | Holds |
|---|---|
| Premise | Carefully cut layers of wool felt assembled into a tactile applique |
| Shape grammar | Large rounded cut pieces; two to five deliberate overlapping planes; no razor-thin vector strokes |
| Physical cues | Visible felt nap and grain, slightly softened cut edges, restrained stitched or blanket-stitch accents, a shallow contact shadow between layers |
| Palette | A warm cream base, a deep forest or teal structural color, and one vermilion or mustard accent; choose colors by role, not as arbitrary swatches |
| Avoid | UI cards, glossy plastic, photographic lighting, loose yarn clutter, labels, and a scene that reads like a poster |

## `torn-paper-collage`

| Part | Holds |
|---|---|
| Premise | Matte handmade paper, cut and torn into a readable object |
| Shape grammar | Overlapping torn silhouettes with intentional deckled edges and a few large planes |
| Physical cues | Fiber texture, an uneven torn edge, a low paper shadow, variation of printed or painted color |
| Avoid | Perfectly smooth vector cuts, confetti, scrapbook clutter, text, and full scenes |

## `ink-wash-linework`

| Part | Holds |
|---|---|
| Premise | A confident ink contour with sparse transparent watercolor washes |
| Shape grammar | An expressive, irregular contour, open negative space, and few wash fields that support the silhouette |
| Physical cues | Variation of pressure, a tiny wobble of the ink, translucent pooling, breaks from a dry brush |
| Avoid | A uniform black stroke, hyper-detailed hatching, UI frames, and flat clip art |

## `clay-relief`

| Part | Holds |
|---|---|
| Premise | Soft clay forms molded by hand and set in a shallow relief |
| Shape grammar | Plump rounded masses, stacked bands of depth, and carved seams only where the structure needs them |
| Physical cues | Corners softened by a thumb, matte clay grain, gentle ambient occlusion, restrained fingerprints |
| Avoid | Shiny 3D plastic, a pile of toys, scenes in deep perspective, labels, and overly literal realism |

## `ceramic-miniature`

| Part | Holds |
|---|---|
| Premise | A small hand-built ceramic object, simplified on purpose as it was molded |
| Shape grammar | Chunky, simplified volumes and a silhouette that holds together as one fired piece |
| Physical cues | Variation of a satin glaze, a subtle kiln speckle, molded seams, a small shadow that grounds it |
| Avoid | Photoreal tabletop scenes, chrome reflections, UI symbols, and miniature clutter |

## `custom`

Use `custom` only when the user supplies a new style contract, and put it in `customStyleContract` of the asset manifest.
The contract names the material, the grammar of its silhouettes, three to five physical cues, the roles of its palette, and what it excludes.
Never invent a style without that contract, and never let a style redesign the video.
