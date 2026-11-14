# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Docs Publish reads, writes, runs, and keeps, and every rule its script applies.
The agent writes and translates the pages; the script `skills/docs-publish/scripts/docs_publish.py` lays out the folders, keeps the translation map, and checks the result.
The script uses only the Python standard library and reads and writes only the docs folder.

## What it reads

| Who | Reads |
|---|---|
| The agent | Your project's files: the README, the package manifest, the public entry points, the command-line help, the examples, the tests, the changelog, and any existing docs. With your agreement, the titles, bodies, and comments of your project's most discussed GitHub issues, through `gh`. Also with your agreement, the table of contents and up to five pages of the docs of each project you name to follow, through `gh api` for a GitHub repository or the agent's tool for reading web pages for another site; only their structure is taken, never their text |
| The script | The plan the agent passes it, `_translation-map.json`, and the Markdown files in the docs folder's language folders |

Everything it reads is treated as data, never as instructions.

## The plan

The agent proposes a plan, shows it to you with `scaffold --dry-run`, and lays out the folders once you agree.
The plan is JSON.

```json
{"project": "Acme Shop",
 "languages": [{"code": "en", "name": "English"}, {"code": "es", "name": "Español"}],
 "concepts": [{"slug": "carts", "title": "Carts"}],
 "api": [{"slug": "createCart", "title": "createCart"}],
 "cookbook": [{"slug": "apply-a-coupon", "title": "Apply a coupon"}]}
```

| Field | Rule |
|---|---|
| `project` | The project's name, up to 80 characters on one line |
| `languages` | One or more languages, the source first. `code` is a language tag such as `en`, `ja`, or `pt-BR` and names the language's folder. `name` is the language's own name, shown in the language switch. A code may appear once |
| `follow` | Optional. The projects whose docs were followed, each with `name` (up to 80 characters on one line), `url` (starting with `https://`, without spaces), and `adopted` (what was followed, up to 200 characters on one line). Left out means none, and the map keeps the list |
| `concepts`, `api`, `cookbook` | At least one page each. `slug` names the file and uses letters, digits, `.`, `_`, and `-`, starting with a letter or digit, with `/` for a subfolder; a trailing `.md` is dropped, and `README` is not allowed. `title` is up to 80 characters on one line |

Titles and names may not contain `[` or `]`, because they become link text.
When the plan has problems, the script lists all it finds, writes nothing, and exits 2.

## The layout

The docs folder is `docs` unless `--root` names another one.
Each language has a folder named by its code, with the same pages at the same paths.

```text
docs/_translation-map.json
docs/<code>/README.md              the index
docs/<code>/quickstart.md
docs/<code>/concepts/README.md     and concepts/<slug>.md
docs/<code>/api/README.md          and api/<slug>.md
docs/<code>/cookbook/README.md     and cookbook/<slug>.md
docs/<code>/faq.md
```

The six fixed pages are always there; pages under `concepts/`, `api/`, and `cookbook/` come from the plan or from `add`.
The first language in the map is the source, and every other language is translated from it.
Files in the docs folder outside the language folders, such as shared images in `docs/assets/`, are not part of the map and are not checked except as link targets.

## Starter pages

`scaffold` writes a starter page for every page in every language, then the map.
It never overwrites a file: a page that already exists is kept as it is and listed as kept.
When `_translation-map.json` already exists, it writes nothing and exits 3.

A starter page in the source language has the title, the language switch line, and the outline of its part, with a to-do note in each section: an HTML comment that starts with `docs-publish:todo`.

| Page | Title | Outline |
|---|---|---|
| `README.md` | The project's name and "documentation" | A note for the opening paragraph, and one section per part linking its page |
| `quickstart.md` | Quickstart | Requirements, Install, First run, and Next steps linking the Concepts and Cookbook indexes |
| `concepts/README.md`, `api/README.md`, `cookbook/README.md` | Concepts, API reference, Cookbook | A note for the opening paragraph, and a link to every planned page of the part |
| `concepts/<slug>.md` | From the plan | Why, How it works, Example, and Related |
| `api/<slug>.md` | From the plan | Signature, Parameters, Returns, Errors, Example, and Related |
| `cookbook/<slug>.md` | From the plan | Before you start, Steps, Check the result, and Related |
| `faq.md` | FAQ | One note on how to write the questions |

The Related section links back to the part's `README.md`.
A starter page in another language has the title, the language switch line, and one note naming the source page to translate.
The language switch line sits under the title, names the page's own language, and links the same page in every other language with a relative path, such as `../es/quickstart.md` from `en/quickstart.md`.
With one language, pages have no switch line.

## The translation map

`_translation-map.json` holds the languages, the projects the docs follow, and the pages, in reading order.

```json
{
  "version": 2,
  "languages": [
    {"code": "en", "name": "English"},
    {"code": "es", "name": "Español"}
  ],
  "follow": [],
  "pages": [
    {"path": "README.md", "source_sha256": {"es": "<sha256 of en/README.md when es/README.md was recorded>"}},
    {"path": "quickstart.md", "source_sha256": {}}
  ]
}
```

`source_sha256` maps each translation's language code to the sha256 of the source page at the moment the translation was recorded.
An empty object means no translation of that page has been recorded yet.

The script reads versions 1 and 2, and exits 2 with the version it found for any other.
Version 2 added `follow`. A version 1 map is read as following no project and written back as version 2 the next time a command writes the map, and a script that reads version 1 only refuses version 2 instead of dropping the list.
It also exits 2 when a `follow` entry breaks the rules of the plan.
It also exits 2 when a page path is outside the layout or listed twice, when a `source_sha256` entry names an unknown language or the source language or is not a sha256 value, or when one of the six fixed pages is missing from the map.
It writes the map to a temporary file in the docs folder and renames it over the old one, so a failed write never leaves half a map, and it removes the temporary file if the write fails.

