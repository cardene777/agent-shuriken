# The structures

A structure decides which parts a figure has, how they are placed, and in which order the reader reads them.
A style decides how those parts are drawn.
The two are chosen apart, and any structure can be drawn in any style.

This skill ships sixteen built-in structures in `data/built-in-structures.json`, each defined in words, without images.
`python3 scripts/diagram_sample_catalog.py --structures` prints every structure in use, one per line, with its source (`built-in` or `user`), its group, its label, and what it shows.
`--show-structure <structure>` prints one structure with its whole definition.

| Field | What it holds |
|---|---|
| `group` | The group of the structure |
| `label` | The name shown to the user |
| `shows` | The relation the structure shows, and the reader's question it answers |
| `parts` | The parts the figure has |
| `reading_order` | The order in which the reader reads the parts |
| `fits` | Subjects the structure fits |
| `misfits` | Subjects it does not fit, and the structure that fits them instead |
| `status` | `active`, or `retired` when the user's catalog takes the structure out of use |

## The built-in structures

| Group | Structure | The reader's question it answers |
|---|---|---|
| `flow-and-order` | `process-flow` | What happens first, next, and last |
| `flow-and-order` | `message-sequence` | Who sends what to whom, in which order |
| `flow-and-order` | `timeline` | What came before what, and how far apart |
| `flow-and-order` | `cycle` | What keeps a loop going |
| `structure-and-containment` | `layers` | Where a part belongs in a stack |
| `structure-and-containment` | `tree` | What belongs under what in a hierarchy |
| `structure-and-containment` | `nesting` | What is contained in what, and where its limits lie |
| `structure-and-containment` | `network` | How parts reach each other without one root |
| `comparison` | `side-by-side` | Which option does what on the same points |
| `comparison` | `before-after` | What a change altered |
| `comparison` | `two-axis-matrix` | Which items are high or low on two measures |
| `comparison` | `correspondence-table` | What maps to what |
| `state-and-change` | `state-machine` | What can happen next from the current state |
| `state-and-change` | `decision-branch` | What to do in a given case |
| `state-and-change` | `quantity-trend` | How big an amount is, and which way it is heading |
| `state-and-change` | `journey-map` | Where a person's experience goes well or breaks |

## Choosing a structure

A structure the user or the figure request names comes first.
Without one, take the reader's question from the content summary, compare it with the `shows` of each structure in use, and choose the structure that answers it.
Read the `misfits` of the chosen structure: when the subject is one it names, take the structure it points to.
Choose the structure for each figure; two figures of an article may share a structure when they answer different questions.
A structure that is neither built in nor in the catalog, or one the catalog retired, is never drawn; show the user the list and let them choose.

Record the name of the chosen structure in `structure`, in the figure spec and in the entry of the figure in `composition-ledger.json`.
`validate_composition_ledger.py` refuses a figure without a structure in use, and a figure spec whose `structure` differs from its entry.

## Comparing structures

When the user asks to see the same content in different structures, use the `structure-comparison` mode of the composition ledger.
Draw as many structures as the user asks for, two or more, and three when no number is given.
Each figure holds the same content summary and a different structure, and all of them use the same style, so that only the structure changes.
Write the user's words that asked for the comparison in `comparison_request`.
`validate_composition_ledger.py` refuses a structure comparison without `comparison_request`, with one figure, or with a structure drawn twice; it sets no upper limit on the number of figures.
The candidates of a comparison are not finished figures of the article.

## Your own structures

The catalog `~/.styles/style-catalog.json` may hold an optional `structures` object, as [the style catalog](style-catalog.md) describes.
It adds a structure with a new name, replaces the built-in structure of the same name, and takes a built-in structure out of use with only `"status": "retired"`.
