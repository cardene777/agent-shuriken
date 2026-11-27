# Changelog

This file lists the releases of the repository as a whole, newest first.
Each plugin lists its own releases in `plugins/<name>/CHANGELOG.md`.
A repository release records which plugin versions the marketplace offered at that point, along with changes to the repository itself.
Versions follow semantic versioning, as [Releasing](docs/releasing.md) describes.

## [Unreleased]

### Added

- The motion-explainer plugin, whose skill explains how a mechanism works with a short video of one running example on one offline HTML page, with a narrator, art the agent draws as SVG for each subject, and figures under the video drawn from the same art

### Changed

- `scripts/check.sh` runs the new `scripts/check-musubi.sh`, which checks the musubi declarations of every skill with `musubi-cli` 0.3.0, and the follows of dragon against the dragon skill on dragon's default branch, so a fingerprint that no longer matches fails the checks instead of waiting for a release

## [0.26.0] - 2026-11-26

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.4.0 |
| agent-guards | 0.2.1 |
| agent-notices | 0.1.0 |
| chainome-diagram | 0.2.0 |
| compare-report | 0.6.0 |
| convey | 0.3.0 |
| design-formats | 0.2.0 |
| diagram-composer | 0.1.1 |
| diagram-explainer | 0.4.0 |
| diagram-styles | 0.4.0 |
| digital-dashboard | 0.1.2 |
| doc-formats | 0.1.0 |
| docs-publish | 0.4.0 |
| english-writing | 0.1.0 |
| evm-dev | 0.9.0 |
| excalidraw-diagram | 0.3.0 |
| explaining | 0.1.0 |
| feedback-loop | 0.1.2 |
| flow-format | 0.1.0 |
| init-project | 0.4.0 |
| japanese-speaking | 0.3.0 |
| japanese-writing | 0.3.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.3.0 |
| mechanism-explainer | 0.3.0 |
| motion-diagram | 0.1.0 |
| portman | 0.4.0 |
| product-deck | 0.2.0 |
| remotion-explainer | 0.1.0 |
| repo-progress | 0.2.0 |
| screen-video | 0.4.0 |
| secure-dotfile | 0.8.0 |
| session-handoff | 0.1.1 |
| skill-tune | 0.2.0 |
| slides | 0.1.2 |
| techdebt | 0.4.0 |

### Added

- The english-writing plugin, which writes and fixes English text without adding anything the original does not say, following the patterns of `blader/humanizer` copied without changes, with rules of its own on phrasing translated word for word from Japanese, short sentences, and consistent terms, and a script that points at long sentences, passive voice, and phrasing translated from Japanese
- The explaining plugin, which builds an explanation of how a protocol, a system, or a process works around one running example, with a numbered map of the stages, pairs of similar things told apart, misreadings ruled out, every combination of conditions with its result, moving figures where order or conditions matter, and a closing table with one sentence to take away, and provides that structure to other skills through musubi

## [0.25.0] - 2026-11-26

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.4.0 |
| agent-guards | 0.2.1 |
| agent-notices | 0.1.0 |
| chainome-diagram | 0.2.0 |
| compare-report | 0.6.0 |
| convey | 0.3.0 |
| design-formats | 0.2.0 |
| diagram-composer | 0.1.1 |
| diagram-explainer | 0.4.0 |
| diagram-styles | 0.4.0 |
| digital-dashboard | 0.1.2 |
| doc-formats | 0.1.0 |
| docs-publish | 0.4.0 |
| evm-dev | 0.9.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| flow-format | 0.1.0 |
| init-project | 0.4.0 |
| japanese-speaking | 0.3.0 |
| japanese-writing | 0.3.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.3.0 |
| mechanism-explainer | 0.2.0 |
| motion-diagram | 0.1.0 |
| portman | 0.4.0 |
| product-deck | 0.2.0 |
| remotion-explainer | 0.1.0 |
| repo-progress | 0.2.0 |
| screen-video | 0.4.0 |
| secure-dotfile | 0.8.0 |
| session-handoff | 0.1.1 |
| skill-tune | 0.2.0 |
| slides | 0.1.2 |
| techdebt | 0.4.0 |

### Removed

