---
name: digital-dashboard
description: Decides which screens of a design are presentation dashboards, downloads the official material of the Japanese Digital Agency's "Practical guidebook for dashboard design" and checks each file's fingerprint, and writes the request for the user's drawing tool that attaches that material and applies it to those screens only. Use when asked for a dashboard, a KPI screen, data visualization, a BI or Power BI style screen, a public sector dashboard, a metrics screen, or a totals screen.
---

# Digital Dashboard

This skill brings the Digital Agency's "Practical guidebook for dashboard design" (edition of 2026-03-31) into the drawing of dashboard screens.
It judges which screens are dashboards, downloads the official files, lists what to attach, and writes the request text for whatever drawing tool the user works with.

Talk to the user in the language they write in.
When a step below says to ask the user, ask the user in the chat and wait for the answer.
Agents that offer a tool for asking questions may use it for the same question; in other agents, ask it as a short numbered list of the choices.

## What it does and does not do

| | What |
|---|---|
| **Does** | Judges which of the screens are presentation dashboards (section 1) |
| **Does** | Downloads the official files into the user's folder and checks their fingerprints (section 2) |
| **Does** | Lists the files to attach, from the repository's declaration or from the downloaded files and this skill's rules (section 3) |
| **Does** | Writes the request that applies the dashboard rules to those screens only (section 4) |
| **Does not** | Draw: the user's drawing tool draws |
| **Does not** | Write requirement documents |
| **Does not** | Score the screens after drawing, compare images, or loop on reviews |

**This skill writes no file in the user's project.**
The only file it writes is what `fetch_official.py` downloads into its own folder.

The scripts live in `scripts/` next to this `SKILL.md`. Run each code block below as one shell command, with `S` set to that folder on its first line.

## 1. Judge the screens

The judgment has two passes.
The first pass, a script, marks candidates; the second decides from each screen's main purpose.

### First pass: mark the candidates

Count the kind column of the item definitions table in each screen specification.

| Condition | Result |
|---|---|
| At least one chart, and at least one total (a kind that holds a number, a summary, a KPI, a total, or a trend) | `candidate` |
| Anything else | `other` |

The words of the kind column differ from one specification to another, so a cell counts when it contains one of the words.
The script reads the kind column by its header under the item definitions heading, in a specification written in Japanese or in English (`## Item definitions` with a `Kind` column), and never counts the source column. The exact Japanese and English words are in `scripts/screen_kind.py`.

```bash
S=<folder that contains this SKILL.md>/scripts
python3 "$S/screen_kind.py" <spec-dir>/*.md
```

It prints `<file> chart=<n> total=<n> => candidate` or `=> other` for each file.

**Do not call the first pass's result a dashboard.**
Charts and totals also appear on detail screens, so a candidate still goes through the second pass.

`<spec-dir>` is the folder of screen specifications the user points to.
When the repository has no screen specifications, ask the user which screens are drawn and what each shows, and judge from the answer by the same rules.

### Second pass: decide from the main purpose

Only the screens the first pass marked `candidate` go on. A screen marked `other` stays `other`.

| Condition | Final result |
|---|---|
| The screen reads the whole situation from several measures, mainly to spot anomalies or decide the next action | `dashboard` |
| The screen digs into one entity in detail, or is mainly for complex analysis | `other` |
| Both fit and the main purpose cannot be decided | `ambiguous` |

The first row is what the guidebook calls a presentation dashboard, and the second an exploration dashboard (§1.1).
The guidebook covers only presentation dashboards, so an exploration screen gets no material.
**A period switch or a simple filter does not make a screen exploratory.** Presentation dashboards have them too; counting them would push presentation screens to `other`.

Ask the user about the `ambiguous` screens only.

**When the user says a screen is a dashboard, take it as a hint and judge again anyway.** Taking it as given would split the rules into two places. When the two disagree, use the final result and tell the user that they disagreed.

## 2. Download the official files

Before attaching anything, run:

```bash
S=<folder that contains this SKILL.md>/scripts
python3 "$S/fetch_official.py"
```

It downloads the files listed in `references/official-files.json` from the Digital Agency's published locations (`www.digital.go.jp`, and the Agency's `policy-dashboard-assets` repository on GitHub) into `~/.local/share/digital-dashboard/`, or into `$DIGITAL_DASHBOARD_HOME` when that is set.
The first run downloads about 37 MB. Each file is kept only when its SHA-256 matches the list; a file already in place that matches is not downloaded again, so later runs download nothing.

