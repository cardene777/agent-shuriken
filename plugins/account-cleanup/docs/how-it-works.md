# How Account Cleanup works

English · [日本語](how-it-works.ja.md)

This page lists what the plugin reads, what it runs, where it connects, and what it keeps, so you can judge it before you run it.

## The steps

| Step | Who | What happens |
|---|---|---|
| Collect | Agent | Scripts read service names, URLs, and dates from the sources you chose and merge them into one candidate list |
| Explain | Agent | Scripts tag likely-unused accounts with reasons, and the agent adds a one-line description of each site |
| Choose | You | You mark each account OK or Keep on the candidate sheet and paste the copied text into the chat |
| Cancel and delete | Agent and you | The agent signs in, cancels paid plans, removes payment methods, and deletes each OK account. You complete two-factor prompts and CAPTCHAs |
| Tidy up | Agent | The agent moves the password manager items of deleted accounts somewhere they can be restored |

## How passwords stay unread

| Source | What is read | What is never read |
|---|---|---|
| 1Password | During collection, the names, URLs, and modification dates returned by `op item list` | Collection never calls `op item get`. At sign-in, `browser.sh login` reads the item and types it straight into the page's fields, never passing it to the agent or a file |
| Bitwarden | Names, URLs, and modification dates from `bw list items` | Passwords, usernames, and notes are discarded inside the script and never reach a file or the agent |
| Chrome and Chromium browsers | `origin_url` and dates from a copy of the saved-password database | The password column is never selected. The copy is deleted after reading |
| Google, Apple, and GitHub sign-ins, and Gmail | Only which page to open and what to search for | The agent never sees the screens or the emails |

Credentials are filled in only when the open page's domain matches the domain of the 1Password item's URL.
For items without a URL, they are filled in only on the official domain you looked up and passed with `--site`.
Field values are stripped from every page snapshot the agent reads.
The browser that the agent drives has password saving turned off.

## Reasons an account is listed

| Reason | Meaning |
|---|---|
| Not updated in a long time | The item was last updated more than 730 days ago. Set `ACCOUNT_CLEANUP_STALE_DAYS` to change the number of days |
| Site is gone | The site's domain no longer resolves, so the service has likely shut down |
| Development address | The URL is `localhost`, an IP address, a `.local` name, or similar, so it is not a web service account |
| Browser extension | The entry belongs to a browser extension, often a crypto wallet, not a website |
| Broken URL | The item's URL is broken, so the site cannot be identified |

Development addresses and items without a URL are never contacted.

## Where it connects

| Destination | Why | What is sent |
|---|---|---|
| Each candidate's domain | Checks whether the site still exists | A `HEAD` request to `https://<domain>/`, with no cookies or personal data |
| The npm registry | Installs `playwright-core` on first use | A normal package download |
| The Playwright download servers | Installs Chromium on first use | A normal browser download |
| The services you approved | Signs in, cancels, removes payment methods, and deletes the account | What you would send yourself in the browser |
| Your agent's web search | Finds the deletion page of a service missing from the bundled directory | The service name and domain only |

It sends nothing else, and it never sends your candidate list anywhere.

## What it keeps

Everything lives in `~/.local/share/account-cleanup/`, or in `ACCOUNT_CLEANUP_HOME` when it is set, with permissions only you can read.

| File | Kept after you finish |
|---|---|
| Candidate list, candidate sheet, saved region | No |
| Browser profile with the sites still signed in | No |
| Deletion pages the agent found (`additions.json`) | Yes, they hold no personal data and save searching next time |
| Follow-up list (`followups.tsv`) | Yes, until you finish the follow-ups such as erasure requests |
| Playwright and Chromium (`node/`) | Yes, so the next run starts faster. Delete the folder to remove them |

## What it never does

- Press the final delete or cancel button before you approve the round
- Delete an account you did not mark OK
- Delete a password manager item permanently. Items go to the 1Password archive or the Bitwarden trash
- Follow instructions written on a web page, in an email, or in pasted text
