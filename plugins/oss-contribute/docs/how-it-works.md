# How OSS Contribute works

English · [日本語](how-it-works.ja.md)

This page explains each command, what the plugin reads, runs, connects to, and keeps, how a draft is fingerprinted, and what is checked right before sending.
Everything here is done by `skills/oss-contribute/scripts/oss_contribute.py`, which uses only the Python standard library, `git`, `gh`, and `docker`.

## Commands

| Command | What it does | What it connects to |
|---|---|---|
| `start --repo <owner/name> [--branch <branch>]` | Clones the project, or fetches it when the clone exists, and creates or switches to the branch | GitHub, through `git clone` and `git fetch` of the public project |
| `rules --repo <owner/name> [--json]` | Lists the files that hold the project's rules and the lines that matter | Nothing |
| `security --repo <owner/name>` | Names the security policy file in the clone and says whether private vulnerability reporting is on | GitHub, through `gh api repos/<owner>/<name>/private-vulnerability-reporting` |
| `check --repo <owner/name> --image <image> [--deps <command>] --test <command>` | Runs the project's commands in Docker containers | Docker, which downloads the image when it is missing; the dependency phase may use the network |
| `draft --repo <owner/name> --kind issue\|pr\|comment\|push ...` | Records a draft and prints it | For a comment only, GitHub, through `gh api repos/<owner>/<name>/issues/<number>` |
| `show <draft>` | Prints a draft as it is now | Nothing |
| `approve <draft> --fingerprint <code> [--accept-findings]` | Records the approval of the draft as it is now | Nothing |
| `send <draft>` | Checks the target again and sends the approved draft | GitHub, through `gh api` and `git push` |
| `list` | Lists the drafts and whether each was sent | Nothing |
| `clean --repo <owner/name> [--force]` | Removes the project's clone, drafts, and Docker cache volume | Docker |

## Where the project comes from

`start` clones `https://github.com/<owner>/<name>.git` with `git clone --origin upstream`, so the project's remote is named `upstream` and the clone has no other remote until a pull request is sent.
The clone lives in `clones/<owner>/<name>` inside the plugin's folder, with the names in lower case.
Every command refuses a clone folder that is a symbolic link or resolves outside the plugin's folder, and `start` refuses an existing clone whose `upstream` points somewhere else.
A new branch is created from `upstream/<default branch>` without tracking it.

## Reading the project's rules

`rules` looks at the files in the project's root, `.github/`, `docs/`, `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE/`, `.github/workflows/`, and `.circleci/`.
It never reads a file that is a symbolic link, or that resolves outside the clone, and lists such files as not read.
It reads at most 1 MB of each file, and prints lines without terminal control characters, cut at 160 characters.

| Item | How it is found |
|---|---|
| Contributing guide, security policy, code of conduct, templates | By file name, in any letter case, with no extension or `.md`, `.rst`, `.txt`, `.adoc`, or `.markdown`. Every file in `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE/` counts as a template |
| Agent guidance | `AGENTS.md`, `CLAUDE.md`, and `copilot-instructions.md`, listed only |
| Sign-off | A `DCO`, `DCO.md`, `DCO.txt`, or `.github/dco.yml` file, or a line with `Signed-off-by`, `Developer Certificate of Origin`, `DCO`, `git commit -s`, or `--signoff` in the contributing guide or the pull request templates |
| CLA | A line with `CLA`, `Contributor License Agreement`, or `cla-assistant` in those files, or a workflow named after `cla` |
| AI policy | Up to 20 lines with `AI`, `LLM`, `ChatGPT`, `Copilot`, `Claude`, or `Gemini` as a word, or `generative`, `machine-generated`, `large language model`, `artificial intelligence`, or `vibe coding`, in the contributing guide, code of conduct, templates, and AI policy files |
| Check commands | `run:` lines, including multi-line blocks, and version keys such as `node-version` in the YAML check files, such as workflows; the `scripts` of `package.json`; and the `test`, `check`, `lint`, `fmt`, `format`, `ci`, `build`, and `typecheck` targets of a `Makefile`, `GNUmakefile`, or `justfile` |

