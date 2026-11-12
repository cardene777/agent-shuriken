# Portman

Keep one registry of the localhost ports each of your projects uses, so two dev servers never fight over the same port.

English · [日本語](README.ja.md)

Most dev servers start on the same few ports: 3000, 5173, 8000, 8080.
With several projects on one machine, the second one fails with "address already in use", or quietly moves to another port that the next project then takes.
This plugin keeps one list of which project uses which port, shows what holds each port right now, suggests free ports that avoid the busy defaults, and writes a project's ports into its `.env.local` and Docker Compose override.
It changes the list and your project files only after you approve the change it shows.

```
Look at the ports ──> Pick a free port ──> Register it ──> Write it into the project
 (agent)               (you)                (agent)          (agent, after you approve)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install portman@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add portman@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install portman@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/portman/skills/portman   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when a port gets in your way, for example "port 3000 is already in use", "give my new project a port that nothing else uses", or "which ports do my projects use?".
You can also call it: run `/portman:portman` in Claude Code, or type `$` and pick **Portman** in Codex.
In GitHub Copilot CLI, write `/portman` in your request, and in Gemini CLI, describe the task.

1. The agent shows the registered ports and what holds each one right now
2. For a new project, the agent suggests free ports, you pick one, and the agent registers it
3. When a port is taken, the agent tells you which program or container holds it and whether that is the project itself
4. The agent shows what it would write into the project's `.env.local` and Compose override, and writes it after you approve
5. To remove ports, the agent shows the entries, and removes them after you approve

The list looks like this.

```text
project  name  port  state
shop     web   3101  in use: pid 4242 node (this project)
shop     db    5433  in use: container shop-db-1 (this project)
blog     app   3102  in use: pid 5120 node (another program)
blog     api   3103  free
```

`this project` means a process running in the project's folder, or a container of the project's Compose project.
`another program` is a collision: something else took the project's port.

The check of everything looks like this.

```text
Registry    ~/.local/share/portman/registry.json, 2 projects, 4 ports
Listeners   read with lsof, which names only your own programs; other ports are tested one by one
Docker      running

[Duplicates] none

[Collisions] 1
  blog/app  3102  pid 5120 node. Free instead: 3104

[In use by its own project] 2
  shop/web  3101  pid 4242 node
  shop/db  5433  container shop-db-1

[Unregistered] 2 ports in use outside the registry
  5000   pid 611 ControlCenter
  7000   pid 611 ControlCenter

1 problem found.
```

Writing the ports into a project shows the change first.

```text
Project shop, folder ~/projects/shop

.env.local (new file)
  --- .env.local
  +++ .env.local after apply
  @@ -0,0 +1,5 @@
  +# >>> portman >>>
  +PORT=3101
  +PORT_WEB=3101
  +PORT_DB=5433
  +# <<< portman <<<

docker-compose.override.yml (new file)
  --- docker-compose.override.yml
  +++ docker-compose.override.yml after apply
  @@ -0,0 +1,8 @@
  +# Written by portman from its registry. portman apply rewrites this file.
  +services:
  +  web:
  +    ports: !override
  +      - "3101:3000"
  +  db:
  +    ports: !override
  +      - "5433:5432"

Nothing was written. To write these changes, run:
  portman.py apply --project shop --dir '~/projects/shop' --confirm e299b178f6eb
```

## Free ports

Suggested ports are not registered, not in use on this machine, and not a default that popular tools take, such as 3000 and 3001 (Node.js dev servers), 4200 (Angular), 5000 and 7000 (AirPlay Receiver on macOS), 5173 (Vite), 5432 (PostgreSQL), 6379 (Redis), 8000 (Django), and 8080.
Ask for one of those defaults by name and the agent offers it anyway.
Suggestions stay below 32768, where the operating system starts handing out temporary ports.

## What it writes into a project

In `.env.local`, it writes only the lines between `# >>> portman >>>` and `# <<< portman <<<`: `PORT`, set to the port named `app` or the project's first port, and one `PORT_<NAME>` per registered port.
Every other line stays exactly as it is, and when another line sets the same variable, the preview says which line.
The preview never shows the other lines of the file, since they often hold secrets.

When the project has a Compose file, it writes an override next to it, such as `docker-compose.override.yml`, that publishes each registered port on its service.
Compose adds an override's ports to the ports of the main file, which would keep the old port taken, so the override uses `ports: !override` to replace them; this needs Docker Compose 2.24 or later.
An override that portman did not write is never replaced; the preview prints the lines to add by hand instead.

Whether a dev server reads its port from `.env.local` depends on the tool.
If yours does not, pass the port on the command line, for example `--port $PORT_APP` after loading the file.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always, on macOS or Linux |
| `lsof` | To name the program that holds a port. Built into macOS. Without it, Linux reads `/proc/net` and other systems test each port, and the program shows as one that could not be named |
| `docker` | Optional. When it is installed and running, ports published by containers are named, and the installed Compose version is checked |
| `git` | Optional. To find the project folder and to tell you when `.env.local` is not ignored by git |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains how ports are tested, how an owner is told apart, and exactly what `apply` writes.
In short:

- It reads its registry, the listening TCP ports from `lsof` (or `/proc/net`), the running containers from `docker ps`, and, when you write ports into a project, that project's `.env.local` and Compose file
- It opens and closes local sockets on the ports it tests, without sending any data
- It writes its registry, and in a project only `.env.local` and the Compose override, after you approve the change it shows
- It never stops a program or a container, and sends nothing over the network
- It keeps the registry in `~/.local/share/portman/`, readable only by you, until you delete it

## License

[MIT](LICENSE)