- The dragon-explainer plugin is no longer offered in the marketplace, because mechanism-explainer writes the same kind of explainer page with dragon figures and is the one explainer plugin kept here. Copies already installed keep working, and its past release and tag stay available

## [0.24.0] - 2026-11-26

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.4.0 |
| agent-guards | 0.2.0 |
| agent-notices | 0.1.0 |
| chainome-diagram | 0.2.0 |
| compare-report | 0.6.0 |
| convey | 0.3.0 |
| design-formats | 0.2.0 |
| diagram-composer | 0.1.1 |
| diagram-explainer | 0.4.0 |
| diagram-styles | 0.4.0 |
| digital-dashboard | 0.1.2 |
| doc-formats | 0.1.0 |
| docs-publish | 0.4.0 |
| dragon-explainer | 0.1.0 |
| evm-dev | 0.9.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| flow-format | 0.1.0 |
| init-project | 0.4.0 |
| japanese-speaking | 0.3.0 |
| japanese-writing | 0.3.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.3.0 |
| mechanism-explainer | 0.1.0 |
| motion-diagram | 0.1.0 |
| portman | 0.4.0 |
| product-deck | 0.2.0 |
| remotion-explainer | 0.1.0 |
| repo-progress | 0.2.0 |
| screen-video | 0.4.0 |
| secure-dotfile | 0.8.0 |
| session-handoff | 0.1.1 |
| skill-tune | 0.2.0 |
| slides | 0.1.2 |
| techdebt | 0.4.0 |

### Added

- The dragon-explainer plugin, whose skill writes an explainer as one HTML file with a figure in every section drawn in the dragon notation, checks each figure with `dragon check` and `dragon check --layout`, and embeds the figures as SVG with `dragon embed`, so the finished file opens offline
- The mechanism-explainer plugin, whose skill writes an explainer page where each section answers one question with a one-sentence answer and two to four figures drawn in the dragon notation, exports it with dragon, and prints it to a PDF
- The remotion-explainer plugin, whose `remotion` skill makes a Remotion explainer video through gates the person approves, with `remotion-explainer-production`, `remotion-explainer-review`, `png-asset-production`, and `png-outline-tracing` under it, whose `remotion-motion-plan` skill plans how the scenes of a Remotion explainer video move, carrying one subject from scene to scene and resting each motion on a watched video, and whose `remotion-frame-checks` skill checks its frames by machine; both provide their contracts and checks to other skills through musubi, and whose `remotion-catalog` skill fetches outside Remotion examples under licenses that allow the use, each at a pinned commit, and searches them by form, composition, typography, or motion
- The flow-format plugin, which answers a question about how a flow, a procedure, or a workflow goes as numbered steps, each one action sentence and a short unindented paragraph of details, with a plain-text diagram after them when the flow branches or loops
- The agent-guards plugin, which adds hooks that stop the agent from reading key files, sending text or commits that hold a key, running destructive git commands, and deleting whole folder trees in Claude Code and Codex
- The agent-notices plugin, which adds hooks that tell the agent about fragile shell commands, branch switches that did not happen, environment variables missing from `.env.example`, a temporary directory running short, and risky code patterns, format each edited file with the project's own formatter, and log skill and MCP calls when turned on, in Claude Code and Codex, without stopping a call

### Changed

- A plugin that holds hooks and no skills may carry hooks, and is not uploaded to OpenAI's directory; every other plugin stays without hooks

## [0.23.0] - 2026-11-24

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.4.0 |
| chainome-diagram | 0.2.0 |
| compare-report | 0.6.0 |
| convey | 0.3.0 |
| design-formats | 0.2.0 |
| diagram-composer | 0.1.1 |
| diagram-explainer | 0.4.0 |
| diagram-styles | 0.4.0 |
| digital-dashboard | 0.1.2 |
| doc-formats | 0.1.0 |
| docs-publish | 0.4.0 |
| evm-dev | 0.9.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.4.0 |
| japanese-speaking | 0.3.0 |
| japanese-writing | 0.3.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.3.0 |
| motion-diagram | 0.1.0 |
| portman | 0.4.0 |
| product-deck | 0.2.0 |
| repo-progress | 0.2.0 |
| screen-video | 0.4.0 |
| secure-dotfile | 0.8.0 |
| session-handoff | 0.1.1 |
| skill-tune | 0.2.0 |
| slides | 0.1.2 |
| techdebt | 0.4.0 |

