# How Init Project works

English · [日本語](how-it-works.ja.md)

This page explains how the kind of project and the local port are decided, what each Docker template writes, how env files are linked to 1Password, and what the plugin keeps.
Everything here is done by `skills/init-project/scripts/init_project.py`, which uses only the Python standard library and `git`.

## Commands

| Command | What it does |
|---|---|
| `detect` | Prints what kind of project the folder is, and what is already there. Writes nothing |
| `plan` | Prints every change it would make and saves the plan. Writes nothing into the project |
| `apply <plan id>` | Checks each change again and writes it, then records the port |
| `discard <plan id>` | Removes a plan without writing |
| `ports` | Lists the ports it assigned. `--forget <folder>` removes a folder's ports |
| `wait --port <n>` | Waits up to 30 seconds (`--timeout`) for `http://127.0.0.1:<n>/` to answer |

Every command works on the folder given with `--dir`, or the current folder.

## How it tells the kind of project

The first rule that matches decides.

| Kind | Rule |
|---|---|
| `smart-contract` | `foundry.toml` exists (Foundry), or `hardhat.config.js`, `.ts`, `.cjs`, or `.mjs` exists (Hardhat) |
| `cli` | `package.json` has a `bin` field |
| `web-app` | `package.json` has a `dev` or `start` script |
| `library` | Any other `package.json` |
| `cli` | `Cargo.toml` has a `[[bin]]` section, or `src/main.rs` exists |
| `library` | Any other `Cargo.toml` |
| `web-app` | `requirements.txt` or `pyproject.toml` lists `django`, `fastapi`, `flask`, or `uvicorn` as a whole name, so `flask-sqlalchemy` alone does not count |
| `library` | Any other `pyproject.toml`, `requirements.txt`, or `setup.py` |
| `unknown` | None of these files |

For Node projects it also reads these.

| What | Where it comes from |
|---|---|
| Framework | The first of `next`, `nuxt`, `astro`, and `vite` in `dependencies` or `devDependencies`, otherwise plain Node |
| Package manager | The lockfile: `bun.lock` or `bun.lockb` for bun, `pnpm-lock.yaml` for pnpm, `yarn.lock` for yarn, `package-lock.json` for npm. Without one, the `packageManager` field, and otherwise npm |
| Node version | The major version in `.nvmrc` or `.node-version`, otherwise 24 |
| Dev command | `<package manager> run dev`, or `run start` when there is no `dev` script |

For Python projects, the version comes from `.python-version`, otherwise 3.13.
A FastAPI app is taken from `main.py`, `app/main.py`, or `src/main.py`, in that order, and is guessed as `main:app` when none exists, which `detect` says.

## How the local port is picked

The first of these that applies gives the port.

1. `--port <n>`. It must not be assigned to another project, and it must be free unless it is already this project's port
2. The port in the project's existing compose override file, when the plan keeps that file
3. The port recorded for this project folder and service
4. The first port from `--from` (3100 by default) up that is free, is not assigned to another project, and is not one of these ports that common tools use: 3000, 3001, 3306, 4000, 4200, 4321, 5000, 5173, 5432, 5672, 6379, 8000, 8080, 8443, 8545, 8888, 9000, 9090, 9200, 27017

A port is free when nothing answers a connection on `127.0.0.1` or `::1`, and the script can listen on it for a moment on `0.0.0.0`, `127.0.0.1`, and `::`.
`apply` checks a newly picked or requested port again right before writing; if it came into use or was assigned elsewhere, the override file and the record are skipped.

The ports are recorded in `ports.json` in the plugin's folder, as a list of folder, service, and port, with a format version.
A record with another format version is refused rather than read, so the script never picks a port on wrong information.

## The Docker files

