# Motion evidence

The motion evidence library holds reusable grounds for what to move, in what order, and why, in an explainer video.
It is not a collection for copying the art style, colors, or character placement of other videos.

## The library is the user's

The library is one JSON file kept outside any project, so every video of the user draws on the same evidence.
It lives at `motion-evidence-library.json` in the data folder of the plugin, `~/.local/share/remotion-explainer/`, or in the folder that `REMOTION_EXPLAINER_HOME` names.
The folder is readable only by the user.
A new library holds `{"schemaVersion": 1, "entries": []}`.

## When to research

Do not search for videos from scratch for every new video.
Choose first, from the library, a verified recipe that fits the viewer's question this time, and research a new video only in these cases.

1. No verified recipe in the library explains this question
2. A new medium or subject is needed, such as a live-action cross section, a 3D space, or a code demonstration
3. The sources of the library lean on one platform, which narrows the choice of expression
4. An observation is old and needs checking again

## Sources

Videos from any platform, official demos, and product videos may be mixed.
Only an entry whose video was really played, with the time range and the observed motion recorded, may be `verified`.
A source seen only through its metadata or a search result stays a `candidate` and is never cited as the ground of a scene.
A search uses general words for the kind of motion or a public subject, never names, internal terms, or text taken from the user's files.

| Field | Holds |
|---|---|
| `schemaVersion` | `1`, at the top of the library |
| `entries[].id` | A stable ID |
| `entries[].status` | `verified` or `candidate` |
| `entries[].source` | The `platform`, the `creator`, the `title`, and the `url` of the video |
| `entries[].observations[]` | At least one `range`, such as `00:13-00:45`, and a `description` in plain sentences of what changes on screen. A candidate's range may say it was not checked |
| `entries[].recipes` | The recipes of the motion language catalog the observation shows |
| `entries[].useWhen`, `avoidWhen` | The questions it fits, and when not to use it |
| `entries[].reviewedAt` | The day it was checked, such as `2026-11-24` |

## Using it in a project

Each scene of `storyboard/motion-language-plan.json` cites one or more verified entries in `evidenceIds`, and its main recipe is among the `recipes` of one of them.
Translate the chosen motion into the objects, causes, and screens of the subject.
Never reproduce the art style, interface, characters, or layout of the source.

## Updating it

Research does not stay inside one video's notes.
Add what was checked to the library as soon as it is checked, and update the description, the cases to avoid, and the mechanism of a recipe when needed.
A project keeps only which entries it took from the library and why more research was needed.

## What the check reports

Run the `check-motion-evidence` check of this skill on the library.
Each issue names its `rule` and the `entry`, or no entry when it is about the whole library.

| Rule | Means |
|---|---|
| `schema-version`, `entries` | The library is not version 1, or `entries` is not a list |
| `entry-field` | An entry lacks its id, status, `useWhen`, or `avoidWhen` |
| `duplicate-entry` | Two entries share one ID |
| `status` | The status is not `verified` or `candidate` |
| `source-shape` | The source lacks its platform, its title, or an `http` or `https` address |
| `observation-shape` | An entry has no observation, or one without a range or a description |
| `verified-without-range` | A verified entry has an observation whose range is not a time range |
| `recipes` | An entry names no recipe |
| `reviewed-at` | `reviewedAt` is not a day in the form `2026-11-24` |