### Changed

- The follower test of page-design runs the own tests of page-design and of the skills that follow it, and `scripts/check.sh`, only with `test-followers.sh --own-tests`, which Releasing asks for when page-design changes and before releasing design-formats, so a default run ends in seconds instead of about 25 minutes

## [0.22.0] - 2026-11-24

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.4.0 |
| chainome-diagram | 0.2.0 |
| compare-report | 0.6.0 |
| convey | 0.3.0 |
| design-formats | 0.2.0 |
| diagram-composer | 0.1.1 |
| diagram-explainer | 0.4.0 |
| diagram-styles | 0.4.0 |
| digital-dashboard | 0.1.2 |
| doc-formats | 0.1.0 |
| docs-publish | 0.4.0 |
| evm-dev | 0.9.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.4.0 |
| japanese-speaking | 0.3.0 |
| japanese-writing | 0.3.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.3.0 |
| motion-diagram | 0.1.0 |
| portman | 0.4.0 |
| product-deck | 0.2.0 |
| repo-progress | 0.2.0 |
| screen-video | 0.4.0 |
| secure-dotfile | 0.8.0 |
| session-handoff | 0.1.1 |
| skill-tune | 0.2.0 |
| slides | 0.1.2 |
| techdebt | 0.4.0 |

### Changed

- `scripts/check.sh` checks that the root changelog names every plugin, in the `### Plugins` table of the newest repository release or in a line under Unreleased that starts with `The <name> plugin`, and Creating a plugin asks for that line

## [0.21.0] - 2026-11-24

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.3.0 |
| chainome-diagram | 0.2.0 |
| compare-report | 0.6.0 |
| convey | 0.2.0 |
| design-formats | 0.2.0 |
| diagram-composer | 0.1.1 |
| diagram-explainer | 0.4.0 |
| diagram-styles | 0.4.0 |
| digital-dashboard | 0.1.2 |
| doc-formats | 0.1.0 |
| docs-publish | 0.4.0 |
| evm-dev | 0.9.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.3.0 |
| japanese-speaking | 0.3.0 |
| japanese-writing | 0.3.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.2.0 |
| motion-diagram | 0.1.0 |
| portman | 0.4.0 |
| product-deck | 0.2.0 |
| repo-progress | 0.1.2 |
| screen-video | 0.3.1 |
| secure-dotfile | 0.7.1 |
| session-handoff | 0.1.1 |
| skill-tune | 0.2.0 |
| slides | 0.1.2 |
| techdebt | 0.3.1 |

### Added

- The screen-video plugin, whose skill plans a video of a web app with the user, writes it as a flow file in the project, rehearses it into a storyboard of pictures, and records it in a browser into captioned, edited, vertical, and GIF videos only after the user has seen the storyboard, blurring private values and stopping before steps that send something or pay. The edited videos zoom on each action, sit in a themed frame with title, chapter, and end cards, are narrated on the user's machine, and have quiet music and click sounds
- The diagram-styles plugin, whose two skills make figures for articles and technical books: each figure is designed from the reader's question first and drawn with the agent's image generation in a style from the user's own sample images and catalog in `~/.styles/`, which the plugin does not ship. Other skills follow its style4 rules and figure request format through musubi
- The design-formats plugin, whose page-design skill holds how documents and reports explain and look: two formats, four HTML page templates, and the verify script that checks a page or a document. Other skills follow it through musubi
- The doc-formats plugin, whose design-doc skill holds the shared format of a design document and the verify script that checks one. The five design skills of evm-dev now follow it through musubi
- The diagram-composer plugin, which designs the diagram area of a slide with one visual metaphor, a meaning for every connector, and labels kept off the lines, and checks the diagram's geometry with a script before the slide is rendered
- The slides plugin, whose two skills write and check the outline of a deck of ten or more slides, and design a short presentation as HTML that you edit in the browser and export as PowerPoint, PDF, and HTML. The export fetches python-pptx, Pillow, and Playwright through uv for one run, and stops before writing anything when uv is missing
- The chainome-diagram plugin, whose skill designs and reviews animated React and SVG diagrams that explain blockchain mechanics, with one active phase, state changes shown where they happen, and the prose kept apart from the diagram
- The digital-dashboard plugin, whose skill judges which screens of a design are presentation dashboards, downloads the official files of the Japanese Digital Agency's dashboard design guidebook with their fingerprints checked, and writes the request that applies them to those screens only
- The product-deck plugin, whose skill makes a product introduction deck: it takes screenshots of the real product, decides the structure from ten base slides, builds the slides with the words kept apart from the layout, checks the layout and the wording by machine, and renders HTML, PDF, and PowerPoint
- The motion-diagram plugin, whose skill shows how a mechanism works as one moving picture drawn from a small JSON spec, written as an HTML page, a video, a GIF, or an image, and which diagram-explainer places in a section of a document

