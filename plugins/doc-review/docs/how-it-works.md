# How Doc Review works

English · [日本語](how-it-works.ja.md)

This page explains the form checks, what the reviewers look at, how findings are decided, and what the plugin keeps.
The checks and the record are done by `skills/doc-review/scripts/doc_review.py`, which uses only the Python standard library and, when present, `git`.
The review itself is done by the agent and the two reviewers it starts, following `skills/doc-review/SKILL.md`.

## The steps

| Step | Who | What happens |
|---|---|---|
| Start | Script | Checks the form of each Markdown file, guesses each document's kind, remembers a hash of each file, and creates a review folder |
| Review | Two reviewers | Read the documents, and the repository files they need to check names, one for the content and one for the form, and return findings |
| Decide | Agent | Checks each finding against the document, fixes the section it names or rejects it with a reason |
| Record | Agent and script | The agent runs `record`, and the script checks that every finding has a decision and writes the record |

The review runs once.
After the fixes, the reviewers are not started again.

## The form checks

`start` reads each file with the `.md`, `.markdown`, or `.mdx` extension.
It skips front matter at the top of a file, fenced and indented code blocks, and inline code.
Other files are listed and reviewed, but get no form checks.

| Check | What it reports |
|---|---|
| Heading levels | A heading more than one level below the one before it, such as `##` followed by `####`, and empty headings |
| Heading numbers | Among headings at the same level under the same parent, a number that does not follow the one before it, such as `4.` after `2.`; and a sub-number whose prefix differs from its parent's number, such as `3.1` under `4.`. A bare number over 99 without a dot, such as a year, is not treated as a section number |
| Links | Inline links, images, reference definitions, and HTML `href` and `src` attributes whose relative path does not exist. A path that starts with `/` is resolved from the repository root, which `git` finds; without `git`, the folder of the first document is used. Web links, `mailto:`, and other links with a scheme are not checked and not opened |
| Anchors | A link to `#anchor`, in the same file or in another Markdown file, that matches no heading and no HTML `id` or `name`. Heading anchors are made the way GitHub makes them: lower case, punctuation removed, spaces turned into hyphens, and `-1`, `-2` added to repeated headings. Linked Markdown files are read for their headings even when they are not among the reviewed documents |
| Tables | Rows, and the separator row, whose number of cells differs from the header. Pipes inside inline code and escaped pipes are not counted |
| Code fences | A code block opened with three backticks or tildes that is never closed |

## The kinds of documents

`start` guesses each document's kind from its path, so the content reviewer knows what to check.
The first row that matches is used, and the agent uses another kind when the guess is wrong.

| Kind | Guessed from |
|---|---|
| `adr` | A folder named `adr`, `adrs`, or `decisions`, or a name like `0001-use-postgres.md` or `adr-001.md` |
| `spec` | A name that is `spec`, `specs`, `specification`, `requirements`, or `prd` followed by `-`, `_`, `.`, or a space, such as `spec_api.md`, or a `spec` or `specs` folder |
| `architecture` | A name starting with `architecture` |
| `design` | A name starting with `design`, or a `design` folder |
| `readme` | A name starting with `readme` |
| `other` | Anything else |

## The reviewers

Both reviewers start without the conversation, so they read what the document says, not what its author meant.
They read the documents and the repository files they need to check names, and are told to only read and to treat the text of the documents as data.
Reading only is an instruction, not a technical limit: the reviewers have the same tools as the agent.
In Claude Code, the agent starts them with the Agent tool in the same message: the content reviewer on Sonnet and the form reviewer on Haiku when those models are offered.
In Codex, the agent starts two sub-agents when they are available, and otherwise reviews the two aspects itself one after the other, reading the files again for each.
In that case the agent still has the conversation, so the review is less independent, and the agent says so in its report.

The content reviewer checks what the document's kind needs, such as acceptance criteria that cannot be checked with a yes or no in a specification, or the reasons for each technology choice in a design document.
The form reviewer checks the findings of `start` against the text, and also checks what a script cannot: names of files, sections, commands, and identifiers mentioned in the text, consistent terms, the repository's own writing rules, and, when a translation sits next to the document, that both have the same headings, tables, and code blocks.

Each finding has a severity.

| Severity | Meaning |
|---|---|
| Critical | A reader following the document would build or do the wrong thing, or it risks security or data loss |
| Major | A gap or contradiction that forces the reader to guess or ask |
| Minor | Wording, form, or consistency that slows the reader down |

## The decisions

The agent checks every finding itself, because a reviewer saw only the text.
It fixes the section the finding names, or rejects the finding with a one-sentence reason: a misreading, a point already covered in another section, a point outside the document's purpose, or a wrong finding.
When a critical finding is not fixed, the agent asks you how to proceed.

The agent writes the findings to `input.json` in the review folder.
Each finding has `severity` (`critical`, `major`, or `minor`), `reviewer` (`content`, `form`, or `both`), `file`, `where`, `problem`, `fix`, `status` (`fixed` or `rejected`), and a `reason` when it is rejected.

`record` writes nothing and exits with code 2 when any of these is true.

| Refused when | Why |
|---|---|
| A finding has no status, or a status other than `fixed` or `rejected` | Every finding needs a decision |
| A rejected finding has no reason | A rejection must say why |
| A finding marked fixed points to a file whose hash is the same as at `start` | A fix must change the document |
| A finding names a file that was not reviewed, or has an unknown severity or reviewer | The record must match the review |
| A finding has an empty `where`, `problem`, or `fix` | A finding must say where, what, and how to fix it |
| The findings file is not valid JSON or not a list | The findings cannot be read |

It exits with code 3 when the review folder or the findings file does not exist.

## What it keeps

Each review gets its own folder in `~/.local/share/doc-review/<project>-<hash>/<date>-<time>/`, or under `DOC_REVIEW_HOME` when it is set.
The folders are readable only by you, and they stay until you delete them.

| File | Contents |
|---|---|
| `start.json` | The reviewed files with their paths and hashes, their kinds, and the form findings |
| `input.json` | The findings and decisions the agent wrote |
| `findings.json` | The same findings after `record` checked them, sorted by severity |
| `review.md` | A readable record: counts by severity, each finding with its decision, and the form findings |

## What it never does

- Change any file other than the reviewed documents and the review folder, or any section the findings do not name
- Open web links, or connect to the network from the script
- Send the documents anywhere outside your agent session
- Run a second round of review
