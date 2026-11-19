# 0002. The design skills run one shared verify from doc-formats

## Decision

Where the check that a design document has every section filled in lives, now that five evm-dev skills follow one design format.

## Chosen

The `design-doc` skill in the `doc-formats` plugin holds one `verify` script, provided through musubi as the content `verify` and pinned by its fingerprint.
Each design skill passes its own sections file to it, and its own script keeps only the dated items it looks up.

## Rejected

| Option | Why not |
|---|---|
| Keep the five copies of `verify` | Five nearly identical scripts of about 240 lines would stay, and a fix would have to be made five times |
| Replace `verify` with musubi's JSON rules | Until the musubi command is distributed, users could not check a design on their own machine |

## Grounds

- The five scripts differ only in their section names, topics, and dated section (`plugins/evm-dev/skills/*/scripts/*.py`).
- The plugin rule in `AGENTS.md` keeps each plugin self-contained, so the shared script is reached by opening the `design-doc` skill by name, not by a path between plugins.
- Issue #251, decision table.

## Date

2026-11-19