### Changed

- The report skills of ten plugins, techdebt, compare-report, machine-cleanup, account-cleanup, diagram-explainer, repo-progress, secure-dotfile, init-project, portman, and release-check in evm-dev, follow page-design of design-formats through musubi as optional follows, so each plugin still installs and works alone
- Getting started now places Codex skills in `~/.agents/skills` instead of `~/.codex/skills`, which Codex keeps only for older setups

## [0.20.0] - 2026-11-18

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.3.0 |
| compare-report | 0.5.0 |
| convey | 0.2.0 |
| diagram-explainer | 0.2.2 |
| docs-publish | 0.4.0 |
| evm-dev | 0.5.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.3.0 |
| japanese-speaking | 0.1.0 |
| japanese-writing | 0.2.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.1.0 |
| portman | 0.3.1 |
| repo-progress | 0.1.2 |
| secure-dotfile | 0.7.1 |
| session-handoff | 0.1.1 |
| skill-tune | 0.1.0 |
| techdebt | 0.3.1 |

### Added

- The japanese-speaking plugin, which writes Japanese that sounds like people talking for podcast and radio dialogue, news read and discussed, interviews, narration, and talk scripts, checks the draft with a script for lines that sound read from paper, and has a fresh reader listen for the rest

## [0.19.0] - 2026-11-17

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.3.0 |
| compare-report | 0.5.0 |
| convey | 0.2.0 |
| diagram-explainer | 0.2.2 |
| docs-publish | 0.3.0 |
| evm-dev | 0.4.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.3.0 |
| japanese-writing | 0.2.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.1.0 |
| portman | 0.3.0 |
| repo-progress | 0.1.2 |
| secure-dotfile | 0.7.1 |
| session-handoff | 0.1.1 |
| skill-tune | 0.1.0 |
| techdebt | 0.3.1 |

## [0.18.0] - 2026-11-16

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.3.0 |
| compare-report | 0.5.0 |
| convey | 0.2.0 |
| diagram-explainer | 0.2.2 |
| docs-publish | 0.3.0 |
| evm-dev | 0.3.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.3.0 |
| japanese-writing | 0.2.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.1.0 |
| portman | 0.3.0 |
| repo-progress | 0.1.2 |
| secure-dotfile | 0.7.1 |
| session-handoff | 0.1.1 |
| skill-tune | 0.1.0 |
| techdebt | 0.3.1 |

## [0.17.0] - 2026-11-16

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.3.0 |
| compare-report | 0.5.0 |
| convey | 0.2.0 |
| diagram-explainer | 0.2.2 |
| docs-publish | 0.3.0 |
| evm-dev | 0.2.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.3.0 |
| japanese-writing | 0.2.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.1.0 |
| portman | 0.3.0 |
| repo-progress | 0.1.2 |
| secure-dotfile | 0.7.1 |
| session-handoff | 0.1.1 |
| skill-tune | 0.1.0 |
| techdebt | 0.3.1 |

## [0.16.0] - 2026-11-16

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.3.0 |
| compare-report | 0.5.0 |
| convey | 0.2.0 |
| diagram-explainer | 0.2.2 |
| docs-publish | 0.3.0 |
| evm-dev | 0.1.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.3.0 |
| japanese-writing | 0.2.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.1.0 |
| portman | 0.3.0 |
| repo-progress | 0.1.2 |
| secure-dotfile | 0.7.1 |
| session-handoff | 0.1.1 |
| skill-tune | 0.1.0 |
| techdebt | 0.3.1 |