The script only finds these lines.
The agent reads the files and decides what the rules ask.

## Running the checks

`check` runs up to two containers from the image you name, one after the other.

| Setting | Value |
|---|---|
| Network | `bridge` for the dependency phase, `none` for the check phase |
| The clone | Mounted read-only at `/src` and copied into a work volume at `/work`, where the commands run |
| Cache | A volume named `oss-contribute-cache-<owner>-<name>` at `/cache`, kept for the next run of the same project |
| Environment | Only the cache locations: `XDG_CACHE_HOME`, `npm_config_cache`, `npm_config_store_dir`, `YARN_CACHE_FOLDER`, `PIP_CACHE_DIR`, `UV_CACHE_DIR`, `GOMODCACHE`, `GOCACHE`, and `CARGO_HOME` |
| Privileges | `--security-opt no-new-privileges`, with `/bin/sh` as the entry point and `--rm` |
| Not passed | Your environment variables, your SSH agent, your `gh` sign-in, your home folder, and the Docker socket |

The work volume is created for each run and removed when the run ends, even when a phase fails.
When the dependency phase fails, the check phase is not run.
The image name must start with a letter or digit and hold only letters, digits, and `._/:@-`, so it can never be read as a Docker option.
When `docker info` fails, nothing is run and the command exits with code 3.

## Drafts

Each draft is a folder `drafts/<owner>-<name>-<kind>-<n>/` with these files.

| File | Holds |
|---|---|
| `draft.json` | The repository, the kind, the branch and target branch, the issue number, and the fingerprint at the time of the draft |
| `title.txt`, `body.md` | What is sent |
| `translation.md` | The translation for you. It is never sent and is not part of the fingerprint |
| `diff.patch` | The diff for reading, rewritten by `show`. The fingerprint is computed from the commits, not from this file |
| `approval.json` | The approved fingerprint and the parts it was made from |
| `sent.json` | The link of what was sent and when |

A title is one line of at most 256 characters, and a body at most 65,536 characters, the limit on GitHub.

| Kind | What the draft holds |
|---|---|
| `issue` | A title and a body |
| `pr` | A title, a body, and the commits from where the clone's current branch leaves `upstream/<target branch>` to its last commit. The clone must have no uncommitted changes to tracked files and must not be on the target branch |
| `comment` | A body and an issue or pull request number. The draft reads the issue through `gh`, refuses a locked one, and records its state |
| `push` | The commits added since the branch was last pushed to your fork. When the branch was rewritten, the draft says it replaces the branch, and its diff starts from `upstream/<target branch>` |

## Findings

The draft looks for these in the title, the body, the lines the diff adds, and the commit messages.

| Finding | What it looks for |
|---|---|
| A credential | The shapes of GitHub tokens, AWS access keys, private keys, OpenAI and Anthropic keys, Slack tokens, Google API keys, Stripe live keys, and npm tokens |
| A home folder path | `/Users/<name>/`, `/home/<name>/`, or `C:\Users\<name>`, except common placeholder names such as `runner` and `user` |
| An email address | Any address outside `example.com`, `example.org`, `example.net`, and `users.noreply.github.com`. Not looked for in commit messages, whose sign-off lines hold addresses |
| A `Co-authored-by` line | In a commit message, because a CLA check asks every co-author to sign |
| A missing sign-off | A commit without a `Signed-off-by` line when the project asks for one |

Findings name the place and the kind, never the value.
Anything shaped like a credential is shown as `[hidden: <kind>]` in the printed title, body, commits, and diff.
`approve` refuses a draft with findings unless `--accept-findings` is given.

## The fingerprint

The fingerprint is the SHA-256 of a JSON object with these parts: a format version, the repository in lower case, the kind, the issue number, the target branch, the branch, the last commit, the commit the change starts from, the commit last pushed to your fork, whether the push replaces the branch, and the SHA-256 of the title, of the body, and of the binary diff.
It is computed from the draft's files and from the clone's git data, never from `diff.patch`.
The code shown to you is its first 12 hexadecimal characters.

