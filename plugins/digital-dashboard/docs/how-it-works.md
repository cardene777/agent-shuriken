# How it works

English · [日本語](how-it-works.ja.md)

The plugin holds one skill, `digital-dashboard`.
The agent follows `skills/digital-dashboard/SKILL.md` and runs three scripts in `skills/digital-dashboard/scripts/`, all with the Python 3 standard library only.

## Files in the skill

| File | What it holds |
|---|---|
| `SKILL.md` | The steps: judge the screens, download, list the attachments, write the request, check the result |
| `scripts/screen_kind.py` | The first pass of the judgment |
| `scripts/fetch_official.py` | The downloader of the official files |
| `scripts/attachments.py` | The list of files to attach |
| `references/official-files.json` | The official files: where each is placed, where it is published, its SHA-256, and when to attach it |
| `references/*.md` | The skill's rules, written in English from the guidebook: design principles, choosing charts, colors, numbers, time axes, the templates' formatting, the chart library, the finished example, and the dos and don'ts |
| `references/conventions/<domain>.md` | The conventions of finance, medical, SaaS, and public sector dashboards |

## The judgment

`screen_kind.py <spec.md>...` reads the table under the item definitions heading of each screen specification (`## Item definitions` in English, or its Japanese name) and finds the kind column by its header (`Kind`, or its Japanese name), or takes the second column when there is no such header.
A cell counts as a chart when it contains `chart` or `graph`, and as a total when it contains `KPI`, `number`, `summary`, `total`, or `trend`, or the Japanese words for these.
The Japanese words are listed in `scripts/screen_kind.py`.
A screen with at least one of each is `candidate`, and every other screen is `other`. Tables under other headings are not counted.

The agent then keeps a candidate as `dashboard` when its main purpose is to read the whole situation from several measures, to spot anomalies or decide the next action, and asks the user when that cannot be decided.

## The download

`fetch_official.py [--dest <dir>] [--manifest <path>]` reads `references/official-files.json`, an array whose entries have `path`, `url`, and `sha256`, with `title`, `attach`, `when`, and `palette` used by the attachment list.

| Step | What happens |
|---|---|
| The file is in place and its SHA-256 matches | It is left untouched: no download, the same inode, the same modification time |
| The file is missing, or differs | It is downloaded into a temporary file next to its place, with a 120-second timeout |
| The download matches | The temporary file is made readable only by you and moved into place |
| The download differs | The temporary file is deleted, a copy already in place is removed, and the file is reported as rejected |

The destination is `~/.local/share/digital-dashboard/`, or `$DIGITAL_DASHBOARD_HOME`, or `--dest`. A folder the script creates is readable only by you.
It prints one line per file (`kept`, `fetched`, `rejected`, or `failed`) and a summary, and exits 0 when every file matches, 1 when any download failed or was rejected, and 2 when the list cannot be read.
Only `https://` addresses are downloaded, and `file://` for a local copy passed with `--manifest`.

The list holds 24 files, about 37 MB:

| Files | Published at |
|---|---|
| `guidebook.pdf`, `guidebook-alt.txt`, `manual.pdf`, `worksheet.pptx`, `toolkit.pptx`, `checklist.xlsx`, `summary-format.docx` | The guidebook's page on `www.digital.go.jp` |
| `templates/<Color>_1_0_0.zip`, seven Power BI templates | The guidebook's page on `www.digital.go.jp` |
| `themes/CustomTheme<Color>Default_2026.json`, seven color themes | The Agency's `policy-dashboard-assets` repository on GitHub, at a fixed commit |
| `map/ja_prefecture_area.json`, `map/ja_municipality_area.json`, `map/ja_municipality_area_with_pref_boundary.json` | The same repository and commit |

## The declaration

A repository can name its own material in `.claude/design-sources.json`.

```json
{
  "schema_version": 3,
  "dashboard_attach_globs": ["catalog/dashboard/guide.md"],
  "dashboard_convention_template": "catalog/dashboard/conventions/{domain}.md",
  "dashboard_on_demand_globs": [
    "catalog/dashboard/numbers.md",
    {"glob": "catalog/dashboard/manual.md", "when": "When the steps of the official tool are needed"}
  ]
}
```

| Version | How it is read |
|---|---|
| 1 | Has no fields for material; the skill's own list is used |
| 2 | `dashboard_attach_globs` names the material; the other two fields are optional; the on-demand entries are paths |
| 3 | As version 2, and an on-demand entry may be `{"glob": ..., "when": ...}` |
| other | Refused with exit 2 |

When the declaration has `dashboard_attach_globs`, all three fields come from it and nothing is added from the skill.
The patterns are expanded by the script, relative to the repository's root, and a pattern that matches nothing stops the list with exit 1.

## The attachment list

`attachments.py [--repo <dir>] [--domain <d>] [--theme <name>] [--official <dir>] [--manifest <path>]` prints one tab-separated line per file:

| First column | Meaning |
|---|---|
| `required` | Attach it |
| `domain` | The conventions of the field given with `--domain`; attach it |
| `on-demand` | Attach it only when the third column, when it is needed, applies |
| `request` | A sentence to copy into the request; printed with `--theme` |

Without a declaration, the list holds the downloaded guidebook and the skill's rules as required, the conventions of the field, and the other rules and downloaded files on demand.
It stops with exit 1 and says to run `fetch_official.py` when a downloaded file is missing.
With `--theme`, it leaves out `color-palette.md`, `theme-spec.md`, `chart-library.md`, the templates, and the color themes, and the `request` line asks the drawing tool to use the theme's colors instead of the guidebook's color palette.

## The request

The agent writes one request for the user's drawing tool: the target screens, the attached files, the screens the guidebook applies to, and the statement that it does not apply to the other screens.
It writes no sizes, colors, fonts, or layout into the request, only the paths, prohibitions, and sample data.
It checks the drawn result itself by listing the screens and reading the exported files and images, rather than trusting the drawing tool's report.

## What it writes and keeps

The plugin writes only the downloaded files, in `~/.local/share/digital-dashboard/`, and keeps them until you delete the folder.
It writes no file in your project and sends nothing anywhere besides the requests for the listed files.