When it exits with a code other than 0, stop: tell the user which files failed or were rejected, and attach nothing.
A rejected file means the published file changed since the list was made; the plugin needs an updated list.

## 3. List the attachments

Run this only for the screens whose final result is `dashboard`, after section 2:

```bash
S=<folder that contains this SKILL.md>/scripts
python3 "$S/attachments.py" --repo "$(git rev-parse --show-toplevel)" --domain <domain> --theme <theme>
```

Leave out `--domain` when the field cannot be judged, and `--theme` when the drawing tool uses no theme.

**Where the material comes from is decided by the repository's declaration, `.claude/design-sources.json`.**
When the declaration has `dashboard_attach_globs` (schema versions 2 and 3), the list takes all three fields from the declaration, with paths in the repository, and adds nothing from this skill: mixing the repository's material with this skill's would give the same points twice, written two ways.
Version 1 has no fields for material, and a repository without a declaration uses this skill's list: the downloaded official files and the rule files under `references/`.

The output has one file per line, and the first word says how to attach it.

| First word | How |
|---|---|
| `required` | Attach it |
| `domain` | Printed only when the field was judged. Attach it |
| `on-demand` | Read the third column, which says when the file is needed, and attach it only when the screens need that. The column is the declaration's `when` (version 3), or else the first line of the file's text |
| `request` | Not a file: copy the sentence into the request text (section 4) |

**When a pattern matches nothing, or an official file is missing, the script stops with a non-zero exit.** Do not go on without the material; run section 2 again, or tell the user which pattern of the declaration matched nothing.

### The field

When the specifications show the field, pass it to `--domain`.

| Field | `--domain` | File |
|---|---|---|
| Finance and asset management | `finance` | `references/conventions/finance.md` |
| Medical | `medical` | `references/conventions/medical.md` |
| SaaS | `saas` | `references/conventions/saas.md` |
| Public sector | `civic` | `references/conventions/civic.md` |

Judge from the words of the specifications: total assets, money market funds, or yields for finance; monthly active users, recurring revenue, or churn for SaaS; patients or beds for medical; policies or issuing rates for the public sector. When none fits, leave the field out.

### With a theme

When the drawing tool uses a theme, pass its name to `--theme`.
The list then leaves out the files that only set colors (`color-palette.md`, `theme-spec.md`, `chart-library.md`, the Power BI templates, and the theme files), and prints a `request` line that asks for the theme's colors instead of the guidebook's palette.
Giving the drawing tool the theme's colors and the guidebook's colors together leaves it unclear which to follow.

**Decide the theme before running this step.** When the drawing tool offers themes to choose from first (section 4), run this step again with the chosen theme.

### This skill's own list

Without a declaration, the list holds:

| How | File | What |
|---|---|---|
| required | `guidebook.pdf` (downloaded) | The guidebook itself |
| required | `references/abstraction-principles.md` | The design principles, the path of the eye, the 16:9 grid, and what not to do |
| required | `references/chart-decision-tree.md` | Choosing a chart, the number of series, and the steps of color |
| required | `references/color-palette.md` | The official color codes of the 7 families and the roles of chart colors (left out with a theme) |
| domain | `references/conventions/<domain>.md` | The conventions of the field |
| on-demand | `references/numeric-format.md` | When currency, units, and percentages need one notation |
| on-demand | `references/time-axis.md` | When the tick spacing and the granularity of time axes need to agree |
| on-demand | `references/theme-spec.md` | When the screens follow the formatting inside the templates (left out with a theme) |
| on-demand | `references/chart-library.md` | When the 30 charts of the templates and their default sizes are needed (left out with a theme) |
| on-demand | `references/visual-ssot.md` | When checking lone line charts, dual axes, and hidden grid lines |
| on-demand | `references/dos-donts.md` | When checking the guidebook's dos and don'ts |
| on-demand | The other downloaded files | When each one's `when` in `references/official-files.json` applies: the plain-text guidebook, the manual, the worksheet, the prototyping kit, the checklist, the summary format, the templates, the theme files, and the maps |

The on-demand files are not attached by default: each one makes the drawing tool read more.

## 4. The request to the drawing tool

**Send one request.** Do not split dashboard screens and other screens into separate requests. Keep the material attached, and **limit where it applies in the words of the request.**

