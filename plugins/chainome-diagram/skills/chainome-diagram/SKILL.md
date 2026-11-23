---
name: chainome-diagram
description: Use when designing or implementing educational animated diagrams that explain blockchain mechanics, especially React and SVG scene diagrams animated with GSAP or Motion, where visual clarity, state transitions, a prose panel kept apart from the diagram, and protocol correctness matter. Takes its colors, fonts, and corners from the user's theme file when one is placed.
---

# Blockchain Diagram

## Overview

Use this skill for animated diagrams that explain blockchain mechanics with moving diagram elements, not video and not generic slideshow controls.
The diagram must make the mechanism legible from visual structure, state, paths, and motion, while the prose explanation stays in a clearly separated region.

Talk to the user in the language they write in.
When the concept to explain, the protocol it follows, or a simplification of a protocol detail is unclear, ask the user in the chat before drawing, and wait for the answer.
This works the same in every agent, because it needs no question tool.

## Quality bar

- Prefer sparse, precise scenes: 4-7 primary nodes for one concept, with clear spacing and one main flow at a time.
- The diagram area shows actors, state, paths, moving tokens, highlights, and transient badges. It must not contain long prose explanation boxes.
- The explanation area is separate from the diagram, usually below or to the right. Do not embed mini-diagrams inside the explanation card unless the user asks for them.
- Do not show all steps at once. One current phase should be visually dominant, with one visible explanation panel and one active moving token or path.
- State displayed inside actor cards should be current state only. Show deltas as transient badges near the relevant element at the moment of change, not as permanent inline arithmetic like `100 -10 90`.
- When behavior happens inside a smart contract, draw the contract as a large execution boundary and place functions, storage, and emitted logs inside it. Do not reduce the contract to a tiny peer node when the lesson is about internal execution.
- Use layout and timing to reduce eye travel: if a ledger or table is needed, put it in the explanation panel or next to the step text, not detached far below the diagram.
- Validate with screenshots at desktop and mobile sizes. Check for overflow, overlapping labels, broken paths, text that is too small, and more than one active panel.

## Intermediate representation

Use a small scene model before rendering:

- `nodes`: stable actors and objects with a semantic kind, position, dimensions, and compact display fields.
- `containers`: semantic boundaries such as contract execution areas. Nodes must declare whether they are inside or outside the boundary in the rendered design, even if the current implementation still stores absolute coordinates.
- `steps`: ordered phases with title, body, active path, active nodes, and state rows.
- `paths`: explicit SVG paths or generated route data for moving dots and packets. Avoid arrowheads when moving-dot flow is the explanatory device.
- `stateByStep`: current values after each step; compute deltas from adjacent states.
- `annotations`: short visual labels only when they are part of the diagram, not prose explanations.

Do not force one universal JSON schema unless the product needs author-editable content.
A typed local scene model is acceptable for high-fidelity prototypes.

## Library guidance

- Use SVG for precise educational diagrams with custom paths, masks, glows, and moving tokens.
- Use GSAP or Motion for timeline orchestration and phase changes.
- Use React Flow or XYFlow for editable node graphs, dependency maps, and graph-like diagrams. Do not force it onto bespoke instructional scenes when custom SVG motion is clearer.
- Use Canvas or WebGL only when the scene is dense or needs particle or field rendering; keep text and accessibility in HTML or SVG where possible.

## The user's look

The diagram takes its colors, fonts, text size, and corners from the user's theme file when one is placed, and keeps the project's own look otherwise.
Before drawing, run `python3 <this skill's folder>/scripts/diagram-theme.py` as a shell command, with the user's project as the current folder.
The script reads the first of these two files that exists, and does not merge them.

| Order | File | Use |
|---|---|---|
| 1 | `.design-theme.json` at the root of the repository | The look of one project |
| 2 | `~/.design-theme.json` | The look of everything the user makes |

- When neither file exists, it prints `{}`. Keep the project's own look: take colors, fonts, and corners from the project's existing styles, and add no palette of your own.
- When a file exists, it prints the keys the file sets that apply to a diagram, as JSON grouped in `light`, `dark`, `font`, and `space`. Write them as CSS custom properties on the diagram's root element, put the `dark` values under the project's dark mode selector when the project has one, and draw the SVG and the explanation panel with `var(...)`. A number is in pixels; write it with `px`, except `line-height`. A key the file leaves out keeps the project's value.
- When it refuses the file (exit 2), it names each wrong key. Tell the user the keys and ask in the chat whether to fix the file first or to draw with the project's own look for now.

