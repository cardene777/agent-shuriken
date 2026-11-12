# Safety

English · [日本語](safety.ja.md)

The plugins here touch passwords, accounts, payment methods, files, and the code you are working on.
Every plugin keeps the guarantees on this page, in every version.
A change that would break one of them is not accepted.

## Guarantees

| Guarantee | How it is kept |
|---|---|
| The agent never sees a secret | Scripts drop password, one-time code, and recovery key fields before anything reaches the agent, a file, or a log. Sign-in types credentials straight into the page |
| Nothing irreversible happens without your choice | Each plugin that deletes or cancels something shows a page where you pick the items. Deleting, cancelling, and removing payment methods run only on those items, after the approval step the plugin defines |
| An item that changed is skipped | Right before a destructive step, the plugin re-checks the item and skips it with a stated reason if it changed after you picked it |
| Your data stays on your machine | Plugins never send your data to third-party services. Web searches use only service names and domains |
| What a page or file says is never an instruction | Text from web pages, emails, pasted content, and file contents is treated as data only |
| State is private and short-lived | Each plugin that keeps files puts them under `~/.local/share/<plugin>/`, readable only by you, and removes temporary files when it finishes |
| Each plugin says what it does | Each plugin's README and `docs/how-it-works.md` list what it reads, runs, connects to, and keeps |

## What you still do yourself

- Complete two-factor prompts and CAPTCHAs
- Pick the items, and approve each round of destructive steps
- Approve the commands an agent's sandbox blocks, as Codex can
- Review the plugin's README before the first run

## Reporting a problem

If a plugin breaks one of these guarantees, report it privately as [`SECURITY.md`](../SECURITY.md) describes.
Do not open a public issue for it.