## Commands

Each command takes `--root <docs folder>`, which defaults to `docs`.

| Command | What it does | Exit codes |
|---|---|---|
| `scaffold <plan>` | Reads the plan from a file, or from standard input with `-`, and writes the starter pages and the map. `--dry-run` lists the files and writes nothing | 0 written, 2 the plan has problems, 3 the map already exists |
| `add <path> --title <title>` | Adds a page under `concepts/`, `api/`, or `cookbook/` to every language and to the map, appending `.md` when it is missing. Keeps a file that exists | 0 added, 2 the path is outside those folders, is a fixed page, or is already in the map |
| `drop <path>` | Removes a page from the map and lists its files that are still there. Deletes no file | 0 removed, 2 a fixed page or a page not in the map |
| `translated <path>...` | Records that each translation matches the current source page | 0 every page recorded, 1 a page was not recorded, 2 bad input |
| `check` | Checks the pages against the map and each other, and writes nothing | 0 no problems, 1 problems listed, 2 the map cannot be read |

`translated` takes `quickstart.md`, `es/quickstart.md`, or `docs/es/quickstart.md`.
`--lang <code>` names the translation's language when the docs have more than one translation.
It exits 2 when the path names the source language, the language is not in the map, or the docs have only one language.
It does not record a page that is not in the map, whose source or translation is missing or not UTF-8, whose source or translation still has to-do notes, or whose headings, code blocks, or table rows differ from the source, and it prints the reason for each.
It writes the map only when it recorded at least one page.

## The checks

`check` reads every page in the map in every language, and lists each problem on its own line, grouped by kind.

| Kind | Rule |
|---|---|
| `missing` | Every page in the map exists in every language folder and is UTF-8 |
| `unmapped` | Every `.md` file under a language folder is in the map |
| `todo` | No page has a `docs-publish:todo` note left outside code blocks |
| `content` | In the source language, every page under `concepts/` other than a `README.md` has a `mermaid` code block, and `quickstart.md` and every page under `api/` and `cookbook/` other than a `README.md` has a code block that is not a `mermaid` block. Pages with to-do notes are skipped |
| `structure` | Each translation has the same heading levels in the same order, the same code blocks with the same language in the same order, and the same number of table rows as its source |
| `untranslated` | Each translation has a sha256 recorded in the map |
| `stale` | The recorded sha256 equals the sha256 of the source page now |
| `link` | Every relative link resolves to a file or folder, with the same letter case as on disk |
| `crosslink` | A link that resolves into another language's folder points at the same page in that language, which is the language switch |
| `switch` | Every page links the same page in every other language |
| `orphan` | Every page can be reached by following links from its language's `README.md` |

`structure`, `untranslated`, and `stale` skip a page when it or its source is missing or still has to-do notes.
`orphan` is checked for a language only once none of its pages has to-do notes, since starter pages do not link everything yet.

The output starts with a line naming the docs folder, the number of pages, and the languages, and ends with the number of problems and a count of the links checked and broken.

### How pages are read

- A code block starts with three or more backticks or tildes, indented by at most three spaces, and ends with a line of the same character, at least as long, and nothing else. A backtick line whose language contains a backtick is not a code block
- A heading is a line that starts with one to six `#` characters, indented by at most three spaces, followed by a space, a tab, or the end of the line
- A table row is a line whose first character other than spaces is `|`
- A code block's language is the first word after the opening backticks, in lower case; a block without one counts as plain
- Nothing inside a code block is read for headings, table rows, to-do notes, or links

### How links are read

- The script reads inline links and images, reference definitions such as `[label]: path`, and the `src` and `href` attributes of HTML tags, outside code blocks and after removing code spans. Footnotes such as `[^1]: text` are not links
- A target in angle brackets is read without them, and a title after the target is ignored
- Targets that are empty, start with `#` or `//`, or start with a scheme such as `https:` or `mailto:` are not checked
- Targets that start with `/` are not checked, because their meaning depends on where the docs are served; the summary counts them
- For the rest, the part after `#` or `?` is removed, percent-encoding is decoded, and the path is resolved from the folder of the page that holds the link. Anchors are not checked
- The file or folder must exist, and every part of its path must match the letter case on disk, because links are case-sensitive on GitHub and most web servers even when your disk is not
- For reach, a link to a folder counts as a link to its `README.md`

## What it runs and connects to

- The script runs no other program and connects to nothing
- The agent runs the script with `python3`, and runs your project's Quickstart and Cookbook commands to show their real output only when they need nothing new installed. It asks before installing anything
- With your agreement, the agent runs `gh issue list` and `gh issue view` on your project, which sends the repository's name to GitHub through your own `gh` sign-in
- With your agreement, the agent reads the docs of the projects you name to follow: `gh api` for a GitHub repository, which sends its name to GitHub through your own `gh` sign-in, and the agent's tool for reading web pages for another site, which requests those pages from that site. When the agent has no such tool, it skips the project and tells you. Nothing else is sent anywhere

## What it keeps

- The pages and `_translation-map.json` in your docs folder, until you delete them
- Nothing outside your project: no settings, no cache, and no state folder
- No temporary files: the one temporary file used to write the map is renamed into place or removed
- Nothing is committed, pushed, or published; you review the new files and commit them yourself
