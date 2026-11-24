# Third-party notices

The plugin bundles no third-party file.
`skills/remotion-catalog/data/sources.json` names the outside repositories that `remotion-catalog` fetches into the user's data folder when the user runs its `sync` command, each at the commit below.

| Source | Repository | Commit | License | License evidence | Checked on |
|---|---|---|---|---|---|
| `reactvideoeditor-remotion-templates` | `reactvideoeditor/remotion-templates` on GitHub | `6209b724798e48ff395f8df1a6fa2d26082372b5` | MIT | The License section of `README.md`; the repository has no `LICENSE` file at this commit | 2026-11-24 |
| `video-shotcraft` | `Vincentwei1021/video-shotcraft` on GitHub | `0d6f0b57f0d4d6700761644c07f7ef03c3e50234` | Apache-2.0 | `LICENSE` | 2026-11-24 |

`video-shotcraft` names what its shot cards studied in `references/shots/ATTRIBUTION.md`, and states that every card is rewritten from scratch.
Its sounds under `assets/audio/` are not fetched, because their own notice says that the sources of some are not confirmed.

Code copied from a source into a project keeps that source's license: the copyright and license notice for MIT, and the license with a note of the changes for Apache-2.0.
