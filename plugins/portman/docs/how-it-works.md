# How Portman works

English · [日本語](how-it-works.ja.md)

This page explains where the registry lives, how a port is tested, how the owner of a port is told apart, which ports are suggested, and exactly what `apply` writes.
Everything here is done by `skills/portman/scripts/portman.py`, which uses only the Python standard library, and `lsof`, `docker`, and `git` when they are installed.

## The registry

The registry is one JSON file.

```json
{
  "version": 1,
  "projects": {
    "shop": {
      "ports": [
        {"name": "web", "port": 3101},
        {"name": "db", "port": 5433, "service": "postgres", "target": 5432}
      ],
      "dir": "/path/to/shop"
    }
  }
}
```

| Field | Meaning |
|---|---|
| `version` | The format of the file. This version reads `1` only and refuses any other with exit code 2, without changing the file |
| `name` | What the port is for. It becomes the variable `PORT_<NAME>`, in upper case with `-` turned into `_` |
| `port` | The port on this machine, from 1 to 65535 |
| `service`, `target` | The Compose service that publishes the port, and the port inside its container, when they were given with `--service` and `--target` |
| `dir` | The project folder, given with `add --dir` or recorded by `apply`. It tells whether a process holding the port runs in the project |

It lives in `~/.local/share/portman/registry.json`, or under `PORTMAN_HOME` when that is set.
The folder is created with mode 700 and the file with mode 600, so only you can read them.
Every change is made while holding a lock on `registry.lock` in the same folder, and the file is replaced in one step, so two runs at the same time never lose a change.
A registry with a field of the wrong type, such as a port written as text, is refused with exit code 2 and a list of the entries to fix.

| Command | Reads | Changes |
|---|---|---|
| `list`, `check`, `suggest`, `doctor` | The registry and the ports in use | Nothing |
| `add` | The registry and the ports in use | Adds one entry, and the project folder when `--dir` is given |
| `remove` | The registry | Nothing in the preview. With `--confirm`, removes the entries that still match |
| `apply` | The registry, the project's `.env.local` and Compose files | Nothing in the preview. With `--confirm`, writes the project files and records the project folder |

`add` refuses a port that is already registered, a name the project already has, and a name that would give the same variable as another one, such as `web-ui` and `web_ui`.
It notes, without refusing, a port that is a common default, below 1024, or in use right now.

## How a port is tested

The listening TCP ports are read once per run, from the first of these that works.

| Source | Command | What it gives |
|---|---|---|
| `lsof` | `lsof +c 0 -nP -iTCP -sTCP:LISTEN -Fpcn` | The port, the process ID, and the program name. Without administrator rights it sees only your own programs |
| `/proc/net/tcp` and `tcp6` | Read as files, on Linux without `lsof` | The port only, so the program shows as one that could not be named |

When `docker` is installed, `docker ps --format '{{json .}}'` adds the ports published by running containers, with each container's name and the Compose project and folder from its labels.
When a container holds a port, the program that forwards it for Docker (`com.docker.backend`, `vpnkit`, `docker-proxy`, `rootlessport`, or `gvproxy`) is not listed beside it.
When `docker` is installed but does not answer, `doctor` says so, and the other sources still work.

A port that none of these list is tested directly: the script tries to connect to it on `127.0.0.1` and `::1`, then to bind it on `0.0.0.0` and `::`.
The port is in use when a connection succeeds or a bind fails because the address is in use.
These sockets are opened and closed at once on this machine; no data is sent.
This finds programs that `lsof` cannot see, such as ones run by another user, and shows them as "a program that could not be named".

## Whose a port is

For each registered port in use, the holder is compared with the project.

| Holder | This project | Another program | Unclear |
|---|---|---|---|
| A container | Its Compose project name is the project's name in the form Compose uses (lower case, letters, digits, `-`, `_`), or its Compose folder is inside the project folder | It belongs to another Compose project | It has no Compose labels |
| A process | Its working folder, read with `lsof -a -p <pid> -d cwd -Fn`, is inside the project folder | Its working folder is elsewhere | No project folder is recorded, or the working folder cannot be read |
| Something that could not be named | | | Always |