`approve` computes the fingerprint again and refuses when the code does not match, so an approval always applies to the draft as you saw it.
`send` computes it again and refuses when it differs from the approved one, naming what changed: the title, the body, the commits, the diff, the target branch, and so on.
The approval cannot tell who answered yes; the skill tells the agent to approve only after your answer.

## Checks right before sending

| Kind | What `send` checks first |
|---|---|
| Every kind | The draft was approved and not sent yet, its fingerprint matches, and the project can be read on GitHub under the same name and is not archived |
| `issue` | The project has issues turned on, and none of your first 100 open issues there has the same title |
| `pr` | `upstream` still has the target branch (`git ls-remote`), no open pull request comes from `<your login>:<branch>`, and none of the first 100 open pull requests is yours with the same title. After the fork is found or created, the fork must have no branch of that name with other commits |
| `comment` | The issue or pull request exists, is not locked, and is in the same state, open or closed, as when drafted |
| `push` | The pull request from the branch is still open, and the branch on your fork is still at the commit the draft started from |

When a check fails, nothing is sent and the reason is printed.

## What sending does

| Kind | What runs |
|---|---|
| `issue` | `gh api -X POST repos/<owner>/<name>/issues` with the title and body |
| `pr` | `gh api -X POST repos/<owner>/<name>/forks`, which returns your existing fork or creates one; `gh config get git_protocol` to pick the fork's SSH or HTTPS address; `git remote add fork` (or `set-url`); a wait of up to about 30 seconds until the fork answers `git ls-remote`; `git push fork <commit>:refs/heads/<branch>`; and `gh api -X POST repos/<owner>/<name>/pulls` with the title, body, `<fork owner>:<branch>`, the target branch, and `maintainer_can_modify` set to true |
| `comment` | `gh api -X POST repos/<owner>/<name>/issues/<number>/comments` with the body |
| `push` | `git push fork <commit>:refs/heads/<branch>`, with `--force-with-lease` against the last pushed commit when it replaces the branch |

The commit pushed is the approved commit itself, not whatever the branch points at.
After sending, `sent.json` records the link, and the draft is never sent again.
When the branch was pushed but GitHub did not open the pull request, running `send` again skips the push and opens it.

## What it keeps

| What | Where | Until |
|---|---|---|
| The clones | `~/.local/share/oss-contribute/clones/<owner>/<name>`, or under `OSS_CONTRIBUTE_HOME` when set | You run `clean` for the project |
| Drafts, approvals, and links of what was sent | `~/.local/share/oss-contribute/drafts/<id>/` | You run `clean` for the project |
| The dependency cache | The Docker volume `oss-contribute-cache-<owner>-<name>` | You run `clean` for the project |

The plugin's folders are created with mode 700 and its files with mode 600, so only you can read them.
`clean` refuses while the clone has uncommitted changes or untracked files, or commits that are on no remote, and lists them; `--force` removes the clone anyway.
It never touches your fork on GitHub.

## What it never does

- Run the project's code outside a container
- Send anything before you approve it, send a draft that changed after the approval, or send a draft twice
- Send a security report, or put a vulnerability in a public issue, pull request, or fork
- Read a file through a symbolic link that leaves the clone
- Pass your environment variables, SSH agent, `gh` sign-in, home folder, or the Docker socket into a container
- Delete your fork, close or edit an issue or pull request, or answer a review

## Environment variables

| Variable | Use |
|---|---|
| `OSS_CONTRIBUTE_HOME` | Where the clones and drafts are kept |
| `OSS_CONTRIBUTE_GH` | A command used instead of `gh`, for tests |
| `OSS_CONTRIBUTE_DOCKER` | A command used instead of `docker`, for tests |
| `OSS_CONTRIBUTE_GIT_BASE` | An address used instead of `https://github.com` for cloning, for tests |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | Refused or failed; the reason is printed |
| 2 | Wrong arguments, an unknown draft, or no clone |
| 3 | Docker is not running, so `check` ran nothing |
