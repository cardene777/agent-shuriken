---
name: init-project
description: Sets up a project for local work. It tells what kind of project a folder is, picks a free local port that no other project set up with it uses, writes a Docker setup (Dockerfile, compose file, and a local override with the port), and links the project's env files to 1Password by writing op:// references, so no value passes through the agent. Every file is shown first and written only after the user approves, and existing files are kept unless the user names one to replace. Use when the user starts a new project, wants to add Docker to an existing one, or wants to move environment variables into 1Password.
---

# Init project

This skill prepares a project folder for local work in three parts, which the user can take together or one at a time.

| Part | What it adds |
|---|---|
| Port | A free local port for the dev server, which no other project set up with this skill gets |
| Docker | `Dockerfile`, `.dockerignore`, `docker-compose.yml`, and `docker-compose.override.yml`, which holds the local port and stays out of git |
| 1Password | One `<env file>.tpl` per env file, with `op://` references in place of the values, and the commands the user runs to put the values into 1Password |

Nothing is written until the user has seen every file and approved.
A file that already exists is kept unless the user asks to replace that file by name.

Talk to the user in the language they write in.
The commands and their output are the same in every language.

All commands live in `scripts/` next to this `SKILL.md`.
Below, `S` stands for the absolute path of that folder.
When running a command, put `S=<folder that contains this SKILL.md>/scripts` at the start of the same shell command.

This skill works in Claude Code, Codex, and other agents that read `SKILL.md`, such as GitHub Copilot CLI and Gemini CLI.
The commands keep their state in the home folder, check ports by listening on them for a moment, and connect to `127.0.0.1`, so request approval for them when a sandbox blocks them, as Codex can.

## Keep every value away from the agent

The commands read env files only to find the names before `=`, and print, keep, and send no part of a value.
Follow these rules for the whole session.

- Never open, print, or search env files (`.env`, `.env.local`, `.env.*`) with any tool. Use only the commands below. The `.tpl` files this skill writes hold only references and may be read
- Never run `op read`, `op inject`, `op run`, or `op item get` with `--reveal`, and never run the commands the plan prints for putting values into 1Password. The user runs them in their own terminal
- Never ask the user to paste a value into the chat. If they paste one anyway, tell them it is now in the conversation and recommend rotating that key

## 1. Pick the mode

| Mode | When | Parts |
|---|---|---|
| `new` | The user starts or sets up a project | The port, then Docker and 1Password when the user wants them |
| `add-docker` | The user wants Docker in an existing project | Docker, with its port |
| `add-1password` | The user wants the env files linked to 1Password | 1Password |

The user may name the mode, for example `/init-project:init-project add-docker`.
When the request does not make the mode clear, ask.

The project folder is the folder the user is working in, usually the root of the repository.
For another folder, add `--dir <folder>` to every command below.
In a monorepo, use the folder of the package that installs and runs on its own.

## 2. Look at the project

```bash
S=<skill folder>/scripts; python3 "$S/init_project.py" detect --dir <project folder>
```

It prints the kind of project and why, the runtime and package manager, the dev command, whether a Docker template fits, the Docker files that already exist, the env files with their number of names, whether `op` (the 1Password CLI) and `docker` are installed, and any port already assigned.
The first rule that matches decides the kind.

| Kind | When |
|---|---|
| `smart-contract` | `foundry.toml`, or a Hardhat config such as `hardhat.config.ts` |
| `cli` | `package.json` with a `bin` field, or `Cargo.toml` that builds a binary |
| `web-app` | `package.json` with a `dev` or `start` script, or Python dependencies on Django, FastAPI, Flask, or uvicorn |
| `library` | Any other `package.json`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, or `setup.py` |
| `unknown` | None of these files |

Docker templates exist for Node and Python web apps and for local chains with Foundry (anvil) and Hardhat.
Tell the user the kind and the reason in one sentence, and which parts can be set up.

## 3. Ask what to set up

In mode `new`, ask about each part that applies, in one round.

- Docker, when `detect` shows a template. Recommend it for web apps and local chains
- 1Password, when `detect` lists env files. When `op` is not installed, say that linking needs the 1Password CLI and leave this part out
- The vault, when 1Password is chosen: the name of the 1Password vault that will hold the values. The user can list their vaults with `op vault list` in their own terminal. The item is named after the folder unless the user wants another name
- The port: a free port from 3100 up is picked, skipping ports that common tools use such as 3000, 5173, 8000, and 8080. The user may ask for a port, or for a first port to try

In mode `add-docker`, no question is needed unless the user mentioned a port.
In mode `add-1password`, ask for the vault.

In Claude Code, use AskUserQuestion with one question per part.
In other agents, ask in the chat in one message.

## 4. Make the plan

```bash
S=<skill folder>/scripts; python3 "$S/init_project.py" plan --dir <project folder> <flags>
```

| Flag | Use |
|---|---|
| `--docker` | The Docker files and their local port |
| `--assign-port` | Only the local port, for a web app or local chain that will run without Docker |
| `--env --vault <vault>` | A `.tpl` file of references for each env file, and the commands that put the values into 1Password |
| `--item <name>` | The 1Password item, instead of the folder name |
| `--env-file <file>` | Link only this env file. Repeatable |
| `--port <n>` | Use this local port. It must be free and not assigned to another project |
| `--from <n>` | The first port to try when picking one (default 3100) |
| `--overwrite <file>` | Replace this existing Docker file. Use it only after the user asked to replace that file |
| `--service <name>`, `--container-port <n>` | For a compose file the project already has: the service that gets the local port, and the port it listens on inside its container |

