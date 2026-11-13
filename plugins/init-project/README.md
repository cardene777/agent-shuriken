# Init Project

Set up a project for local work: a free local port, a Docker setup, and env files linked to 1Password, with every file shown to you before it is written.

English · [日本語](README.ja.md)

Starting work on a project means the same chores every time.
You pick a port that does not clash with your other projects, write a Dockerfile and a compose file, keep the local parts out of git, and keep real keys out of plain `.env` files.
This plugin does those chores in three parts you can take together or one at a time.
It shows every file it would write, writes only after you approve, and keeps any file that already exists unless you name it to replace.
Your secret values never pass through the agent: it writes `op://` references, and you store the values with commands you run in your own terminal.

```
Look at the project ──> Ask what to set up ──> Show the plan ──> Write after approval ──> Store the values in 1Password
 (agent)                 (agent and you)         (agent)           (agent)                  (you, in your terminal)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install init-project@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add init-project@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install init-project@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/init-project/skills/init-project   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask to set up a project, for example "set up this project with Docker", "add Docker to this repo", or "move my .env into 1Password".
You can also call it: run `/init-project:init-project` in Claude Code, or type `$` and pick **Init Project** in Codex.
In GitHub Copilot CLI, write `/init-project` in your request, and in Gemini CLI, describe the task.

| Mode | For | Parts |
|---|---|---|
| `new` | A project you are setting up | The port, then Docker and 1Password if you want them |
| `add-docker` | Adding Docker to an existing project | Docker, with its port |
| `add-1password` | Linking the env files to 1Password | 1Password |

1. The agent looks at the project: what kind it is, its package manager, its Docker files, and its env files, reading only the variable names in env files
2. The agent asks which parts you want, and for 1Password, which vault holds the values
3. The agent shows the plan: every new file in full, the lines added to existing files, the files kept and why, and the local port
4. After you approve, the agent writes the files, checking each one and the port again right before writing
5. For Docker, the agent offers to start the project and checks that it answers
6. For 1Password, you run the printed commands in your own terminal to store the values, then start the app with `op run`

The plan for a Next.js project with pnpm, one `.env` file, and a `.gitignore` that ignores `.env*`, as the one Next.js creates does, looks like this.

```text
Plan 2760c3b6 for ~/projects/shop
  project  shop, web-app (next, pnpm)
  port     3100 for the app service (free)
  1Password vault Personal, item shop

[create] Dockerfile
    # Development image for shop, written by init-project.
    FROM node:24-alpine
    WORKDIR /app
    RUN npm install -g pnpm@9.12.0
    COPY . .
    RUN pnpm install
    EXPOSE 3000
    CMD ["pnpm", "run", "dev"]

[create] .dockerignore
    # Files kept out of the Docker build, written by init-project.
    .git
    .env
    .env.*
    *.log
    .DS_Store
    node_modules/
    dist/
    .turbo/
    .next/
    out/

[create] docker-compose.yml
    # Development services for shop, written by init-project.
    # The local port is set in docker-compose.override.yml, which stays out of git.
    services:
      app:
        build: .
        volumes:
          - .:/app
          - /app/node_modules
        environment:
          - NODE_ENV=development
          - DATABASE_URL
          - STRIPE_SECRET_KEY
          - NEXT_PUBLIC_SITE_URL

[create] docker-compose.override.yml
    # Local port for this machine, written by init-project. Keep it out of git.
    services:
      app:
        ports:
          - "127.0.0.1:3100:3000"

[create] .env.tpl
    # 1Password references for .env, written by init-project.
    # It holds no values, so it can be committed. Start the app with:
    #   op run --env-file .env.tpl -- pnpm run dev
    DATABASE_URL=op://Personal/shop/env/DATABASE_URL
    STRIPE_SECRET_KEY=op://Personal/shop/env/STRIPE_SECRET_KEY
    NEXT_PUBLIC_SITE_URL=op://Personal/shop/env/NEXT_PUBLIC_SITE_URL

[append] .gitignore
    + # Added by init-project
    + !.env.tpl
    + docker-compose.override.yml

After writing:
  Start it with: docker compose up --build
  Then open: http://localhost:3100
  Put the values into 1Password from your own terminal (bash or zsh). These commands read each env file in a subshell and print nothing:
    cd ~/projects/shop
    op item get shop --vault Personal >/dev/null 2>&1 || op item create --vault Personal --category 'Secure Note' --title shop --tags env >/dev/null
    ( set -a; . ./.env; set +a; op item edit shop --vault Personal "env.DATABASE_URL[concealed]=${DATABASE_URL-}" "env.STRIPE_SECRET_KEY[concealed]=${STRIPE_SECRET_KEY-}" "env.NEXT_PUBLIC_SITE_URL[text]=${NEXT_PUBLIC_SITE_URL-}" >/dev/null )
  Then start the app with: op run --env-file .env.tpl -- pnpm run dev
  Or in Docker: op run --env-file .env.tpl -- docker compose up
  Once that works, the plain env files are no longer needed. They still hold the values until you delete them.

Nothing has been written. To write these files, run: init_project.py apply 2760c3b6
```

## Ports

The plugin picks a port from 3100 up that nothing on your machine is listening on, that common tools such as 3000, 5173, 8000, and 8080 are not using, and that no other project set up with this plugin has.
It records the port so the next project gets another one, and reuses it when you run the plugin on the same project again.
You can ask for a port or for a first port to try.
The port is bound to `127.0.0.1` only, so other machines on your network cannot reach the dev server.
The record covers projects set up with this plugin; the portman plugin keeps a registry of ports across all your projects.

## Docker templates

| Project | What the files run | Port inside the container |
|---|---|---|
| Node web app (Next.js, Nuxt, Astro, Vite, or another app with a `dev` or `start` script) | The `dev` or `start` script with npm, pnpm, yarn, or bun | 3000, Astro 4321, Vite 5173 |
| Python web app (FastAPI, Flask, or Django) | uvicorn, `flask run`, or `manage.py runserver`, reloading on changes | 8000, Flask 5000 |
| Hardhat | `hardhat node`, a local chain | 8545 |
| Foundry | `anvil` from the Foundry image, a local chain | 8545 |

The compose file holds no ports, so it can be committed; the override file holds your local port and stays out of git.
When the project already has a compose file, the plugin keeps it and adds only the override file for the service you name.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always |
| `git` | To check which files git already ignores and which env files are committed. Outside a git repository, `.gitignore` lines are compared as text |
| `docker` | To run the Docker setup. Writing the files does not need it |
| `op` (1Password CLI) | For the 1Password part, signed in to your account. Without it, the other parts still work |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains how the kind of project and the port are decided, what each template writes, and how env files are linked.
In short:

- It reads the project's manifests, such as `package.json` and `pyproject.toml`, its Docker files and `.gitignore`, and only the variable names in its env files. It never prints, keeps, or sends a value
- It runs `git` to read which files are ignored or committed, checks local ports by listening on them for a moment, and connects only to `127.0.0.1`. It never runs `op` and never connects to the internet
- When you agree to start the project, the agent runs `docker compose up -d --build`, which downloads the base image and the dependencies
- The commands for 1Password are run by you, in your own terminal, and send your values to 1Password with your own sign-in
- It keeps only the ports it assigned with their project folders, and plans waiting for approval for at most a day, in `~/.local/share/init-project/`, readable only by you

## License

[MIT](LICENSE)
