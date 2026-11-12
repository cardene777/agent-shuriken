# OSS Contribute

Send a fix to an outside open source project by that project's own rules, and only after you approve the exact draft.

English · [日本語](README.ja.md)

Sending a fix upstream takes more than the fix.
Each project has its own rules: whether an issue comes first, how branches and commits are written, whether commits need a sign-off, what the pull request template asks, which checks must pass, and what it allows from AI tools.
And whatever you send is public and cannot be taken back.
This plugin reads those rules, makes the fix in a clone, runs the project's checks inside a Docker container so the project's code never runs on your machine, and writes the issue or pull request in the project's language with a translation for you.
Nothing is sent until you approve that exact draft, and a draft that changed after your approval is not sent.

```
Read the rules ──> Fix in a clone ──> Run its checks ──> Show the draft ──> Send what you approved
 (agent)            (agent)            (Docker)           (agent)            (you approve, agent sends)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install oss-contribute@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add oss-contribute@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install oss-contribute@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/oss-contribute/skills/oss-contribute   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask to send a fix or a report to a project, for example "send this fix upstream to acme/shop" or "I found a bug in this library, let's open a pull request".
When the agent notices a bug in an outside project while doing something else, it tells you and starts only if you say yes; it never contributes on its own.
You can also call it: run `/oss-contribute:oss-contribute` in Claude Code, or type `$` and pick **OSS Contribute** in Codex.
In GitHub Copilot CLI, write `/oss-contribute` in your request, and in Gemini CLI, describe the task.

1. The agent clones the project into `~/.local/share/oss-contribute/clones/` and lists the files that hold its rules
2. The agent reads them, creates a branch named the project's way, makes the fix, and commits in the project's style
3. The agent runs the project's lint, format, and test commands inside a Docker container
4. The agent writes the issue or pull request in the project's language, with a translation for you, and shows you the draft: the title, the body, the commits, the diff, and anything that looks like a credential, a home folder path, or an email address
5. You approve that exact draft, and the agent sends it. For a pull request, it forks the project under your account when you have no fork, pushes the branch, and opens the pull request
6. Changes the maintainers ask for later go through a new draft and a new approval

The rules of a project look like this.

```text
Rules of acme/shop
  folder           ~/.local/share/oss-contribute/clones/acme/shop
  contributing     .github/CONTRIBUTING.md
  security         SECURITY.md
  code of conduct  none
  issue templates  none
  pr templates     .github/pull_request_template.md
  agent guidance   none
  checks           go.mod, .github/workflows/ci.yml
  sign-off         asked for
    .github/CONTRIBUTING.md:5  Sign off every commit with `git commit -s` (DCO).
  CLA              not mentioned
  AI policy        1 line
    .github/CONTRIBUTING.md:6  If you used AI tools, say so in the pull request description.

Check commands in the project's files
  .github/workflows/ci.yml:8  go-version: '1.24'
  .github/workflows/ci.yml:9  run: go mod download
  .github/workflows/ci.yml:10  run: go vet ./...
  .github/workflows/ci.yml:11  run: go test ./...
```

A draft of a pull request looks like this.

```text
Draft acme-shop-pr-1
  repository   acme/shop
  kind         pull request
  from         fix/readme-typo on your fork, which is created when sending if you have none
  into         main
  title        Fix the spelling of "library" in the README
  status       drafted, not approved
  fingerprint  670b63aadf45

----- what the project's files say about AI (read before approving) -----
  .github/CONTRIBUTING.md:6  If you used AI tools, say so in the pull request description.

----- body (sent) -----
## What changed

Fixes the spelling of "library" in the README.

## How it was tested

Ran `go vet ./...` and `go test ./...` in a `golang:1.24` container. Both passed.

This change was prepared with an AI coding agent and reviewed by me.

----- commits (1) -----
  10d9cff Fix the spelling of "library" in the README  (Ada Example <ada@example.com>)

----- diff (1 file, +1 -1) -----
diff --git a/README.md b/README.md
index b324362..a651e2f 100644
--- a/README.md
+++ b/README.md
@@ -1,3 +1,3 @@
 # Shop
 
-Shop is a small cart libary for Go.
+Shop is a small cart library for Go.

----- findings -----
  none
```

## What your approval covers

Your approval is recorded as a fingerprint of the repository, the kind of draft, the title, the body, the commits, the diff, and the target branch.
When any of them changes after you approve, sending refuses, and the agent shows you the new draft and asks again.
Right before sending, the plugin checks the target once more and stops with the reason when the project was archived or renamed, the target branch is gone, a pull request from the same branch or one of yours with the same title is already open, an issue changed state, or your fork's branch changed.
A draft is never sent twice.
The fingerprint makes sure that what is sent is what you were shown; it cannot tell who typed the yes, so the agent is told to approve only after your answer.

## Projects that restrict AI tools

Every issue and pull request body says in one line, in the project's language, that an AI tool was used.
When a project forbids AI-written contributions and also asks for a sign-off, the agent stops before drafting, because a sign-off states that you wrote the change or have the right to submit it.
When a project restricts AI tools without asking for a sign-off, the draft quotes the project's words and you confirm that you read them before anything is sent.

## Security problems

A vulnerability never goes to a public issue, pull request, comment, commit, or fork.
The plugin shows the project's security policy and whether GitHub's private vulnerability reporting is on, and the agent writes a report for you to send through that channel.
The plugin does not send security reports itself.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always |
| `git` | Always. To push to your fork, git needs an SSH key added to GitHub, or `gh auth setup-git` for HTTPS |
| `gh` | To send and to check the target before sending, signed in to GitHub with `gh auth login` |
| Docker | To run the project's checks. Without it the checks are not run, and the draft says so |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains every command, the fingerprint, the checks before sending, and the container.
In short:

- It reads the files of the project's clone, never following a symbolic link out of it, and the git data of the clone
- It runs `git` to clone the public project from GitHub and to work in the clone, `gh api` to read the project, your GitHub login, and the open issues and pull requests, and `docker` to run the project's checks in a container, which downloads the image and the project's dependencies
- It sends nothing of yours before you approve. After you approve a draft, it creates your fork if needed, pushes the branch, and sends the title, body, or comment to GitHub through your own `gh` sign-in, where they are public
- It keeps the clones, the drafts, your approvals, and the links of what was sent in `~/.local/share/oss-contribute/`, readable only by you, and a Docker cache volume per project, until you remove them with the clean step. It never touches your fork on GitHub

## License

[MIT](LICENSE)