| Project | Dockerfile | Command in the container | Port in the container |
|---|---|---|---|
| Node web app | `node:<version>-alpine`, or `oven/bun:1` for bun. Installs with the project's package manager; pnpm is installed first, at the version in `packageManager` when it names one, and yarn when the image lacks it | The `dev` or `start` script. With the `dev` script, Vite, Astro, and Nuxt get `--host 0.0.0.0` so the server is reachable from outside the container | Next.js and Nuxt 3000, Astro 4321, Vite 5173, others 3000 |
| Python web app | `python:<version>-slim`. Installs `requirements.txt`, or the project itself with `pip install -e .` | `uvicorn <app> --host 0.0.0.0 --port 8000 --reload`, `flask run --host 0.0.0.0 --port 5000 --debug`, or `python manage.py runserver 0.0.0.0:8000` | 8000, Flask 5000 |
| Hardhat | The Node image as above | `npx hardhat node --hostname 0.0.0.0`, or `bunx` with bun | 8545 |
| Foundry | None. The compose file uses `ghcr.io/foundry-rs/foundry:latest` | `anvil --host 0.0.0.0` | 8545 |

| File | Contents |
|---|---|
| `Dockerfile` | As in the table above, copying the whole project into `/app` before installing |
| `.dockerignore` | `.git`, `.env`, `.env.*`, `*.log`, `.DS_Store`, and for Node `node_modules/`, `dist/`, `.turbo/` (Next.js adds `.next/` and `out/`, Hardhat adds `artifacts/`, `cache/`, `typechain-types/`), for Python `__pycache__/`, `*.pyc`, `.venv/`, `venv/` |
| `docker-compose.yml` | One service, `app`, or `chain` for a local chain. It is built from the project folder and mounts it at `/app`, with `node_modules` kept inside the container for Node; Foundry's service runs the Foundry image instead. Node web apps get `NODE_ENV=development`, and every service but Foundry's gets the names from the env files at the project root that the same plan links to 1Password, so `op run` can pass their values in. No ports |
| `docker-compose.override.yml` | The service's port as `127.0.0.1:<local port>:<port in the container>` |

A compose file named `compose.yaml`, `compose.yml`, `docker-compose.yml`, or `docker-compose.yaml` counts as existing, and the override file is named after it, such as `compose.override.yaml` next to `compose.yaml`.
When a compose file exists and is not named in `--overwrite`, it is kept, and the `Dockerfile` and `.dockerignore` are planned only when one of them is named in `--overwrite`.
The override file then goes to the service named with `--service`, or the template's service when the compose file has it, or the only service; with several and no `--service`, `plan` stops and names them.
The port in the container comes from `--container-port` or the template.

## Existing files

| State | What the plan does |
|---|---|
| The file does not exist | `[create]` with the full content |
| The file exists | `[skip]`, keeping it |
| The file exists and is named in `--overwrite` | `[overwrite]` with a diff. Only the `Dockerfile`, `.dockerignore`, compose file, and override file can be named; env files never can |
| `.gitignore` or a `.tpl` file exists | `[append]` with only the missing lines |

The plan file stores the full content of new and replacing files, and for files to replace or extend, only a SHA-256 hash of their current content.
`apply` writes each item only when its file is still missing (for a new file) or still has that hash (for a file to replace or extend), and skips it with the reason otherwise.
New files are created without following an existing path, replaced files keep their permissions, and lines are added at the end of a file.

## Linking env files to 1Password

The env files are `.env` and every `.env.<name>` in the project folder and in each folder under `apps/` and `packages/`.
Files whose name ends in `.tpl`, `.example`, `.sample`, `.template`, `.dist`, `.defaults`, `.schema`, `.vault`, or `.keys` are left out, since they hold no values by convention.

From each file the script takes the name of every line of the form `NAME=` or `export NAME=`, where the name is letters, digits, and `_`.
It looks at the rest of the line only to find where a quoted value ends, so that the lines of a multi-line value, such as a private key, are never taken for names.
It never prints, stores, or sends any part of a value.

