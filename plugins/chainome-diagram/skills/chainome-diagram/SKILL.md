---
name: chainome-diagram
description: Use when designing or implementing Chainome-style educational animated diagrams for blockchain concepts, especially React and SVG scene diagrams animated with GSAP or Motion, where visual clarity, state transitions, a prose panel kept apart from the diagram, and protocol correctness matter.
---

# Chainome Diagram

## Overview

Use this skill for Chainome animated diagrams that explain blockchain mechanics with moving diagram elements, not video and not generic slideshow controls.
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

1. Define the scene model first, then render it.
2. Keep diagram text short: labels, values, and state badges only.
3. Separate step prose and detailed tables from the diagram.
4. Animate the cause-and-effect path with a moving token or highlight; avoid static arrows when motion is the explanatory device.
5. Make state changes visible where they happen, then show the consolidated state in one nearby table.
6. Run a critical self-review before calling the work complete.
7. Run the project's lint, type check, and build commands, such as `pnpm lint`, `pnpm typecheck`, and `pnpm build`.
8. Use Playwright screenshots and DOM checks for the active phase count, the active token count, overflow, and the mobile layout.

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
