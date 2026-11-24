# Choreography

The rough cut of an explainer video is a full rehearsal of the final cut with stand-ins for the finished art.
Only texture, shading, and the detail of the materials are left out.
The composition, the camera, the order things appear, the routes of objects, transforms, comparisons, changes of state, and the handoffs between scenes are designed exactly as in the final cut, and checked in the rough.

## The plan

Write `storyboard/choreography-plan.json` in the Remotion project before building the rough cut.

```json
{
  "schemaVersion": 1,
  "scenes": [
    {
      "id": "scan",
      "viewGrammar": "inspection",
      "viewerQuestion": "How does the center learn where the parcel goes?",
      "camera": {
        "entry": "The parcel under the scanner",
        "operation": "Push in on the label as it is read",
        "result": "The route printed beside the label",
        "movement": "push-in"
      },
      "objectLifecycles": [
        {
          "object": "scanner-beam",
          "role": "what reads the label",
          "entryState": "off",
          "introducedAt": "operation",
          "operation": "sweeps across the label",
          "resultState": "reading",
          "resultAt": "operation",
          "sourceZone": "scanner",
          "targetZone": "parcel"
        }
      ],
      "motionBeats": [
        {"kind": "camera-reframe", "subject": "parcel", "effect": "the view closes in on the label"},
        {"kind": "state-transition", "subject": "parcel", "effect": "the route appears on the label"}
      ],
      "handoff": "The parcel with its route leaves for the lanes",
      "reviewFrames": ["entry", "operation", "result"],
      "finalMotionParity": {
        "camera": true, "blocking": true, "revealOrder": true,
        "objectRoutes": true, "transforms": true, "handoff": true
      }
    }
  ]
}
```

| Field | Holds |
|---|---|
| `viewGrammar` | How the scene is seen, one of the grammars below |
| `viewerQuestion` | The question of the viewer the scene answers |
| `camera` | What the camera shows at `entry`, during the `operation`, and at the `result`, and its `movement` |
| `objectLifecycles[]` | Each object: its `role`, the state and moment it appears in (`entryState`, `introducedAt`), what happens to it (`operation`), the state and moment it ends in (`resultState`, `resultAt`), and the zones it moves from and to. Moments are `entry`, `operation`, or `result` |
| `motionBeats[]` | Each motion: its `kind`, the `subject` that moves, and the `effect` the viewer sees |
| `handoff` | What the scene passes to the next one |
| `reviewFrames` | `entry`, `operation`, and `result` |
| `finalMotionParity` | `true` for `camera`, `blocking`, `revealOrder`, `objectRoutes`, `transforms`, and `handoff`, stating that the final cut changes none of them |

## View grammars

Choose the grammar that fits what the scene explains.

| Grammar | The scene shows |
|---|---|
| `overview` | The whole, before any part is examined |
| `inspection` | One part opened and read closely |
| `state-machine` | One object whose state is replaced by the next |
| `branching` | Paths that split by a condition |
| `comparison` | The same input meeting different roles or limits |
| `aggregation` | Several results gathered into one |
| `history` | Changes laid out in the order they happened |
| `exception-recovery` | Something that fails and how it is recovered |
| `return-path` | Something that comes back to where it started |
| `progressive-reveal` | A whole uncovered part by part |
| `horizontal-exchange` | Something carried from one side to the other, in at most two scenes of a video |

Neighboring scenes do not use the same grammar, and a video uses at least four grammars, or one per scene when it has fewer than four scenes.
A sideways carry whose labels alone change is not another grammar.

## The rough cut matches the final cut

The final cut replaces only the stand-in art.
It adds no object, camera move, order of appearance, transform, route, or way of showing the conclusion that the rough cut lacks.
A scene whose `finalMotionParity` is not `true` for all six keys does not pass.

## Order of work

1. Write `storyboard/choreography-plan.json` and run the `check-choreography` check of this skill until it passes
2. Build in the Remotion rough cut only the camera, lifecycles, and motion beats of the plan; finished art does not hide what the motion lacks
3. Show the real entry, operation, and result frames and a short clip of each scene, with the viewer's question and what appears, what changes, and what stays written in plain sentences
4. Check that the whole video does not read as a diagram carried sideways, that each change of camera or composition matches a change in the explanation, and that no part needs the final art to be understood
5. When a scene fails, do not adjust the stand-ins or the colors; change its grammar, camera, lifecycles, or motion beats and rebuild the rough cut

## What the check reports

Each issue names its `rule` and the `scene`, or no scene when it is about the whole plan.

| Rule | Means |
|---|---|
| `schema-version`, `scenes` | The plan is not version 1, or has fewer than two scenes |
| `scene-field`, `camera-field`, `lifecycle-field`, `motion-beat-field` | A field of the scene, its camera, an object, or a motion beat is missing |
| `view-grammar`, `motion-kind`, `lifecycle-moment` | A grammar, a motion kind, or a moment is not one of those listed here |
| `no-late-introduction` | Every object of the scene is on screen at entry |
| `no-state-change` | Every object ends in the state it started in |
| `motion-variety` | The scene has fewer than two kinds of motion |
| `review-frames` | `reviewFrames` lacks entry, operation, or result |
| `motion-parity` | A key of `finalMotionParity` is not `true` |
| `repeated-view-grammar` | The scene uses the grammar of the scene before it |
| `horizontal-exchange-limit`, `view-grammar-variety` | More than two scenes carry sideways, or the video uses too few grammars |

The motion kinds are `reveal`, `spatial-route`, `transform`, `state-transition`, `branch`, `aggregate`, `compare`, `camera-reframe`, and `handoff`.
