# Step ladders

The JSON that `scripts/ladder.py` reads, and how the drawn figure looks.

## When to use one

A step ladder answers "what happens at which step".
Use it when each step carries several items: what is called, the check that gates it, who acts, and where the result is kept.
Folded into arrow labels, those items become unreadable.
When steps have only a number and a name, an HTML figure (an `html` block with boxes and arrows) is enough.

## Placing one

Put the slot in an `html` block with a caption, so it counts as the section's figure:

```json
{"type": "html", "id": "a-ladder", "caption": "Figure 2 What happens at each step of a checkout",
 "html": "<div class=\"ladder\" data-ladder=\"checkout\"></div>"}
```

The `data-ladder` name reads `<src>/checkout.json`.
Names use letters, digits, `.`, `-`, and `_`.

```bash
python3 scripts/ladder.py --html body.html --src ladders/
```

`ladder.py` rewrites `body.html` in place and exits 1 when the file has no slot, so run it only for documents that have ladders.
The figure's styles are in `assets/ladder.css`, which the template already includes.
`build.py` refuses a document that still has an empty slot.

Default text drawn in the figure follows `<html lang>`: the `alt` fallback and the labels of lines going back read `Step ladder` / `Back to step N` / `back to N` in English and the Japanese equivalents in Japanese.

On narrow screens a ladder keeps its width (at least 720 px, from `assets/ladder.css`) and scrolls sideways inside its frame, so the columns on the right stay readable side by side.
Keep the most important item of each step in the `do` column on the left.
`check.py --live` does not count this sideways scrolling as the page overflowing.

## JSON fields

```json
{
  "schema_version": 1,
  "alt": "Five steps of a checkout, with a line back to step 2 when the member is over a limit",
  "back_note": "back to step %s",
  "actors": {
    "desk": {"label": "Desk or kiosk", "tone": "emphasis"},
    "system": {"label": "Library system", "tone": "plain"},
    "member": {"label": "Member", "tone": "strong"}
  },
  "bands": [{"label": "AT THE DESK", "from": 1, "to": 2}, {"label": "IN THE SYSTEM", "from": 3, "to": 5}],
  "steps": [
    {"n": 1, "title": "Scan the member card", "calls": "card reader", "gate": "card not expired",
     "actor": "desk", "place": "member record"}
  ],
  "back": [{"from": 3, "to": 2, "label": "over the limit"}]
}
```

| Field | Required | Meaning |
|---|---|---|
| `schema_version` | yes | Always `1` |
| `alt` | no | One sentence read out for the figure |
| `back_note` | no | Second label of a line going back; `%s` (exactly once) becomes the target step number |
| `actors` | no | Who acts: a label and a `tone` of `emphasis`, `plain`, or `strong` |
| `bands` | no | Groups of steps with a heading. `from` and `to` are step numbers |
| `steps` | yes | The steps, drawn in array order. See below |
| `back` | no | Lines back to an earlier step. `from` / `to` are step numbers, `label` is the condition |

Fields of one step:

| Field | Required | Meaning |
|---|---|---|
| `n` | yes | Step number (integer). Numbers must be unique; they need not be in ascending order |
| `title` | yes | What is done: first line of the box |
| `badge` | no | Text in the number column (default `n` as two digits) |
| `calls` | no | What is called: second line, left |
| `gate` | no | The check on the result: second line, after `calls` and an arrow |
| `actor` | no | A key of `actors`: sets the colored bar and the label at the bottom right |
| `place` | no | Where the result is kept: top right |

Box width follows the longest line, estimated as 1em per CJK character and 0.6em per other character.
Open the finished page to confirm that no text leaves its box.

## Refused definitions

`ladder.py` checks the definition before drawing and exits 1 at the first problem.

| Refused | Why |
|---|---|
| `schema_version` is not 1 | Fields may mean something else in another version |
| `steps` is empty | Nothing to draw |
| A step has no `n` or `title`, or `n` is not an integer | The box cannot be placed or labeled |
| Two steps share `n` | Rows are looked up by number, so a repeat points at the wrong step |
| `actor` is not a key of `actors` | Its color cannot be chosen |
| `tone` is not one of the three | Same as above |
| A band's range is not in `steps` | The band would float |
| A `back` end is not in `steps` | The line has no end |
| A `back` line does not point to an earlier step | Forward moves belong to the main flow; drawing them here would draw them twice |
| `back_note` does not contain `%s` exactly once | The step number cannot be filled in |

## How the checks see a ladder

| Check | What it reads |
|---|---|
| `check.py` empty slots | An unfilled `<div class="ladder">` fails |
| `check.py` ids and references | The ladder's arrow markers (`<name>-f`, `<name>-b`) are ids in the page |
| `figure.py` captions | The ladder must sit in a `<figure>` with a `<figcaption>` (the `html` block's `caption`) |
| `figure.py` term table | The text of box names and of the lines going back |
| `prose.py` caption numbers | The caption number counts with the page's other figures |