### Added

- The evm-dev plugin, which tells whether an ERC is final or an EIP is live on Ethereum mainnet, and what it lets contracts and wallets do, from 41 items checked against the official documents with their dates and sources, and re-checks the items that are out of date before answering

### Changed

- The README check in `scripts/check.sh` looks for each skill's name as the Codex `$` list shows it, from the skill's `agents/openai.yaml`, so a plugin can hold more than one skill

## [0.15.0] - 2026-11-16

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.3.0 |
| compare-report | 0.5.0 |
| convey | 0.2.0 |
| diagram-explainer | 0.2.2 |
| docs-publish | 0.3.0 |
| excalidraw-diagram | 0.3.0 |
| feedback-loop | 0.1.2 |
| init-project | 0.3.0 |
| japanese-writing | 0.2.0 |
| learning-to-skill | 0.1.2 |
| machine-cleanup | 0.1.0 |
| portman | 0.3.0 |
| repo-progress | 0.1.2 |
| secure-dotfile | 0.7.1 |
| session-handoff | 0.1.1 |
| skill-tune | 0.1.0 |
| techdebt | 0.3.1 |

### Added

- The convey plugin, which writes a message that tells people what they need, with the conclusion first and nothing the reader does not need, following one of seven message types, and checks its length, formatting, filler phrases, and secret-looking values, local paths, and email addresses for Slack, Discord, an email, or a GitHub comment before copying it to the clipboard
- The japanese-writing plugin, which writes and fixes Japanese text without adding anything the original does not say, following the steps and scripts of `coji/natural-japanese` copied without changes, with a script of its own that points at metaphor verbs and rules for Markdown kept in a repository
- The machine-cleanup plugin, which finds caches tools rebuild, build output git ignores, large and duplicate files, unused apps, dev servers left running, heavy processes, login items, and running containers on macOS, Linux, and WSL, lets you pick on a local page, and frees only your picks, with anything another session uses kept out of reach
- The skill-tune plugin, which measures a plugin's skill with `claude plugin eval` cases kept in the plugin, shortens its `SKILL.md`, and measures again on a private copy so that no case scores lower, with the cost estimated and agreed before any run

## [0.14.0] - 2026-11-15

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.1 |
| compare-report | 0.4.0 |
| diagram-explainer | 0.2.1 |
| docs-publish | 0.2.0 |
| excalidraw-diagram | 0.2.0 |
| feedback-loop | 0.1.1 |
| init-project | 0.2.0 |
| learning-to-skill | 0.1.1 |
| portman | 0.2.0 |
| repo-progress | 0.1.1 |
| secure-dotfile | 0.7.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.3.0 |

## [0.13.0] - 2026-11-14

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.1 |
| compare-report | 0.4.0 |
| diagram-explainer | 0.2.1 |
| docs-publish | 0.2.0 |
| excalidraw-diagram | 0.2.0 |
| feedback-loop | 0.1.1 |
| init-project | 0.2.0 |
| learning-to-skill | 0.1.1 |
| portman | 0.2.0 |
| repo-progress | 0.1.1 |
| secure-dotfile | 0.6.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.3.0 |

## [0.12.0] - 2026-11-14

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.1 |
| compare-report | 0.4.0 |
| diagram-explainer | 0.2.1 |
| docs-publish | 0.2.0 |
| excalidraw-diagram | 0.2.0 |
| feedback-loop | 0.1.1 |
| init-project | 0.2.0 |
| learning-to-skill | 0.1.1 |
| portman | 0.2.0 |
| repo-progress | 0.1.1 |
| secure-dotfile | 0.5.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.3.0 |

## [0.11.0] - 2026-11-14

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.1 |
| compare-report | 0.4.0 |
| diagram-explainer | 0.2.1 |
| docs-publish | 0.2.0 |
| excalidraw-diagram | 0.2.0 |
| feedback-loop | 0.1.1 |
| init-project | 0.2.0 |
| learning-to-skill | 0.1.1 |
| portman | 0.2.0 |
| repo-progress | 0.1.1 |
| secure-dotfile | 0.4.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.3.0 |

