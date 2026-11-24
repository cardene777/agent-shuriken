# Explainer

This contract sets how an explainer frames its scenes, what makes its subject rich, how one scene hands over to the next, and the geometry everything is placed with.

## Layout

A DOM `SceneFrame` holds a safe title area and a content area.
One `DiagramWorld` sits inside the content area.
Every position in the world comes from named anchors, bounds derived from them, and connection rules, all in one layout module.
The camera reads the same module.

The layout module is the typed object that `storyboard/layout-spec.json` of the `layout` format of the `remotion-frame-checks` skill is generated from.
When the world places PNG art, `formats/spatial-layout.md` adds the rules for the art's silhouettes, connectors, and frames.

## Richness

Make the subject rich, not the interface around it.
Each primary object has all four of these:

| Each primary object has | Means |
|---|---|
| A silhouette | A shape a viewer recognizes from its outline alone |
| An inner structure | At least one structure inside the outline |
| A material or an edge treatment | A surface or an edge that says what the object is made of |
| A change for each state | A transformation of the object itself when its state changes |

Use one restrained palette, the one the `art-direction` format of the `remotion` skill sets, and move the camera only with a purpose.
Do not add cards, background images, badges, or ambient motion to fake detail.

## Scene handoff

Record these for each scene:

| Field | Holds |
|---|---|
| `entry` | How the scene begins |
| `operation` | The change the scene shows |
| `exit` | How the scene ends |
| `focusObject` | The object the viewer follows |
| `camera` | What the camera does |
| `handoff` | The object, state, or path the next scene takes over |

The exit of a scene and the entry of the next share at least one object, state, or path.
A fade alone is not a handoff.
The `continuity-samples` format of the `remotion-explainer-review` skill checks each handoff in sampled frames.

## Geometry

- Use a world of 1920 by 1080 unless the composition sets another size
- Keep text inside a safe area of 96 px left and right and 72 px top and bottom, unless a crop was approved
- Place objects by the bounds of their components, never by eye
- Rotate an object around a declared anchor, and compute its outer bounds again after the rotation