`list` shows `(this project)` or `(another program)` after the holder, and nothing when it is unclear.
`doctor` counts only "another program" as a collision, and lists unclear ones separately, so a dev server of the project itself is never reported as a problem.

## Free ports

`suggest` counts up from `--from` (3000 by default, never below 1024) and returns `--count` ports (5 by default, up to 50) that pass every test.

- Not registered to any project
- Not in use, by the tests in [How a port is tested](#how-a-port-is-tested)
- Not one of the defaults that popular tools take, unless `--allow-common` is given
- At most 32767, below the ranges macOS and Linux use for temporary ports

The defaults it skips are 1433 (SQL Server), 3000 and 3001 (Node.js, React, Next.js, Rails, and Grafana dev servers), 3306 (MySQL), 4000 (Phoenix, Jekyll, and GraphQL dev servers), 4200 (Angular), 4321 (Astro), 5000 and 7000 (Flask, and AirPlay Receiver on macOS), 5173 and 5174 (Vite), 5432 (PostgreSQL), 5672 (RabbitMQ), 6006 (Storybook), 6379 (Redis), 8000 (Django, uvicorn, and Python's `http.server`), 8008, 8080, and 8443 (alternative HTTP and HTTPS servers), 8081 (the React Native bundler), 8888 (Jupyter), 9000 (PHP-FPM, SonarQube, and MinIO), 9200 (Elasticsearch), 9229 (the Node.js inspector), 11211 (Memcached), and 27017 (MongoDB).
`check` names these defaults too.
`doctor` uses the same tests to offer a free port for each collision, counting up from the taken port, and never offers the same port twice in one run.

## What doctor reports

| Line or section | What it holds |
|---|---|
| `Registry` | The registry file and its number of projects and ports |
| `Permissions` | The registry folder or file when it is readable by others, with the `chmod` command to fix it. Counted as a problem |
| `Listeners` | Whether the ports were read with `lsof`, from `/proc/net`, or neither |
| `Docker` | Running, installed but not answering, or not installed |
| `[Duplicates]` | Ports registered twice, names repeated in a project, and names that give the same variable. Counted as problems |
| `[Collisions]` | Registered ports held by another program, with a free port to move to. Counted as problems |
| `[In use, owner unclear]` | Registered ports in use whose owner cannot be told |
| `[In use by its own project]` | Registered ports held by the project's own process or container |
| `[Unregistered]` | Ports from 1024 to 32767 that `lsof`, `/proc/net`, or `docker` list and that are not registered. When neither `lsof` nor `/proc/net` can be read, it says `unknown`, never `none` |

The last line counts the problems.
`doctor` exits 0 whether or not it finds problems; its output says what it found.

## What apply writes

`apply` works on one project folder: `--dir`, or the top folder of the git repository you are in, or the current folder.
The project is `--project`, or the project whose recorded folder is that folder, or the folder's name.

### .env.local

The script reads `.env.local` inside its own process and prints only the lines it manages and line numbers.
It manages the lines from `# >>> portman >>>` to `# <<< portman <<<`.

```
# >>> portman >>>
PORT=3101
PORT_WEB=3101
PORT_DB=5433
# <<< portman <<<
```

`PORT` is the port named `app`, or the project's first port when none is named `app`; then comes one `PORT_<NAME>` per port, in the order they were registered.
When the file has the block, only the block is replaced.
When it does not, the block is added at the end, after a blank line, and the file's last line gets a line break if it had none.
Every other line stays byte for byte as it was.
When a line outside the block sets one of the same variables, the preview names its line number and leaves it.
When the file has a start line without an end line, or more than one block, `apply` stops with exit code 1 and changes nothing.

### The Compose override

When the folder has `compose.yaml`, `compose.yml`, `docker-compose.yml`, or `docker-compose.yaml` (the first found, in that order), `apply` reads its services and writes an override with the same name plus `.override`, such as `docker-compose.override.yml`.

The script reads the common layout of a Compose file without a YAML library: a top-level `services:`, one key per service, and each service's `ports:` in short (`"3000:3000"`, `"127.0.0.1:3000:3000"`, `"${WEB_PORT:-3000}:3000"`), flow (`["3000:3000"]`), or long syntax (`target`, `published`, `host_ip`, `protocol`, `mode`, `name`, `app_protocol`).
A service that uses anchors, `<<` merges, `extends`, port ranges, tabs, or another layout it does not know is left out of the override, and the preview says to edit it by hand.

| Step | Rule |
|---|---|
| Which service | The entry's `service`, or a service with the same name as the entry. Without one, the port goes only to `.env.local` |
| Which container port | The entry's `target`, or the only TCP port the service publishes. When the service publishes several or none, the preview asks to add the port again with `--target` |
| Each port of the service | A mapping whose container port belongs to a registered entry gets the registered port as its host port, keeping its host address and protocol. Other mappings are kept as they are |
| A registered port the service does not publish yet | Added as `"<port>:<target>"` |
| Replace or add | Compose adds the ports of an override to the ports of the main file, which would leave the old host port taken. When the service already has ports, the override writes `ports: !override` to replace them |

`!override` needs Docker Compose 2.24 or later.
When `docker` is installed, `apply` runs `docker compose version --short` and notes an older version.

The override starts with the line `# Written by portman from its registry. portman apply rewrites this file.`
When the override file exists without that first line, or another override name already exists in the folder, `apply` does not write it and prints the lines to add by hand.

### Approval

Without `--confirm`, `apply` prints the change as a diff of changed lines only, without the lines around them, and a token: the first 12 characters of a SHA-256 over the folder, the project, and each file's current contents and new contents.
With `--confirm <token>`, it takes the registry lock, reads the registry and the files again, plans the change again, and writes only when the token is the same.
When the registry or a file changed in between, it exits 3 and writes nothing.

Files are replaced in one step and keep their permissions; a new file is created readable only by you.
After writing, `apply` records the project folder in the registry and prints the address of `PORT`.
When a written file is not ignored by git, `git check-ignore` tells the preview to suggest adding it to `.gitignore`.

## Removing ports

`remove <project> [<name>...]` prints each entry as `project/name=port` and changes nothing.
`remove --confirm <project>/<name>=<port>` removes an entry only when the registry still has that name with that port.
An entry that is gone or has another port is skipped with the reason, and the command exits 3.
A project whose last port is removed leaves the registry.

## What it keeps

| What | Where | Until |
|---|---|---|
| The registry | `~/.local/share/portman/registry.json`, mode 600, in a folder with mode 700, or under `PORTMAN_HOME` | You remove the entries or delete the file |
| An empty lock file | `registry.lock` next to the registry, mode 600 | You delete the folder |

In a project, it writes only `.env.local` and the Compose override, and only after you approve.
Temporary files are created next to the file they replace and renamed over it, or removed when writing fails.

## What it never does

- Stop, restart, or change a program or a container
- Show the lines of `.env.local` outside its block
- Change a line of `.env.local` outside its block, or an override it did not write
- Send anything over the network: the socket tests stay on this machine, and `docker` talks to the local Docker daemon
- Run anything other than `lsof`, `docker ps`, `docker compose version`, `git rev-parse --show-toplevel`, and `git check-ignore`

## Environment variables

| Variable | Use |
|---|---|
| `PORTMAN_HOME` | Where the registry is kept |
| `PORTMAN_LSOF` | A command used instead of `lsof`, for tests |
| `PORTMAN_DOCKER` | A command used instead of `docker`, for tests |
| `PORTMAN_PROC_NET` | A folder read instead of `/proc/net`, for tests |
| `PORTMAN_NO_PROBE` | `1` turns off the socket test, for tests |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | Nothing is registered for what you asked, or a request was refused, such as a port that is already registered |
| 2 | The input is not valid, or the registry cannot be read |
| 3 | An entry or a file changed after the preview, so it was skipped or nothing was written |
