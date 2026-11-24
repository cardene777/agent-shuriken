# Asset manifest

Every object made as a PNG for the video has its own `asset-manifest.json`.
It records what the object is for, the one material style it is made in, the only motion Remotion may give it, the explanation it must not carry, the files it was made from, and the images it was reviewed on.
The video skill that calls this one, such as `remotion`, decides when a video uses static art at all, and names this manifest among what each static art entry carries.

## Fields

| Field | Holds |
|---|---|
| `schemaVersion` | `1` |
| `assetId` | The ID the video uses for the object |
| `role` | What the object is in the explanation |
| `styleId` | One style of `formats/material-styles.md`: `felt-applique`, `torn-paper-collage`, `ink-wash-linework`, `clay-relief`, `ceramic-miniature`, or `custom` |
| `customStyleContract` | Only with `custom`, and then required: the style contract the user supplied |
| `staticRoleReason` | Why the object is a PNG that moves as a whole, and what native Remotion geometry does instead |
| `motionBoundary` | `whole-image`: the PNG moves only as one piece, and its inner parts never deform |
| `allowedMotion[]` | The motions Remotion may apply, from `translate`, `scale`, `fade`, and `crop` only |
| `forbiddenExplanationWork[]` | What the PNG must not explain, such as a route, a lifecycle, or acting as a UI card |
| `generation` | The `prompt`, the untouched `rawPng` on a flat chroma background or with true alpha, and the transparent `alphaPng` made from it |
| `review` | The `lightComposite`, `darkComposite`, and `sceneComposite`, the alpha PNG placed on white, on dark, and on its intended neutral scene background, and `accepted` |
| `outlineHandoff` | `null`, or the path of the `outline-handoff.json` of the `outline-timing` format of the `png-outline-tracing` skill |

Paths are relative to the folder that holds the manifest.
Set `outlineHandoff` only after the `png-outline-tracing` skill has produced accepted paths and timing data.
Until the composites have been reviewed, the asset is a candidate, not finished art.

`examples/asset-manifest.json` shows the form only: it names a parcel's PNGs, which are not shipped with this skill, so the check reports each of them as a missing file.

## The check

Run the `check-asset-manifest` check of this skill on the manifest.

```bash
python3 <check-asset-manifest> artwork/parcel-asset-manifest.json
```

It reads the five PNGs the manifest names, with the Python standard library only.
A PNG has a positive size when its image header gives a width and a height above 0.
The alpha PNG is the same size as the raw PNG it was made from, has an alpha channel, holds at least one fully transparent pixel, and holds at least one pixel with an alpha above 16.
The pixels of 8-bit, non-interlaced PNGs of every color type are read; save the alpha PNG as an 8-bit RGBA PNG.

Each issue names its `rule`, the `asset`, and the `field` it is about.

| Rule | Means |
|---|---|
| `required-field` | A field other than `customStyleContract` and `outlineHandoff` is missing |
| `style-id`, `custom-style-contract` | `styleId` is not one of the six values, or `custom` comes without `customStyleContract` |
| `motion-boundary`, `allowed-motion` | `motionBoundary` is not `whole-image`, or `allowedMotion` holds a motion other than `translate`, `scale`, `fade`, and `crop` |
| `generation-file`, `review-file` | A path of `generation` or `review` is missing or empty |
| `outline-handoff` | `outlineHandoff` is neither `null` nor a path |
| `missing-file` | A file the manifest names does not exist, or cannot be read |
| `png-signature` | A PNG file does not start with the PNG signature |
| `png-size` | A PNG has no width and height above 0, or the alpha PNG differs in size from the raw PNG |
| `png-alpha` | The alpha PNG cannot be read for its alpha, has no alpha channel, no fully transparent pixel, or no pixel with an alpha above 16 |

A pass does not prove that the art is good.
Looking at the three composites, and rejecting fringe, baked-in scenery, a cut-off silhouette, an unreadable form, fake UI, a generic icon, or a style that is only a recolor, stays with the reviewer.
