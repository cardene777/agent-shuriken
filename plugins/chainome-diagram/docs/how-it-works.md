# How it works

English · [日本語](how-it-works.ja.md)

The plugin holds one skill, `chainome-diagram`, and no scripts.
The agent follows `skills/chainome-diagram/SKILL.md` and writes the diagram's code in your project.

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

The agent runs your project's own commands: the lint, type check, and build commands, such as `pnpm lint`, `pnpm typecheck`, and `pnpm build`, and Playwright for the screenshots.
The plugin connects to nothing.

## What it writes and keeps

The agent writes only the diagram's files in your project.
The plugin keeps nothing of its own and sends nothing anywhere.
