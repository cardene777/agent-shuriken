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
| convey | Ready to submit | Ready to upload, with its icon set the same way |
| design-formats | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| diagram-composer | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| diagram-explainer | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| doc-formats | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| docs-publish | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| evm-dev | Ready to submit | Ready to upload, with its icon set the same way |
| excalidraw-diagram | Ready to submit | Ready to upload, with its icon set the same way |
| feedback-loop | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| init-project | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| japanese-speaking | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| japanese-writing | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| learning-to-skill | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| machine-cleanup | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| portman | Ready to submit | Ready to upload, with its icon set the same way |
| repo-progress | Ready to submit | Ready to upload, with its icon set the same way |
| secure-dotfile | Ready to submit | Ready to upload, with its icon set the same way |
| session-handoff | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
| skill-tune | Ready to submit. Its name is made of generic words, so a version may be held for a reviewer | Ready to upload, with its icon set the same way |
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

| Question | account-cleanup | compare-report | convey | design-formats | diagram-composer | diagram-explainer | doc-formats | docs-publish | evm-dev | excalidraw-diagram | feedback-loop | init-project | japanese-speaking | japanese-writing | learning-to-skill | machine-cleanup | portman | repo-progress | secure-dotfile | session-handoff | skill-tune | techdebt |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Reads personal data | Service names, URLs, and dates from your password managers and browser, read on your machine. It never reads passwords | No. It reads public web pages about the candidates | The text you point to, read on your machine: the conversation, pasted text and files, issues and pull requests, and commits | The pages and documents you pass to `verify`, read on your machine | The deck and slide you point to, and the geometry manifest the agent writes, read on your machine | The code and documents you point to, read on your machine, and public pages about standards and products | No. It reads only the design and the sections file the agent passes, on your machine | No. It reads the files of the project you document on your machine, and its GitHub issues when you agree | The contracts, tests, and config files of the project you work in, the versions in its `foundry.toml` and `package.json` files, and the design file it writes, read on your machine. It never reads `.env` files or keys. It also reads its own items and, for out-of-date items, the public ERC, EIP, tool, and financial standard documents | The diagram spec the agent writes, a Mermaid or `.excalidraw` file you point to, and the code you ask for a diagram of, read on your machine | The files you corrected and the rules and cases kept for that repository, read on your machine. The words of your correction are read only to hash them | The project's manifests, Docker files, and `.gitignore`, and only the variable names in its env files, read on your machine. It never reads, prints, or keeps the values | No. It reads only the material and the script you point to | The text and files you give it, read on your machine | The instruction files and skills in your project, and with `--home` the ones in your agents' folders in your home folder, read on your machine | The sizes and dates of files and folders in your home folder and app folders, the contents of same-sized files of 10 MB or more to tell duplicates apart, and your processes with their commands and working folders, login items, and containers, read on your machine | The ports your programs listen on, with their process IDs, names, and working folders, and the names of your running containers, read on your machine. It reads a project's `.env.local` only inside the script and never shows lines other than its own | The git data of the clones under your project folders: commits, branches, worktrees, and which files have uncommitted changes, read on your machine. It never reads file contents | Variable names, file names, and line numbers in your shell startup files, `~/.npmrc`, `~/.aws/credentials`, `~/.netrc`, and the `.env` files of the folder it runs in, read on your machine. Values are read only inside the script and never shown to the agent | What you worked on in the current session, which the agent already has, and the project's branch and latest commit, read on your machine. Environment variables named like secrets are only compared to keep their values out, never shown or stored | The plugin folder you point to, its eval results, and the traces `claude plugin eval` keeps for each run, read on your machine | No. It reads the source files and git history of the folder you scan, on your machine |
| Stores personal data | Only on your machine, in `~/.local/share/account-cleanup/`, readable only by you | No. It stores the report in `~/.local/share/compare-report/`, readable only by you | No. It writes the message only to the file you name or to a temporary file it deletes | No. A page made from a template keeps only the chosen language and theme in your browser | No. The geometry manifest goes where you or the agent saves it | No. It writes the document and its JSON source to a folder in your project | No. The design goes where the following skill or you save it | No. It writes the pages and the translation map to the docs folder in your project | No. It writes only the contracts, tests, or design document you ask for into your project | No. It writes the `.excalidraw` file, the SVG, and the PNG to a folder you choose, such as `docs/images/` in your project | Only a hash of your correction, what was corrected, the review criteria, the reviews, and file hashes, in `~/.local/share/feedback-loop/`, readable only by you, or in a folder of the project you choose | Only the local ports it assigned with their project folders, and plans waiting for approval, in `~/.local/share/init-project/`, readable only by you. The files it writes go into your project after you approve them | No | No. It keeps no files of its own | No. It writes only the rules you approve into the instruction file you chose, and keeps no files of its own | Only on your machine, in `~/.local/share/machine-cleanup/`, readable only by you: the last scan, with paths and process commands whose secret-looking values are hidden, and what `restore` needs | Only project names, ports, and project folders, in `~/.local/share/portman/`, readable only by you. After you approve, it writes port lines to a project's `.env.local` and Compose override | Only the root folders you save, in `~/.local/share/repo-progress/`, readable only by you | Only the values you pick, in your macOS Keychain, your Linux secret service, your pass password store, or your 1Password vault. It keeps no files of its own | Only on your machine: one snapshot per project in `~/.local/share/session-handoff/`, readable only by you | No. It stores copies of the plugin, their eval results, and run logs in `~/.local/share/skill-tune/`, readable only by you | No. It stores the measures, the agent's notes, and the report in `~/.local/share/techdebt/`, readable only by you |
| Sends data elsewhere | A `HEAD` request to each candidate's domain, and the sign-in and deletion steps on services you approve. Web searches use only service names and domains | Web searches with only the topic and the names of candidates and vendors | Nothing. `copy` hands the message to the clipboard tool on your machine, and `gh` reads issues and pull requests from GitHub with your own sign-in only when you point to them | Nothing | Nothing | Web searches with only the names of the topic, standards, products, and vendors | Nothing | Only when you agree to use your issues for the FAQ: the repository's name, sent to GitHub by `gh` with your own sign-in | Web searches and page loads for out-of-date items, with only a standard's number or name, or a tool's name and version | Nothing. The browser that makes the PNG opens only the local SVG and is blocked from resolving any host name | Nothing | Nothing. The commands you run in your own terminal send your values to 1Password with your own sign-in | No. It connects to nothing | Nothing. On first use, `uv` downloads `sudachipy` and its dictionary from the Python Package Index, asking only for the package names | Nothing | Nothing. The page is served only on `127.0.0.1` | Nothing | The names of your GitHub repositories, sent to GitHub by `gh` with your own sign-in to list open issues and pull requests | Nothing itself. When you pick 1Password, `op` stores the values you pick in your own 1Password account | Nothing | Nothing itself. `claude plugin eval`, which runs only after you agree on a cost ceiling, sends each case's prompt and what the agent reads during the run to Anthropic's model through your own Claude Code sign-in, and the cost is billed to your account | Nothing |
| Keeps data for | Until you finish. The candidate list, the sheet, and the browser profile are deleted then | Until you delete the report's folder. The browser profile used to print the PDF is deleted right after printing | It keeps nothing. The temporary message file is deleted when it finishes | It keeps nothing | It keeps nothing | Until you delete the document's folder. The browser profile used to measure the layout or print the PDF is deleted right after | It keeps nothing | Until you delete the pages from your project. It keeps nothing outside the project | It keeps nothing. The contracts, tests, and designs it writes stay in your project until you change them | Until you delete the diagram's files. The browser profile used to make the PNG is deleted right after | Until you delete the records folder | The ports until you remove them with `ports --forget` or delete the file. A plan until it is applied or discarded, and at most a day | Nothing is kept | It keeps nothing. Intermediate files are deleted when it finishes, and the packages stay in uv's cache until you clear it | It keeps nothing. The rules it writes stay in your instruction files until you change them | Until the next scan or `finish`. Restore records stay until you restore the item | Until you delete the registry. The port lines in your projects stay until you remove them | Until you delete the saved roots file | In the Keychain, the secret service, pass, or 1Password until you delete the item. Nothing else is kept | Until the next handoff for the project replaces the snapshot, you ask to delete it, or 7 days after it was saved | Until `clean` removes the copies, their results, and the folders `claude plugin eval` kept for them, which the skill runs when it finishes | Until you delete the plugin's folder |
| Intended for people under 18 | No | No | No | No | No | No | No | No | No | No | No | No | No | No | No | No | No | No | No | No | No | No |

Each plugin's `docs/how-it-works.md` has the details behind these answers.
