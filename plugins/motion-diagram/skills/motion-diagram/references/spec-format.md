# The spec format

A spec is one JSON file that lists the parts of the picture and the lines between them.
`motion_diagram.py check` reads it and names each field that breaks a rule below.

## Top level

| Field | Required | What it holds |
|---|---|---|
| `version` | yes | `1` |
| `lang` | no | `en` (the default) or `ja`, the language the page starts in |
| `title` | yes | The opening sentence: what the picture shows, in one line |
| `unit` | no | What the counts count, shown beside the opening sentence, such as `a day` |
| `parts` | yes | The parts, in any order |
| `lines` | no | The lines between parts |
| `boundaries` | no | What the flow never reaches |

## Parts

| Field | Required | What it holds |
|---|---|---|
| `id` | yes | A name for lines to use: a lowercase letter, then lowercase letters, digits, and `-` |
| `kind` | yes | One of the kinds below |
| `name` | yes | The short name shown on the part |
| `count` | sources | How many cards the source sends |
| `keep` | checks and people | How many of the cards it receives it lets through |
| `details` | no | What the part does, shown when it is pressed |
| `example` | no | One example of what passes it, shown under the details |
| `icon` | no | One of the icons below; each kind has its own when this is left out |

| Kind | What it is | Its cards |
|---|---|---|
| `source` | Where cards come from | Sends `count` cards |
| `box` | A step that holds or changes cards | Passes on every card it receives |
| `check` | A step that drops some cards | Passes on `keep` and drops the rest into a bin |
| `person` | A person who decides | Passes on `keep` and drops the rest into a bin, when a drop line goes from it |
| `bin` | Where dropped cards go | Keeps what it receives |
| `end` | Where the kept cards arrive | Keeps what it receives |
| `outside` | Something the flow never reaches | Shown beyond a boundary, with no lines |

A spec with any check or person, or any count, has numbers: then every source needs `count` and every check and person needs `keep`.
A spec with none of them runs its cards without counts.

Icons: `inbox`, `filter`, `read`, `stack`, `person`, `archive`, `done`, `lock`, `doc`, `feed`, `code`, `chat`, `mail`, `data`, `cloud`, `gear`, `chart`, `clock`, `people`, `flag`, `bell`, `key`, `cart`, `globe`.

## Lines

| Field | Required | What it holds |
|---|---|---|
| `from` | yes | The `id` of the part that sends |
| `to` | yes | The `id` of the part that receives |
| `drop` | no | `true` for the line from a check or a person to a bin |
| `back` | no | `true` for a line to an earlier part, drawn as an arc; it carries no cards and pulses each time a card passes the part it starts from |
| `label` | no | A few words on the line; used on a line back |
| `count` | when needed | How many cards go this way, needed on each line of a part that sends to more than one part |

The lines decide the layout: each part sits one column after the latest part that sends it cards.
A source that joins a later part sits beside the column of that part, and a bin sits under the parts that drop into it.
A line back and a drop line do not move a part.

## Boundaries

| Field | Required | What it holds |
|---|---|---|
| `name` | yes | What the boundary keeps out, such as `Never reaches payments` |
| `parts` | yes | The `id`s of the outside parts beyond it |

## What check refuses

| Rule | Example of the line check prints |
|---|---|
| A line names a part that does not exist | `lines[3].to: no part is named "drafs"` |
| A check or a person keeps more than it receives | `parts[3].keep: keeps 140 of the 100 cards it receives` |
| A line back points to a part that does not come earlier | `lines[10]: a line back points to an earlier part, but "issue" does not come before "person"` |
| A line goes to or from a part beyond a boundary | `lines[11]: crosses the boundary "Never reaches payments"; nothing flows to or from a part outside it` |
| Lines go round without a line back | `lines: the lines go round without a line back; give the line that returns "back": true` |
| A line to a bin is not marked as a drop | `lines[4]: a line to a bin is a drop; give it "drop": true` |
| A part sends to more than one part without counts on its lines | `lines[3].count: "rules" sends to more than one part, so each of its lines needs a count` |
| Text is wider than its limit | `parts[2].name: is 31 wide; keep it to 24 (a CJK character counts 2)` |

## Text limits

Width counts 2 for a CJK character and 1 for any other character.

| Field | Limit |
|---|---|
| `title` | 80 |
| `name` | 24 |
| `details` | 200 |
| `example` | 200 |
| `label` | 32 |
| boundary `name` | 40 |
| `unit` | 8 |