Each printed key sets one part of the diagram.

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

`light.bar`, `dark.bar`, and `space.page-width` belong to pages made by other skills, so the script accepts them and does not print them.

## Protocol correctness

For an ERC-20 transfer:

- Alice sends a signed transaction to the token contract.
- The signed transaction is outside the contract before execution. Do not place the transaction card inside the contract boundary.
- `transfer(to, amount)` is calldata and a contract function call, not a separate token object moving between wallets.
- Balances live in contract storage, typically `balanceOf[address]`.
- The ERC-20 contract should be the main container for the mechanism: `transfer()` reads and writes `balanceOf` and emits the log from inside that execution context.
- Read and check phases should not change balances.
- The write phase updates storage: the sender decreases, the recipient increases.
- The emit phase publishes `Transfer(from, to, amount)` as an event log after storage has already changed.

Use this pattern for other protocols too: distinguish message, function, storage, event, proof, and actor.
If the diagram simplifies a protocol detail, say so in the explanation panel.

## Implementation checklist

1. Run `scripts/diagram-theme.py` and apply what it prints, as "The user's look" says.
2. Define the scene model first, then render it.
3. Keep diagram text short: labels, values, and state badges only.
4. Separate step prose and detailed tables from the diagram.
5. Animate the cause-and-effect path with a moving token or highlight; avoid static arrows when motion is the explanatory device.
6. Make state changes visible where they happen, then show the consolidated state in one nearby table.
7. Run a critical self-review before calling the work complete.
8. Run the project's lint, type check, and build commands, such as `pnpm lint`, `pnpm typecheck`, and `pnpm build`.
9. Use Playwright screenshots and DOM checks for the active phase count, the active token count, overflow, and the mobile layout.

## Review loop

Never treat a passing build as proof of quality.
After each meaningful diagram change:

1. Capture desktop and mobile screenshots with Playwright.
2. Review the diagram harshly against these gates:
   - **Protocol structure**: the drawing must reflect where the mechanism actually happens. For smart contracts, internal function, storage, and log behavior must be spatially inside the contract boundary.
   - **Visual causality**: the viewer can tell what enters, what executes, what reads or writes state, and what exits without relying on prose.
   - **State clarity**: current state, transient deltas, and final state are visually distinct; no inline arithmetic clutter.
   - **Focus**: only the current phase is dominant; inactive paths and nodes are quiet.
   - **Composition**: spacing, alignment, hierarchy, and text scale look intentional on desktop and mobile.
   - **Theme**: when the script printed a theme, the parts in the key table use its values and no other colors, fonts, or corners.
   - **Mobile framing**: the current operation and the current state change must be visible in the initial mobile viewport; do not rely on the user scrolling sideways to find the active part of the diagram.
   - **Cognitive load**: no extra boxes, decorative labels, or duplicated explanations that compete with the main flow.
3. If any gate fails, make a concrete fix and run the review again.
4. Do not hand off while a material known issue remains. A material issue is any flaw that can mislead the learner about protocol semantics, hide the causal path, make the current state ambiguous, or make the diagram hard to scan.
5. If a remaining issue is only a deliberate tradeoff, write down why it is acceptable in this specific diagram before finishing.
6. In the final response, say what was reviewed. Do not call the diagram perfect unless there are no known material issues after the screenshot review.

## ERC-20 transfer review gate

Before finishing an ERC-20 transfer diagram, verify that all of these are true:

- The contract is the main execution boundary.
- The signed transaction is outside the contract boundary until it enters execution.
- The signed transaction enters the contract and calls `transfer(to, amount)`.
- `transfer()` is visually connected to `balanceOf` as the state source.
- The storage write is visible at `balanceOf`, not only on wallet cards.
- Wallet cards are clearly views or readouts, not the place where ERC-20 balances are stored.
- The event log is visibly emitted after the storage write.
- Each phase has exactly one dominant operation, one active motion path, and one explanation panel.
- For a diagram whose audience reads Japanese, diagram labels and review notes are in Japanese unless an English protocol term is the clearest exact term.