## [0.10.0] - 2026-11-14

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.1 |
| compare-report | 0.4.0 |
| diagram-explainer | 0.2.1 |
| docs-publish | 0.1.1 |
| excalidraw-diagram | 0.2.0 |
| feedback-loop | 0.1.1 |
| init-project | 0.2.0 |
| learning-to-skill | 0.1.1 |
| portman | 0.2.0 |
| repo-progress | 0.1.1 |
| secure-dotfile | 0.3.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.3.0 |

## [0.9.0] - 2026-11-14

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.1 |
| compare-report | 0.3.0 |
| diagram-explainer | 0.2.1 |
| docs-publish | 0.1.1 |
| excalidraw-diagram | 0.2.0 |
| feedback-loop | 0.1.1 |
| init-project | 0.2.0 |
| learning-to-skill | 0.1.1 |
| portman | 0.2.0 |
| repo-progress | 0.1.1 |
| secure-dotfile | 0.3.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.2.2 |

### Changed

- `scripts/check.sh` no longer reads the files under `.ikkan/`, the acceptance criteria the ikkan workflow keeps in Japanese, when it looks for text outside English

## [0.8.1] - 2026-11-14

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.1 |
| compare-report | 0.2.1 |
| diagram-explainer | 0.2.1 |
| docs-publish | 0.1.1 |
| excalidraw-diagram | 0.2.0 |
| feedback-loop | 0.1.1 |
| init-project | 0.1.1 |
| learning-to-skill | 0.1.1 |
| portman | 0.1.0 |
| repo-progress | 0.1.1 |
| secure-dotfile | 0.2.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.2.2 |

## [0.8.0] - 2026-11-13

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.1 |
| compare-report | 0.2.1 |
| diagram-explainer | 0.2.1 |
| docs-publish | 0.1.1 |
| excalidraw-diagram | 0.2.0 |
| feedback-loop | 0.1.1 |
| init-project | 0.1.1 |
| learning-to-skill | 0.1.1 |
| portman | 0.1.0 |
| repo-progress | 0.1.1 |
| secure-dotfile | 0.2.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.2.1 |

### Changed

- The link check in `scripts/check.sh` no longer reads links inside fenced code blocks, so a README can show a sample page with its own relative links
- The text checks in `scripts/check.sh` skip font files, so a plugin can bundle the fonts it embeds

### Removed

- One plugin was withdrawn: the marketplace no longer offers it, and its release, tag, and release branch were removed

## [0.7.0] - 2026-11-13

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.0 |
| compare-report | 0.2.0 |
| diagram-explainer | 0.2.0 |
| docs-publish | 0.1.0 |
| excalidraw-diagram | 0.1.0 |
| feedback-loop | 0.1.0 |
| init-project | 0.1.0 |
| learning-to-skill | 0.1.0 |
| portman | 0.1.0 |
| repo-progress | 0.1.0 |
| secure-dotfile | 0.2.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.2.0 |

### Added

- The repo-progress plugin, which shows every repository you work on in one table, with worktrees, open issues and pull requests, uncommitted files, and the ones that have stalled first, without changing anything
- The learning-to-skill plugin, which writes a lesson from a session into the instruction files your agents read, such as AGENTS.md, CLAUDE.md, GEMINI.md, Copilot's instructions, or a skill's SKILL.md, once and in the place that reaches the right agents, only after you approve the diff
- The feedback-loop plugin, which turns a correction you give the agent into fixed files, a review by an evaluator that edits nothing that passes every criterion, and a check or rule that keeps the mistake from coming back
- The session-handoff plugin, which writes a short message to paste into a new agent session and saves the options already rejected, the current phase, delegated work, and things not to do for the project, refusing anything that looks like a secret
- The docs-publish plugin, which writes the public documentation of an open source project in five parts, Quickstart, Concepts, API reference, Cookbook, and FAQ, in English and a second language you pick, and checks that every page has its translation and every link resolves
- The portman plugin, which keeps one registry of the localhost ports each project uses, shows what holds each port right now, suggests free ports that avoid common defaults, finds collisions, and writes a project's ports to `.env.local` and a Docker Compose override after you approve
- The init-project plugin, which sets up a project for local work: a free local port that no other project set up with it gets, a Docker setup for Node and Python web apps and Foundry and Hardhat local chains, and env files linked to 1Password with `op://` references, each file shown before it is written
- The excalidraw-diagram plugin, which draws architecture, flow, sequence, and entity-relationship diagrams as Excalidraw files laid out by a script and checked for overlaps, crowded spacing, and labels on lines, with SVG and PNG copies