```
<The target screens, and what goes where, in 1-3 sentences>

## Attachments

- Screen specifications: <path>, for every screen drawn
- Shared layout: <path>
- Brand: <path>
- Dashboard material: <the required and domain paths that attachments.py printed, and the on-demand paths chosen>

## Screens the guidebook applies to

Only <screen A> and <screen B>.

Do not apply it to the other screens. Do not add headline KPIs, charts, comparisons, or summary paragraphs to them; draw only what their item definitions list.

<With a theme, the sentence of the request line that attachments.py printed>
```

Hand the request and the attachments to the drawing tool the user works with, in the way that tool takes files.

### Always limit where it applies

Write both "apply it only to these screens" and "do not apply it to the others". With only one of them, the drawing tool adds headline KPIs and charts to list and form screens too.

**Do not send a request without the material.** Splitting requests by whether material is attached would put the judgment in two places. The judgment shows only in the words of the request.

### Do not split

However many screens there are, send one request and let the drawing tool draw them in one run. Do not split them into batches in advance.

### Attach only the specifications of the screens drawn

When only some screens of a set are drawn, attach only their specifications and the shared layout. Attaching the specifications of screens that are not drawn makes the drawing tool draw them too.

### When the drawing tool offers themes first

Some drawing tools answer a first request without a theme with theme proposals instead of the screens.
Show the proposals, ask the user to pick one (or none), run section 3 again with the chosen theme, and send the request again in the same form.
The proposals do not count as the request; there is still one request for the screens.

**When the drawing stops partway, resume from what is already drawn.** Use the same form, and add which screens are drawn and which are still to draw.

### Never write design values into the request

**Do not write sizes, color values, font sizes, corner radii, or layout splits into the request.** They are in the attached specifications and material.
Written twice, they disagree sooner or later, and the request wins over the specifications: a sidebar width written into a request once overrode the 260px of the specification with 240px.

Only three things may be written:

| May be written | Why |
|---|---|
| The paths of the attached files | They name the sources |
| Prohibitions (such as not passing a file that another tool manages) | They prevent destructive mistakes |
| Sample data (amounts, dates, company names) | The specifications have no examples, and the screens need the same values (the guidebook, §3.3: random sample numbers are fine) |

Do not write checks or a report format into the request either. Check the result yourself (section 5).

## 5. Check the result yourself

**Do not take the drawing tool's report as proof.** A report of "5 screens drawn" has turned out to be 1 screen.

| Check | How |
|---|---|
| Every screen is there | List the screens or frames from the drawing tool's file or export |
| Sizes follow the specifications | Search the exported HTML or the file for the sizes |
| No forbidden decoration | Count `shadow` and `animate` in the exported HTML |
| The look | Look at the exported images one by one |

Export the result yourself when the drawing tool can be run from the shell; an export left to the drawing tool's own run is lost when that run fails.

## 6. Rules

| # | Never | Why |
|---|---|---|
| 1 | Write HTML, SVG, or the drawing tool's files from this skill | Drawing belongs to the drawing tool; writing them directly bypasses its design rules and leaves only hand-fixing of coordinates |
| 2 | Write requirement documents or other files from this skill | The user writes them when they need them; extra files duplicate the specifications |
| 3 | Write sizes, colors, fonts, or layout into the request | They duplicate the specifications, and the request wins when they disagree |
| 4 | Attach the material without limiting where it applies | The drawing tool adds headline KPIs and charts to screens that are not dashboards |
| 5 | Take the drawing tool's report as proof | "5 screens drawn" has turned out to be 1 |
| 6 | Score the screens after drawing | The scores never converge on values the specifications do not define |
| 7 | Attach an official file that `fetch_official.py` did not keep | Its fingerprint differs from the published file, or it was never downloaded |

## 7. Files

| What | Where |
|---|---|
| The list of official files, their published locations, and their fingerprints | `references/official-files.json` |
| The downloader | `scripts/fetch_official.py` |
| The attachment list | `scripts/attachments.py` |
| The first pass of the judgment | `scripts/screen_kind.py` |
| The rules written for this skill from the guidebook | `references/*.md` |
| The conventions of each field | `references/conventions/<domain>.md` |
| Where the official files come from and their terms of use | `THIRD_PARTY_NOTICES.md` at the root of the plugin |

The official files are not part of the plugin. They are downloaded into `~/.local/share/digital-dashboard/` and stay there until the user deletes the folder.
