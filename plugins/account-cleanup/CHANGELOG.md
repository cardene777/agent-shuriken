# Changelog

Releases of the account-cleanup plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The candidate sheet shows the domain under a name only when the name does not already hold it, and wraps a long name, such as a browser extension's ID, instead of cutting it. On a phone, the domain moves under the name instead of cutting both
- Each tab of the candidate sheet keeps its own sort, and the sort by last round's result is offered only on a tab that has such rows, so the sort shown is the one the rows follow
- The help of the candidate sheet explains every deletion effort the details can show, including Partial, Service ended, and a site that is gone, in English and Japanese
- Text colors in the light theme of the candidate sheet are darker, so every text reaches a contrast of 4.5 to 1 on every background in both themes
- The three steps at the top of the candidate sheet sit side by side in equal columns, with shorter words that fit one line, and stack on a phone
- The reason for an item that was not updated for a long time reads `Not updated in a long time (last updated <date>)`, without a label and a colon
- `followup.sh add` keeps the service name from the candidates with each record, and the follow-up page shows that name in the Service column, with the domain under it only when the name does not hold it. Records written before show their key as before
- `musubi.json` follows the `structure` and `look` formats, the `sheet` page type, and `verify` of page-design in the design-formats plugin through musubi, as optional follows. When page-design is installed, the agent reads them and runs page-design's verify on the candidate sheet and the follow-up page; when the `musubi` command is installed, it runs `musubi check` first. Without design-formats, the pages work as before
- The candidate sheet and the follow-up page have a Light and Dark switch next to the language switch. It follows the system setting until you choose, and both pages share your choice in the browser's local storage under `account-cleanup-theme`

## [0.3.0] - 2026-11-16

- The skill's instructions are shorter, so starting the skill reads less, and its rules on passwords, approval, and the browser are unchanged. An eval suite under `evals/` measures it with `claude plugin eval`, and every case kept its score
- The agent passes its descriptions of the candidates to `annotate.sh -` on standard input. Before, it first wrote them to a file in the data folder, which asked for one more approval and was refused where the agent may not write outside the project

## [0.2.1] - 2026-11-13

- The README's screenshot is the candidate sheet the scripts built from a sample list of real services, and its details panel shows a reason and a date
- Each IP address and local network name (`localhost`, `.local`, `.lan`, `.home.arpa`, and the like) is its own candidate marked as a development address. Before, two devices such as `192.168.1.1` and `10.0.1.1` became one candidate, `1.1`, that was treated as a web service and contacted at `https://1.1/`

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.1] - 2026-11-12

- Add an icon, used as the icon and the logo in the plugin directories

## [0.1.0] - 2026-11-12

First public release.

- Collects service names, URLs, and dates from 1Password, Bitwarden, and Chromium browsers without reading any passwords
- Tags likely-unused accounts with reasons and opens a candidate sheet where you mark each one OK or Keep
- Cancels subscriptions, removes payment methods, and deletes the accounts you approve, signing in from 1Password without showing credentials to the agent
- Drafts erasure requests under GDPR, CCPA, or Japan's APPI for services that cannot delete accounts
- Bundles the JustDeleteMe deletion directory
- The pages offer an English / 日本語 switch

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/account-cleanup--v0.3.0...HEAD
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/account-cleanup--v0.3.0
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/account-cleanup--v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/account-cleanup--v0.2.0
[0.1.1]: https://github.com/cardene777/agent-shuriken/releases/tag/account-cleanup--v0.1.1
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/account-cleanup--v0.1.0
