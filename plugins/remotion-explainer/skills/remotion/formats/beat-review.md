# Beat review

After rendering, write `out/review/beat-review.json` and run its check.
It is evidence that each beat was looked at in real frames, not a pass the renderer declares for itself.

## The review

```json
{
  "dossierPath": "../../beat-dossier.json",
  "dossierHash": "<the dossierHash that check-beat-dossier printed>",
  "compiledHash": "<the SHA-256 of the exact renderer source and output contract>",
  "beats": [
    {
      "id": "unsorted",
      "frames": [
        {"kind": "orient", "path": "unsorted-orient.png"},
        {"kind": "operation", "path": "unsorted-operation.png"},
        {"kind": "read", "path": "unsorted-read.png"},
        {"kind": "handoff", "path": "unsorted-handoff.png"}
      ],
      "scores": {"questionClarity": 4, "visualProof": 4, "hierarchy": 4, "operation": 4, "readingRhythm": 4, "handoff": 4},
      "reviewNote": "The blank label is the only large lit object; the route label is absent until the handoff frame."
    }
  ]
}
```

| Field | Holds |
|---|---|
| `dossierPath` | The beat dossier, relative to this file |
| `dossierHash` | The `dossierHash` that the `check-beat-dossier` check of this skill printed for that dossier |
| `compiledHash` | The SHA-256 of the exact renderer source and output contract the frames came from |
| `beats[].id` | A beat of the dossier; every beat of the dossier has one review |
| `beats[].frames[]` | One rendered frame of each `kind`, `orient`, `operation`, `read`, and `handoff`, with its `path` relative to this file |
| `beats[].scores` | The six scores of `formats/video-quality-review.md`, from 1 to 5: `questionClarity`, `visualProof`, `hierarchy`, `operation`, `readingRhythm`, and `handoff` |
| `beats[].reviewNote` | What the frames show, in concrete terms |

## What a pass means

The check needs a real file for each of the four frame kinds, the exact hash of the dossier, a SHA-256 compiled hash, every beat of the dossier, and every score at 4 or 5.
It cannot judge visual quality alone.
The independent reviewer opens the listed frame files and writes concrete remarks before a render may become a candidate; a pass of the check is what allows that candidate, nothing more.

## The check

Run the `check-beat-review` check of this skill on the file.
Each issue names its `rule` and the `beat`, the `frame` kind, or the `field` it is about.

| Rule | Means |
|---|---|
| `dossier-path` | `dossierPath` is missing or names no file |
| `dossier-hash` | `dossierHash` is not the SHA-256 of the dossier as it is now |
| `compiled-hash` | `compiledHash` is not a SHA-256 hash of 64 lowercase hex digits |
| `unknown-beat`, `missing-review` | A reviewed beat is not in the dossier, or a beat of the dossier has no review |
| `frame-kind`, `frame-file` | A beat lacks one of the four frame kinds, or a listed frame is not a file |
| `score` | A score is missing or not 4 or 5 |
| `review-note` | `reviewNote` is missing or is a general verdict such as "ok", "looks good", or "no problem" |

`examples/beat-review.json` reviews `examples/beat-dossier.json`, and its frames in `examples/frames/` are small SVG stand-ins for rendered frames, so the example has real files to point at.
