# Publishing

English · [日本語](publishing.ja.md)

Anyone can install the plugins from this repository's marketplace, as [Getting started](getting-started.md) shows.
This page covers listing a plugin in the official directories as well, so people can find it inside Claude and inside ChatGPT and Codex.
Each directory takes one plugin folder at a time, and a maintainer submits it from their own account.

## Where each plugin stands

| Plugin | Anthropic's directory | OpenAI's directory |
|---|---|---|
| account-cleanup | Ready to submit. `skills/account-cleanup/data/sites.json` is over 256 KiB, so each version is held for a reviewer before it goes live | Ready to upload. The icon in `assets/icon.svg` is both `interface.composerIcon` and `interface.logo` |
| compare-report | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| diagram-explainer | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| docs-publish | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| feedback-loop | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| learning-to-skill | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| repo-progress | Ready to submit | Ready to upload, with its icon set the same way |
| secure-dotfile | Ready to submit | Ready to upload, with its icon set the same way |
| session-handoff | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| techdebt | Ready to submit | Ready to upload, with its icon set the same way |

Names made only of generic words can also be held for a reviewer in Anthropic's directory.

## Anthropic's directory

Listed plugins can be added from claude.ai and used in chat, Cowork, and Claude Code.

What you need:

- A paid Claude plan with a role that can submit to the directory
- Your GitHub account connected on claude.ai, with push access to this repository

Steps:

1. Run `claude plugin validate plugins/<name>` and `bash scripts/check.sh`, and fix what they report
2. Open the developer portal at `claude.ai/directory/manage`, select **Submit new**, then **Plugin bundle**
3. On **Source**, enter `cardene777/agent-shuriken` as the repository, `plugins/<name>` as the plugin path, and `release/<name>` as the branch to track
4. Select **Validate**, and fix every finding marked **Blocking**
5. Check **Listing details**, which come from `.claude-plugin/plugin.json` and `README.md`
6. Answer the **Data handling** questions with the table below, complete **Compliance**, and select **Submit for review**
7. When the version passes, select **Publish**

`scripts/release.sh` moves `release/<name>` to each new plugin release, so the directory picks up a release without another visit to the portal.
Changes merged to `main` but not yet released do not reach the directory.

## OpenAI's directory

Listed plugins appear in the directory shared by ChatGPT and Codex.

What you need:

- A verified developer or business identity in the OpenAI Platform organization you submit from
- Organization owner, or the **Apps Management Write** permission
- The plugin zip from the plugin's GitHub release, `<name>-X.Y.Z-plugin.zip`

Steps:

1. Download the plugin zip from the plugin's newest GitHub release
2. Open **Plugins** in the OpenAI Platform and select **Upload new or existing plugin**
3. Choose your verified developer identity, select **Upload plugin**, and upload the plugin zip
4. In **Metadata & Skills**, wait for the checks and the skill scans, and fix any **Issues** by uploading a corrected zip
5. Select the draft, choose **Submit for review**, and complete the policy attestations
6. After approval, open the approved version and select **Publish plugin**

To update a listed plugin, upload the plugin zip of the new release and submit it for review again.
The listing text comes from `interface` in `.codex-plugin/plugin.json`, where `displayName` and `shortDescription` are limited to 30 characters.

## Answers to the data handling questions

| Question | account-cleanup | compare-report | diagram-explainer | docs-publish | feedback-loop | learning-to-skill | repo-progress | secure-dotfile | session-handoff | techdebt |
|---|---|---|---|---|---|---|---|---|---|---|
| Reads personal data | Service names, URLs, and dates from your password managers and browser, read on your machine. It never reads passwords | No. It reads public web pages about the candidates | The code and documents you point to, read on your machine, and public pages about standards and products | No. It reads the files of the project you document on your machine, and its GitHub issues when you agree | The files you corrected and the rules and cases kept for that repository, read on your machine. The words of your correction are read only to hash them | The instruction files and skills in your project, and with `--home` the ones in your agents' folders in your home folder, read on your machine | The git data of the clones under your project folders: commits, branches, worktrees, and which files have uncommitted changes, read on your machine. It never reads file contents | Variable names, file names, and line numbers in your shell startup files, read on your machine. Values are read only inside the script and never shown to the agent | What you worked on in the current session, which the agent already has, and the project's branch and latest commit, read on your machine. Environment variables named like secrets are only compared to keep their values out, never shown or stored | No. It reads the source files and git history of the folder you scan, on your machine |
| Stores personal data | Only on your machine, in `~/.local/share/account-cleanup/`, readable only by you | No. It stores the report in `~/.local/share/compare-report/`, readable only by you | No. It writes the document and its JSON source to a folder in your project | No. It writes the pages and the translation map to the docs folder in your project | Only a hash of your correction, what was corrected, the review criteria, the reviews, and file hashes, in `~/.local/share/feedback-loop/`, readable only by you, or in a folder of the project you choose | No. It writes only the rules you approve into the instruction file you chose, and keeps no files of its own | Only the root folders you save, in `~/.local/share/repo-progress/`, readable only by you | Only the values you pick, in your macOS Keychain. It keeps no files of its own | Only on your machine: one snapshot per project in `~/.local/share/session-handoff/`, readable only by you | No. It stores the measures, the agent's notes, and the report in `~/.local/share/techdebt/`, readable only by you |
| Sends data elsewhere | A `HEAD` request to each candidate's domain, and the sign-in and deletion steps on services you approve. Web searches use only service names and domains | Web searches with only the topic and the names of candidates and vendors | Web searches with only the names of the topic, standards, products, and vendors | Only when you agree to use your issues for the FAQ: the repository's name, sent to GitHub by `gh` with your own sign-in | Nothing | Nothing | The names of your GitHub repositories, sent to GitHub by `gh` with your own sign-in to list open issues and pull requests | Nothing | Nothing | Nothing |
| Keeps data for | Until you finish. The candidate list, the sheet, and the browser profile are deleted then | Until you delete the report's folder. The browser profile used to print the PDF is deleted right after printing | Until you delete the document's folder. The browser profile used to measure the layout or print the PDF is deleted right after | Until you delete the pages from your project. It keeps nothing outside the project | Until you delete the records folder | It keeps nothing. The rules it writes stay in your instruction files until you change them | Until you delete the saved roots file | In the Keychain until you delete the item. Nothing else is kept | Until the next handoff for the project replaces the snapshot, you ask to delete it, or 7 days after it was saved | Until you delete the plugin's folder |
| Intended for people under 18 | No | No | No | No | No | No | No | No | No | No |

Each plugin's `docs/how-it-works.md` has the details behind these answers.