| Mode | Flags |
|---|---|
| `new` | `--docker` when the user wants Docker, otherwise `--assign-port` for a web app or local chain, and `--env --vault <vault>` when the user wants 1Password |
| `add-docker` | `--docker` |
| `add-1password` | `--env --vault <vault>` |

The plan writes nothing into the project.
It prints a plan id and every change.

| Mark | Meaning |
|---|---|
| `[create]` | A new file, shown in full |
| `[overwrite]` | An existing file to replace, shown as a diff. Only with `--overwrite` |
| `[append]` | Lines to add at the end of an existing file, such as `.gitignore` or a `.tpl` file |
| `[skip]` | A file that is kept, with the reason |

Under `After writing` it prints how to start the project and, for 1Password, the commands for the user's terminal.
When an existing compose file has several services, the plan stops and names them; ask the user which one gets the port and pass `--service`.

## 5. Get approval

Show the user the plan: each new file under its path in a code block, the lines to add to existing files, the files that are kept and why, the port, and every note.
Then ask whether to write it, change something, or cancel.
In Claude Code, use AskUserQuestion; in other agents, ask in the chat.
Never write without a clear yes for this plan.

- To change something, run `plan` again with other flags. A new plan replaces the earlier one for the same folder
- To replace a file marked `[skip]`, run `plan` again with `--overwrite <file>` only when the user asked for that file, show the diff, and ask again. Env files are never replaced
- To cancel, run `python3 "$S/init_project.py" discard <plan id>`

## 6. Write

```bash
S=<skill folder>/scripts; python3 "$S/init_project.py" apply <plan id>
```

Right before writing, it checks each file again: a new file must still be missing, and a file to replace or extend must be unchanged since the plan.
A port that was picked must still be free and not assigned to another project.
Whatever changed is skipped with the reason, and the command exits 4; tell the user and offer to plan again.
The port is recorded in `~/.local/share/init-project/ports.json`, readable only by the user, so later projects get other ports.
When the portman plugin is installed, the port is registered in portman's registry with portman's own `add` command instead, and the plan skips every port portman holds for other folders, including the git worktrees of the same repository.

## 7. Check that it starts

After writing Docker files, ask whether to start the project now.
Only after a yes, run these in the project folder.

```bash
docker compose up -d --build
S=<skill folder>/scripts; python3 "$S/init_project.py" wait --port <port>
```

Building downloads the base image and installs the dependencies, which can take minutes.
`wait` exits 0 once the server answers with any HTTP status, and 1 after 30 seconds without an answer; then run `docker compose logs --tail 50` and explain what it shows.
This check runs without the 1Password values; if the app needs them to start, say so and leave starting with `op run` to the user.
Leave the containers running unless the user asks to stop them with `docker compose down`.

## 8. Put the values into 1Password

The user does this step in their own terminal; the agent only shows the commands.
Show the commands from `After writing` exactly as printed, and explain them.

- Run them in bash or zsh. They start with `cd` to the project folder, the `op item get` line creates the 1Password item when it is missing, and each line after it loads one env file in a subshell and passes its values to `op item edit`, printing nothing. The shell history keeps only the variable names
- `op` may ask the user to sign in or unlock 1Password
- Loading an env file runs it as shell code, like `source .env`. When a file is not valid shell, for example a value with spaces and no quotes, the user adds the fields in the 1Password app instead: in the item, one section per `.tpl` file, named as in the references, and one field per variable
- Then the user starts the app with `op run --env-file <file>.tpl -- <dev command>`, as the plan shows. `op run` hides the values in the output
- Once that works, the plain env files are no longer needed. The skill never deletes them; the user decides

When a note says an env file is committed to git, recommend rotating those keys, since the values are in the git history, and removing the file from git with `git rm --cached <file>`.
Run that only when the user asks.

## 9. Report

From the output of `apply`, tell the user these things.

- The project, its kind, and the local port
- Which files were written, kept, or skipped, and why
- How to start it, and what the user still does for 1Password

## When something fails

| Exit code | Meaning | What to do |
|---|---|---|
| 1 | Nothing found: no env file with variables, an unknown plan id, or a project folder that is gone | Explain, or run `plan` again |
| 2 | Bad input, such as a vault name with characters references cannot hold, `--overwrite` on an env file, or a compose file with several services and no `--service` | Fix the flags as the message says. A vault can be named by the ID that `op vault list` shows |
| 3 | `op` is not installed | Linking needs the 1Password CLI. The other parts still work |
| 4 | `apply` skipped items that changed after the plan | Tell the user which, and plan again |
| 5 | No Docker template for this kind of project | Say which templates exist. The port and 1Password parts still work |
| 6 | The port is in use or assigned to another project | Pick another port, or leave out `--port` to pick a free one |

## Other commands

- `python3 "$S/init_project.py" ports` lists the ports this skill assigned, with their folders. After the user removes a project, `ports --forget <folder>` frees its ports; ask before running it
- When the portman plugin is installed, its registry is the one record of ports: the plan reads it, uses the port portman holds for this folder, and `apply` registers new ports there. The script finds portman in the Claude Code and Codex plugin folders, or at `INIT_PROJECT_PORTMAN`
- When a plan notes ports recorded before portman was installed, `ports --move` shows the move into the portman registry, and `ports --move --confirm` does it and removes them from `ports.json`. Show the user the list and ask before running it with `--confirm`. A port portman gives to another project stays in `ports.json`, with the reason
- When the plan warns that it cannot read the portman registry, it picks from `ports.json` only. Tell the user, and suggest updating portman