### Removed

- The root-cause, doc-review, and pc-tidy plugins are no longer offered in the marketplace, because they are no longer maintained here. Copies already installed keep working, and their past releases and tags stay available

## [0.6.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.0 |
| compare-report | 0.2.0 |
| diagram-explainer | 0.2.0 |
| doc-review | 0.2.0 |
| pc-tidy | 0.2.0 |
| root-cause | 0.2.0 |
| secure-dotfile | 0.2.0 |
| techdebt | 0.2.0 |

### Changed

- Every plugin works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the READMEs and Getting started show how to install, run, update, and remove them there

## [0.5.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.1 |
| compare-report | 0.1.0 |
| diagram-explainer | 0.1.0 |
| doc-review | 0.1.0 |
| pc-tidy | 0.1.1 |
| root-cause | 0.1.0 |
| secure-dotfile | 0.1.0 |
| techdebt | 0.1.0 |

### Added

- The secure-dotfile plugin, which moves the API keys and tokens written into shell startup files into the macOS Keychain without the agent seeing any value
- The techdebt plugin, which ranks the files most worth fixing by combining how often they change with their size, old TODO comments, missing tests, long functions, and duplication
- The doc-review plugin, which reviews a specification, design document, or README once with two reviewers that do not share the conversation, then fixes each finding or records why not

## [0.4.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.1 |
| compare-report | 0.1.0 |
| diagram-explainer | 0.1.0 |
| pc-tidy | 0.1.1 |
| root-cause | 0.1.0 |

### Added

- The diagram-explainer plugin, which writes an explainer with a figure drawn in every section as one HTML file

### Changed

- The publishing page lists root-cause and compare-report, and `scripts/check.sh` fails when a plugin is missing from its tables

## [0.3.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.1 |
| compare-report | 0.1.0 |
| pc-tidy | 0.1.1 |
| root-cause | 0.1.0 |

### Added

- The compare-report plugin, which researches the candidates for a choice and writes an HTML and PDF comparison report
- The root-cause plugin, which finds the cause of a bug from evidence before fixing it
- The repository has an icon in `assets/icon.svg`, shown at the top of the README

### Changed

- The plugin table in the README shows how to run each plugin in Claude Code and Codex
- The marketplace describes the collection as careful plugins for Claude Code and Codex, no longer only housekeeping ones
- The safety page says that the pick page applies to plugins that delete or cancel something, and the rules for kept files to plugins that keep files

## [0.2.1] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.1 |
| pc-tidy | 0.1.1 |

### Added

- Each plugin has an icon in `assets/icon.svg`, so it can be listed in OpenAI's plugin directory

## [0.2.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.0 |
| pc-tidy | 0.1.0 |

### Changed

- Each plugin now lives in its own folder under `plugins/`, so installing a plugin copies only that plugin
- Each plugin has its own version, changelog, README in English and Japanese, license, and manifests for Claude Code and Codex
- The root README describes the collection instead of each plugin

### Added

- Docs for getting started, safety, creating a plugin, releasing, and publishing, in English and Japanese
- `scripts/release.sh` releases a single plugin or the repository

## [0.1.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.0 |
| pc-tidy | 0.1.0 |

### Added

- First public release with the account-cleanup and pc-tidy plugins, installable from this marketplace in Claude Code and Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/v0.26.0...HEAD
[0.26.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.26.0
[0.25.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.25.0
[0.24.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.24.0
[0.23.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.23.0
[0.22.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.22.0
[0.21.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.21.0
[0.20.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.20.0
[0.19.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.19.0
[0.18.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.18.0
[0.17.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.17.0
[0.16.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.16.0
[0.15.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.15.0
[0.14.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.14.0
[0.13.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.13.0
[0.12.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.12.0
[0.11.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.11.0
[0.10.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.10.0
[0.9.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.9.0
[0.8.1]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.8.1
[0.8.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.8.0
[0.7.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.7.0
[0.6.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.6.0
[0.5.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.5.0
[0.4.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.4.0
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.3.0
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.1.0
