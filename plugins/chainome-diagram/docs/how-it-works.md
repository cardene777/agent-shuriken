# How it works

English · [日本語](how-it-works.ja.md)

The plugin holds one skill, `chainome-diagram`, and one script, `skills/chainome-diagram/scripts/diagram-theme.py`, which reads your theme file.
The agent follows `skills/chainome-diagram/SKILL.md` and writes the diagram's code in your project.

## The theme file

Before drawing, the agent runs `python3 skills/chainome-diagram/scripts/diagram-theme.py` with your project as the current folder.
The script reads the first of these two files that exists, and does not merge them.

| Order | File | Use |
|---|---|---|
| 1 | `.design-theme.json` at the root of the git repository | The look of one project |
| 2 | `~/.design-theme.json` | The look of everything you make |

The file has the format of the theme file of design-formats: up to four objects, `light`, `dark`, `font`, and `space`.
The script checks every key of that format with the same rules: a color is a hex color or `rgb()`, `rgba()`, `hsl()`, or `hsla()`, a font list holds none of `;`, `{`, `}`, `<`, `>`, or `\`, `font.size` is from 12 to 40, `font.line-height` from 1 to 3, and each corner from 0 to 64.
It prints the keys the file sets that a diagram uses as JSON, and the agent writes them as CSS custom properties on the diagram's root element, with the `dark` values under your project's dark mode selector.

| Key | Part of the diagram |
|---|---|
| `bg` | The background of the diagram area |
| `surface` | Actor cards, node fills, and the explanation panel |
| `ink` | Labels, values, and the text of the explanation panel |
| `sub` | Secondary labels and the labels of inactive nodes |
| `line` | Resting paths, borders, and the outline of a contract boundary |
| `accent` | The active path, the moving token, and the outline of the active node |
| `accent-ink` | Text on an `accent` fill |
| `accent-soft` | The highlight behind the active phase and node |
| `label` | The fill of transient state badges and short annotations |
| `sans` | Labels and the explanation panel |
| `mono` | Function names, calldata, and storage keys such as `balanceOf` |
| `size` | The text size of the explanation panel; diagram labels scale from it and stay at 12 px or larger |
| `line-height` | The line height of the explanation panel |
| `radius-small` | Badges and tokens |
| `radius` | Actor cards and nodes |
| `radius-large` | Containers such as a contract boundary, and the explanation panel |

`light.bar`, `dark.bar`, and `space.page-width` belong to pages, so the script accepts them and does not print them.
A key the file leaves out keeps your project's value.

| Case | What the script does | Exit |
|---|---|---|
| No theme file | Prints `{}` and says that the diagram keeps the project's own look | 0 |
| A theme file the rules accept | Prints the keys a diagram uses | 0 |
| An unknown key or a bad value | Names each such key on standard error and prints nothing | 2 |
| A file that is not JSON | Says it cannot read the file and prints nothing | 2 |

## The scene model

Before any rendering, the agent writes a small typed scene model in your project.

| Field | What it holds |
|---|---|
| `nodes` | Actors and objects with a kind, a position, a size, and short display fields |
| `containers` | Boundaries such as a contract's execution area, and which nodes sit inside them |
| `steps` | The phases in order, each with a title, a body, the active path, the active nodes, and state rows |
| `paths` | SVG paths or route data that moving dots and packets follow |
| `stateByStep` | The values after each step; deltas come from adjacent steps |
| `annotations` | Short labels that belong to the drawing, never prose |

The model is local to the diagram. The skill does not ask for a shared JSON schema unless the product needs content that authors edit.

## The screen

The diagram area holds actors, state, paths, moving tokens, highlights, and transient badges.
The explanation panel sits below or beside the diagram and holds the step text and any table.
One phase is dominant at a time, with one moving path and one visible panel.
A change of state shows as a badge next to the element at the moment it happens, and the cards show only the current value.

## The review gates

After each meaningful change, the agent takes desktop and mobile screenshots with your project's Playwright and checks them against these gates.

| Gate | It fails when |
|---|---|
| Protocol structure | The drawing puts behavior where it does not happen, such as storage outside the contract |
| Visual causality | A viewer cannot tell what enters, executes, reads or writes state, and exits without reading the prose |
| State clarity | Current state, deltas, and final state look alike, or arithmetic sits inline |
| Focus | More than one phase, path, or panel competes for attention |
| Composition | Spacing, alignment, hierarchy, or text size looks accidental on either screen |
| Mobile framing | The current operation is not visible in the first mobile viewport |
| Cognitive load | Extra boxes, decorative labels, or repeated explanations compete with the main flow |

A failed gate gets a concrete fix and another review.
For an ERC-20 transfer, a separate gate checks that the signed transaction starts outside the contract, calls `transfer(to, amount)`, writes `balanceOf` inside the contract, and emits `Transfer` after the write.

## What it runs and connects to

The agent runs `diagram-theme.py` with Python 3, and your project's own commands: the lint, type check, and build commands, such as `pnpm lint`, `pnpm typecheck`, and `pnpm build`, and Playwright for the screenshots.
The script and the plugin connect to nothing.

## What it writes and keeps

The agent writes only the diagram's files in your project.
The script reads only the theme file and writes nothing.
The plugin keeps nothing of its own and sends nothing anywhere.