| What | Rule | Example for `packages/api/.env.dev` |
|---|---|---|
| Template | The env file's path with `.tpl` added | `packages/api/.env.dev.tpl` |
| Section | The path without leading dots, with every character other than letters, digits, `_`, and `-` turned into `_` | `packages_api_env_dev` |
| Reference | `op://<vault>/<item>/<section>/<NAME>`, in double quotes when it holds a space | `JWT_SECRET=op://Personal/shop/packages_api_env_dev/JWT_SECRET` |
| Field type | `text` for `PORT`, `HOST`, `HOSTNAME`, `NODE_ENV`, `APP_ENV`, `ENV`, `LOG_LEVEL`, `TZ`, `DEBUG`, names ending in `_PORT`, `_HOST`, `_HOSTNAME`, or `_REGION`, and names starting with `NEXT_PUBLIC_`, `NUXT_PUBLIC_`, `VITE_`, `PUBLIC_`, `EXPO_PUBLIC_`, or `REACT_APP_`. `concealed` for every other name | `concealed` |

The item is named after the project folder unless `--item` is given.
Vault and item names may hold letters, digits, spaces, `.`, `_`, and `-`, so that the references work; for any other name, use the vault's ID.
When a `.tpl` file already exists, its names are read the same way and only the missing ones are added.
`--env` stops with exit code 3 when `op` is not installed, because the references are useless without it, but the script itself never runs `op`.

The plan prints commands for you to run in bash or zsh, starting with `cd` to the project folder.

```bash
cd ~/projects/shop
op item get shop --vault Personal >/dev/null 2>&1 || op item create --vault Personal --category 'Secure Note' --title shop --tags env >/dev/null
( set -a; . ./.env; set +a; op item edit shop --vault Personal "env.DATABASE_URL[concealed]=${DATABASE_URL-}" >/dev/null )
```

The `op item get` line creates the item when it is missing.
Each line after it loads one env file in a subshell and passes its values to `op item edit`, so the values go from the file to 1Password without being printed, and the shell history keeps only the names.
Loading the file runs it as shell code, like `source .env`; for a file that is not valid shell, add the fields in the 1Password app instead.
The agent never runs these commands.

## .gitignore

The plan adds these lines to `.gitignore`, creating it when it does not exist, under a `# Added by init-project` line.

| Line | Why |
|---|---|
| Each linked env file, such as `.env` | Keeps the values out of git |
| `!` and each `.tpl` file, such as `!.env.tpl` | Keeps the references in git when a pattern such as `.env*` would ignore them |
| The override file | Keeps the local port out of git |

Inside a git repository, a line is added only when `git check-ignore --no-index` shows the file in the other state, reading the project's ignore files and leaving out your global ignore file, which other people do not share.
Outside a git repository, a line is added when the same line is not already there.
An env file that git already tracks stays tracked; the plan names it and suggests rotating its keys, since the values are in the history.

## What it keeps

| What | Where | Until |
|---|---|---|
| The ports it assigned, with the project folder and service | `~/.local/share/init-project/ports.json`, or under `INIT_PROJECT_HOME`, in a folder readable only by you | You remove them with `ports --forget <folder>` or delete the file |
| Plans waiting to be applied: the planned file contents, hashes of existing files, the port, and the next steps | `~/.local/share/init-project/plans/<plan id>.json`, readable only by you | `apply` or `discard`, a newer plan for the same folder, or one day |

The files it writes into your project are listed in each plan, and are written only by `apply`.

## What it never does

- Read, print, keep, or send a value from an env file
- Run `op`, or ask you to paste a value
- Replace or extend a file that changed after the plan, replace an existing file you did not name, or replace an env file
- Delete a file in your project
- Connect to anything but `127.0.0.1` and `::1`. It runs only `git rev-parse`, `git check-ignore`, and `git ls-files` to read the repository

## Environment variables

| Variable | Use |
|---|---|
| `INIT_PROJECT_HOME` | Where the ports and plans are kept |
| `INIT_PROJECT_OP` | A path checked instead of `op` on the `PATH`, for tests |
| `INIT_PROJECT_DOCKER` | A path checked instead of `docker` on the `PATH`, for tests |
