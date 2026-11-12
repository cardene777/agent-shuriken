#!/usr/bin/env python3
"""Set up a project for local work: tell what kind of project it is, pick a free local port,
render a Docker setup, and link its environment variables to 1Password with references.

Nothing is written into the project until a plan is shown and applied:

  init_project.py detect  [--dir DIR] [--json]
  init_project.py plan    [--dir DIR] [--docker] [--assign-port] [--port N] [--from N]
                          [--service NAME] [--container-port N] [--overwrite FILE]...
                          [--env --vault NAME [--item NAME] [--env-file FILE]...]
  init_project.py apply   PLAN_ID
  init_project.py discard PLAN_ID
  init_project.py ports   [--forget DIR]
  init_project.py wait    --port N [--timeout SECONDS]

State lives in ~/.local/share/init-project/ (or INIT_PROJECT_HOME): the local ports this script
assigned, and plans waiting to be applied. Env files are read only to find the names before "=";
no part of a value is printed, kept, or sent.

Exit codes: 0 done, 1 nothing found, 2 bad input, 3 op is not installed, 4 some items changed after
the plan and were skipped, 5 no Docker template for this kind of project, 6 the port is taken.
"""
import argparse
import difflib
import hashlib
import http.client
import json
import os
import re
import secrets
import shlex
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

PLAN_VERSION = 1
RECORD_VERSION = 1
PLAN_MAX_AGE = 24 * 3600
DEFAULT_FROM = 3100
# Ports that common dev servers, databases, and tools listen on. A picked port skips them;
# --port can still ask for one of them.
BUSY_PORTS = frozenset((3000, 3001, 3306, 4000, 4200, 4321, 5000, 5173, 5432, 5672, 6379, 8000,
                        8080, 8443, 8545, 8888, 9000, 9090, 9200, 27017))
DEFAULT_NODE = 24
DEFAULT_PYTHON = "3.13"
FOUNDRY_IMAGE = "ghcr.io/foundry-rs/foundry:latest"
COMPOSE_NAMES = ("compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml")
OVERRIDE_NAMES = ("compose.override.yaml", "compose.override.yml", "docker-compose.override.yml",
                  "docker-compose.override.yaml")
HARDHAT_CONFIGS = ("hardhat.config.js", "hardhat.config.ts", "hardhat.config.cjs", "hardhat.config.mjs")
LOCKFILES = (("bun.lock", "bun"), ("bun.lockb", "bun"), ("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"),
             ("package-lock.json", "npm"))
NODE_PORTS = {"next": 3000, "nuxt": 3000, "astro": 4321, "vite": 5173, "node": 3000}
# These dev servers listen only on localhost unless told otherwise, which a container cannot reach.
HOST_FLAG = {"nuxt", "astro", "vite"}
PYTHON_PORTS = {"django": 8000, "fastapi": 8000, "flask": 5000}
# Env files that hold no values by convention, and the references this script writes.
ENV_SKIP_SUFFIXES = {"tpl", "example", "sample", "template", "dist", "defaults", "schema", "vault", "keys"}
ENV_NAME_LINE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$")
# Names whose values are settings rather than secrets. Every other name is stored concealed.
TEXT_FIELD = re.compile(r"^(?:PORT|HOST|HOSTNAME|NODE_ENV|APP_ENV|ENV|LOG_LEVEL|TZ|DEBUG)$"
                        r"|_(?:PORT|HOST|HOSTNAME|REGION)$"
                        r"|^(?:NEXT_PUBLIC|NUXT_PUBLIC|VITE|PUBLIC|EXPO_PUBLIC|REACT_APP)_")
# Names 1Password references accept without an ID: letters, digits, spaces, ".", "_", and "-".
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._-]{0,99}$")
WEB_PYTHON = re.compile(r"(?im)(?:^|[\s\"',\[])(django|fastapi|flask|uvicorn)(?=[\s<>=!~;\[\],\"']|$)")
PLAN_ID = re.compile(r"^[0-9a-f]{8}$")


class Stop(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


# ------------------------------------------------------------------ files and state

def state_home():
    return os.environ.get("INIT_PROJECT_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "init-project")


def private_dir(path):
    os.makedirs(path, mode=0o700, exist_ok=True)
    os.chmod(path, 0o700)


def write_private(path, text):
    private_dir(state_home())
    private_dir(os.path.dirname(path))
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def read_text(path, limit=2000000):
    """Read a project file that holds no secrets. Env files are read only by env_names()."""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read(limit)
    except OSError:
        return None


def sha256_of(path):
    try:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError:
        return None


def listdir(path):
    try:
        return sorted(os.listdir(path))
    except OSError:
        return []


def record_path():
    return os.path.join(state_home(), "ports.json")


def load_record():
    try:
        with open(record_path(), encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return []
    except (OSError, ValueError):
        raise Stop(2, "Cannot read %s. Move it away and run again." % record_path())
    if not isinstance(data, dict) or data.get("version") != RECORD_VERSION or not isinstance(data.get("ports"), list):
        raise Stop(2, "%s has a format this version does not read. Move it away and run again." % record_path())
    return [e for e in data["ports"] if isinstance(e, dict) and isinstance(e.get("port"), int)
            and isinstance(e.get("folder"), str) and isinstance(e.get("service"), str)]


def save_record(entries):
    entries = sorted(entries, key=lambda e: (e["port"], e["folder"], e["service"]))
    write_private(record_path(), json.dumps({"version": RECORD_VERSION, "ports": entries}, indent=2) + "\n")


def plans_dir():
    return os.path.join(state_home(), "plans")


def plan_path(plan_id):
    if not PLAN_ID.match(plan_id or ""):
        raise Stop(2, "A plan id is 8 hexadecimal characters, as plan prints it.")
    return os.path.join(plans_dir(), plan_id + ".json")


def clean_plans(folder=None):
    """Remove plans older than a day, and earlier plans for the same folder."""
    now = time.time()
    for name in listdir(plans_dir()):
        path = os.path.join(plans_dir(), name)
        try:
            if now - os.stat(path).st_mtime > PLAN_MAX_AGE:
                os.remove(path)
                continue
            if folder:
                with open(path, encoding="utf-8") as f:
                    if json.load(f).get("folder") == folder:
                        os.remove(path)
        except (OSError, ValueError):
            continue


# ------------------------------------------------------------------ tools

def tool_installed(env_name, command):
    """True when the command can be found. Tests point the variable at a stand-in."""
    given = os.environ.get(env_name)
    if given:
        return os.path.isfile(given) and os.access(given, os.X_OK)
    return shutil.which(command) is not None


def git(folder, *args):
    try:
        return subprocess.run(["git", "-C", folder, "-c", "core.excludesFile=/dev/null"] + list(args),
                              capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None


def in_git(folder):
    r = git(folder, "rev-parse", "--is-inside-work-tree")
    return bool(r and r.returncode == 0 and r.stdout.strip() == "true")


def git_ignored(folder, rel):
    """True or False from the project's .gitignore files, or None when git cannot tell."""
    r = git(folder, "check-ignore", "-q", "--no-index", "--", rel)
    if r is None or r.returncode not in (0, 1):
        return None
    return r.returncode == 0


def git_tracked(folder, rel):
    r = git(folder, "ls-files", "--error-unmatch", "--", rel)
    return bool(r and r.returncode == 0)


# ------------------------------------------------------------------ env files

def find_env_files(folder):
    """Env files with values: .env and .env.* in the folder and in apps/* and packages/*."""
    dirs = [""]
    for top in ("apps", "packages"):
        for sub in listdir(os.path.join(folder, top)):
            if not sub.startswith(".") and os.path.isdir(os.path.join(folder, top, sub)):
                dirs.append(top + "/" + sub)
    found = []
    for rel_dir in dirs:
        for name in listdir(os.path.join(folder, rel_dir)):
            if name != ".env" and not name.startswith(".env."):
                continue
            if name != ".env" and name.rsplit(".", 1)[-1].lower() in ENV_SKIP_SUFFIXES:
                continue
            if os.path.isfile(os.path.join(folder, rel_dir, name)):
                found.append((rel_dir + "/" + name) if rel_dir else name)
    return found


def quote_closes(text, quote):
    i = 0
    while i < len(text):
        if quote == '"' and text[i] == "\\":
            i += 2
            continue
        if text[i] == quote:
            return True
        i += 1
    return False


def env_names(path):
    """Return the variable names an env file sets, in order.

    The rest of each line is looked at only to find where a quoted value ends, so that the lines
    of a multi-line value are never taken for names. No part of a value is returned."""
    names, quote = [], None
    try:
        f = open(path, encoding="utf-8", errors="replace")
    except OSError:
        return names
    with f:
        for line in f:
            if quote:
                if quote_closes(line, quote):
                    quote = None
                continue
            m = ENV_NAME_LINE.match(line)
            if not m:
                continue
            rest = m.group(2).lstrip()
            if rest[:1] in ("'", '"', "`") and not quote_closes(rest[1:], rest[0]):
                quote = rest[0]
            if m.group(1) not in names:
                names.append(m.group(1))
    return names


def section_for(rel):
    """The 1Password section for an env file: its path without leading dots, "." and "/" as "_"."""
    parts = [p.lstrip(".") for p in rel.split("/")]
    return re.sub(r"[^A-Za-z0-9_-]", "_", "_".join(p for p in parts if p))


def field_type(name):
    return "text" if TEXT_FIELD.search(name) else "concealed"


def reference(vault, item, section, name):
    return "op://%s/%s/%s/%s" % (vault, item, section, name)


# ------------------------------------------------------------------ detection

def node_major(folder):
    for name in (".nvmrc", ".node-version"):
        m = re.match(r"\s*v?(\d{1,2})(?:[.\s]|$)", read_text(os.path.join(folder, name)) or "")
        if m and int(m.group(1)) >= 10:
            return int(m.group(1)), name
    return DEFAULT_NODE, None


def python_version(folder):
    m = re.match(r"\s*(3\.\d{1,2})", read_text(os.path.join(folder, ".python-version")) or "")
    return (m.group(1), ".python-version") if m else (DEFAULT_PYTHON, None)


def package_manager(folder, pkg):
    for lock, pm in LOCKFILES:
        if os.path.exists(os.path.join(folder, lock)):
            return pm, lock
    field = pkg.get("packageManager") if isinstance(pkg.get("packageManager"), str) else ""
    name = field.split("@", 1)[0]
    if name in ("npm", "pnpm", "yarn", "bun"):
        return name, "packageManager in package.json"
    return "npm", None


def pinned_version(pkg, pm):
    """The version in "packageManager": "pnpm@9.1.0", when it names this package manager."""
    m = re.match(r"^%s@([0-9][0-9A-Za-z.-]*)" % re.escape(pm), str(pkg.get("packageManager") or ""))
    return m.group(1) if m else None


def node_framework(pkg):
    deps = {}
    for key in ("dependencies", "devDependencies"):
        if isinstance(pkg.get(key), dict):
            deps.update(pkg[key])
    for name in ("next", "nuxt", "astro", "vite"):
        if name in deps:
            return name
    return "node"


def python_framework(folder):
    found = set()
    for name in ("requirements.txt", "pyproject.toml"):
        found.update(m.group(1).lower() for m in WEB_PYTHON.finditer(read_text(os.path.join(folder, name)) or ""))
    for fw in ("django", "fastapi", "flask"):
        if fw in found:
            return fw
    return "fastapi" if "uvicorn" in found else None


def asgi_app(folder):
    for rel, target in (("main.py", "main:app"), ("app/main.py", "app.main:app"), ("src/main.py", "src.main:app")):
        if os.path.isfile(os.path.join(folder, rel)):
            return target, False
    return "main:app", True


def run_command(pm, script):
    return "%s run %s" % (pm, script)


def detect(folder):
    def has(*parts):
        return os.path.exists(os.path.join(folder, *parts))

    info = {"folder": folder, "name": os.path.basename(folder), "kind": None, "reason": None, "runtime": None,
            "framework": None, "package_manager": None, "package_manager_from": None, "node": None,
            "python": None, "version_from": None, "script": None, "app_module": None, "app_module_guessed": False,
            "dev_command": "<your command>", "template": None, "notes": []}
    pkg = None
    if os.path.isfile(os.path.join(folder, "package.json")):
        try:
            pkg = json.loads(read_text(os.path.join(folder, "package.json")) or "")
        except ValueError:
            pkg = None
        if not isinstance(pkg, dict):
            pkg = {}
            info["notes"].append("package.json could not be read as a JSON object")
    scripts = pkg.get("scripts") if pkg and isinstance(pkg.get("scripts"), dict) else {}
    hardhat = next((n for n in HARDHAT_CONFIGS if has(n)), None)
    python_files = [n for n in ("pyproject.toml", "requirements.txt", "setup.py") if has(n)]

    if has("foundry.toml"):
        info.update(kind="smart-contract", reason="foundry.toml", framework="foundry", dev_command="forge script <script>")
    elif hardhat:
        info.update(kind="smart-contract", reason=hardhat, runtime="node", framework="hardhat",
                    dev_command="npx hardhat run <script>")
    elif pkg is not None:
        info["runtime"] = "node"
        if pkg.get("bin"):
            info.update(kind="cli", reason="package.json has a bin field")
        elif scripts.get("dev") or scripts.get("start"):
            script = "dev" if scripts.get("dev") else "start"
            info.update(kind="web-app", reason="package.json has a %s script" % script, script=script,
                        framework=node_framework(pkg))
        else:
            info.update(kind="library", reason="package.json has no bin field and no dev or start script")
    elif has("Cargo.toml"):
        cargo = read_text(os.path.join(folder, "Cargo.toml")) or ""
        info.update(runtime="rust", dev_command="cargo run")
        if re.search(r"^\s*\[\[bin\]\]", cargo, re.M) or has("src", "main.rs"):
            info.update(kind="cli", reason="Cargo.toml builds a binary")
        else:
            info.update(kind="library", reason="Cargo.toml builds a library")
    elif python_files:
        info["runtime"] = "python"
        fw = python_framework(folder)
        if fw:
            info.update(kind="web-app", reason="the Python dependencies include %s" % fw, framework=fw)
        else:
            info.update(kind="library", reason="%s without a web framework" % python_files[0])
    else:
        info.update(kind="unknown", reason="no package.json, pyproject.toml, requirements.txt, setup.py, "
                                           "Cargo.toml, foundry.toml, or Hardhat config")

    if info["runtime"] == "node":
        pm, source = package_manager(folder, pkg or {})
        major, vsource = node_major(folder)
        info.update(package_manager=pm, package_manager_from=source, node=major, version_from=vsource,
                    pm_version=pinned_version(pkg or {}, pm))
        if info["script"]:
            info["dev_command"] = run_command(pm, info["script"])
    if info["runtime"] == "python":
        version, vsource = python_version(folder)
        info.update(python=version, version_from=vsource,
                    install="requirements.txt" if has("requirements.txt") else "project")
        fw = info["framework"]
        if fw == "fastapi":
            module, guessed = asgi_app(folder)
            info.update(app_module=module, app_module_guessed=guessed, dev_command="uvicorn %s --reload" % module)
        elif fw == "flask":
            info["dev_command"] = "flask run --debug"
        elif fw == "django":
            info["dev_command"] = "python manage.py runserver"

    fw = info["framework"]
    if info["kind"] == "web-app" and info["runtime"] == "node":
        info["template"] = {"name": "node web app", "service": "app", "port": NODE_PORTS[fw], "builds": True}
    elif info["kind"] == "web-app" and info["runtime"] == "python":
        info["template"] = {"name": "python web app", "service": "app", "port": PYTHON_PORTS[fw], "builds": True}
    elif fw == "foundry":
        info["template"] = {"name": "local chain (anvil)", "service": "chain", "port": 8545, "builds": False}
    elif fw == "hardhat":
        info["template"] = {"name": "local chain (hardhat node)", "service": "chain", "port": 8545, "builds": True}

    info["files"] = {
        "Dockerfile": has("Dockerfile"),
        ".dockerignore": has(".dockerignore"),
        "compose": next((n for n in COMPOSE_NAMES if os.path.isfile(os.path.join(folder, n))), None),
        "override": next((n for n in OVERRIDE_NAMES if os.path.isfile(os.path.join(folder, n))), None),
    }
    git_ok = in_git(folder)
    info["git"] = git_ok
    info["env_files"] = [{"path": rel, "names": env_names(os.path.join(folder, rel)),
                          "tracked": git_tracked(folder, rel) if git_ok else False}
                         for rel in find_env_files(folder)]
    info["op"] = tool_installed("INIT_PROJECT_OP", "op")
    info["docker"] = tool_installed("INIT_PROJECT_DOCKER", "docker")
    info["ports"] = [{"service": e["service"], "port": e["port"]} for e in load_record() if e["folder"] == folder]
    return info


# ------------------------------------------------------------------ ports

def port_in_use(port):
    """True when something answers on the port or it cannot be listened on for a moment."""
    for family, host in ((socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")):
        try:
            with socket.socket(family, socket.SOCK_STREAM) as s:
                s.settimeout(0.3)
                if s.connect_ex((host, port)) == 0:
                    return True
        except OSError:
            pass
    for family, host in ((socket.AF_INET, "0.0.0.0"), (socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::")):
        try:
            s = socket.socket(family, socket.SOCK_STREAM)
        except OSError:
            continue
        try:
            s.bind((host, port))
        except OSError:
            return True
        finally:
            s.close()
    return False


def choose_port(folder, service, requested, start, record, fixed=None):
    """Return (port, why, check). check says whether apply must check the port is still free."""
    others = {e["port"] for e in record if not (e["folder"] == folder and e["service"] == service)}
    mine = next((e["port"] for e in record if e["folder"] == folder and e["service"] == service), None)
    if requested is not None:
        if requested in others:
            raise Stop(6, "Port %d is already assigned to another project. See: init_project.py ports" % requested)
        if requested != mine and port_in_use(requested):
            raise Stop(6, "Port %d is in use on this machine. Pick another one." % requested)
        return requested, "asked for", requested != mine
    if fixed is not None:
        return fixed[0], "set in %s" % fixed[1], False
    if mine is not None:
        return mine, "assigned to this project before", False
    port = start
    while port <= 65535:
        if port not in BUSY_PORTS and port not in others and not port_in_use(port):
            return port, "free", True
        port += 1
    raise Stop(6, "No free port from %d up." % start)


def compose_services(text):
    """The service names under the top-level services: key of a compose file."""
    names, inside, indent = [], False, None
    for line in (text or "").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if re.match(r"^services:\s*(#.*)?$", line):
            inside = True
            continue
        if not inside:
            continue
        if not line[0].isspace():
            inside = False
            continue
        width = len(line) - len(line.lstrip(" "))
        if indent is None:
            indent = width
        m = re.match(r"^\s*([A-Za-z0-9._-]+):\s*(#.*)?$", line)
        if width == indent and m:
            names.append(m.group(1))
    return names


def override_port(text):
    m = re.search(r"^\s*-\s*[\"']?(?:\d{1,3}(?:\.\d{1,3}){3}:)?(\d{1,5}):\d{1,5}", text or "", re.M)
    return int(m.group(1)) if m else None


def override_for(compose_name):
    base, ext = compose_name.rsplit(".", 1)
    return "%s.override.%s" % (base, ext)


# ------------------------------------------------------------------ templates

def node_install(info):
    pm = info["package_manager"]
    if pm == "pnpm":
        return ["RUN npm install -g pnpm%s" % ("@" + info["pm_version"] if info.get("pm_version") else ""),
                "COPY . .", "RUN pnpm install"]
    if pm == "yarn":
        return ["RUN yarn --version >/dev/null 2>&1 || npm install -g yarn", "COPY . .", "RUN yarn install"]
    return ["COPY . .", "RUN %s install" % pm]


def render_dockerfile(info, port):
    lines = ["# Development image for %s, written by init-project." % info["name"]]
    if info["runtime"] == "node":
        pm = info["package_manager"]
        lines.append("FROM oven/bun:1" if pm == "bun" else "FROM node:%d-alpine" % info["node"])
        lines.append("WORKDIR /app")
        lines += node_install(info)
        if info["framework"] == "hardhat":
            cmd = ["bunx" if pm == "bun" else "npx", "hardhat", "node", "--hostname", "0.0.0.0"]
        else:
            cmd = [pm, "run", info["script"]]
            if info["framework"] in HOST_FLAG and info["script"] == "dev":
                cmd += (["--"] if pm == "npm" else []) + ["--host", "0.0.0.0"]
    else:
        fw = info["framework"]
        lines += ["FROM python:%s-slim" % info["python"], "WORKDIR /app",
                  "ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1", "COPY . ."]
        if info["install"] == "requirements.txt":
            lines.append("RUN pip install --no-cache-dir -r requirements.txt")
        else:
            lines.append("RUN pip install --no-cache-dir -e .")
        if fw == "django":
            cmd = ["python", "manage.py", "runserver", "0.0.0.0:%d" % port]
        elif fw == "flask":
            cmd = ["flask", "run", "--host", "0.0.0.0", "--port", str(port), "--debug"]
        else:
            cmd = ["uvicorn", info["app_module"], "--host", "0.0.0.0", "--port", str(port), "--reload"]
    lines += ["EXPOSE %d" % port, "CMD " + json.dumps(cmd)]
    return "\n".join(lines) + "\n"


def render_dockerignore(info):
    lines = ["# Files kept out of the Docker build, written by init-project.",
             ".git", ".env", ".env.*", "*.log", ".DS_Store"]
    if info["runtime"] == "node":
        lines += ["node_modules/", "dist/", ".turbo/"]
        if info["framework"] == "next":
            lines += [".next/", "out/"]
        if info["framework"] == "hardhat":
            lines += ["artifacts/", "cache/", "typechain-types/"]
    if info["runtime"] == "python":
        lines += ["__pycache__/", "*.pyc", ".venv/", "venv/"]
    return "\n".join(lines) + "\n"


def render_compose(info, service, override_name, pass_names):
    lines = ["# Development services for %s, written by init-project." % info["name"],
             "# The local port is set in %s, which stays out of git." % override_name,
             "services:", "  %s:" % service]
    if info["framework"] == "foundry":
        lines += ["    image: %s" % FOUNDRY_IMAGE, '    command: ["anvil --host 0.0.0.0"]']
        return "\n".join(lines) + "\n"
    lines += ["    build: .", "    volumes:", "      - .:/app"]
    env = []
    if info["runtime"] == "node":
        lines.append("      - /app/node_modules")
        if info["kind"] == "web-app":
            env.append("NODE_ENV=development")
    fixed = {e.split("=", 1)[0] for e in env}
    # Names without a value pass the variable through from the shell that runs docker compose,
    # which is how op run hands the values to the container.
    env += [n for n in pass_names if n not in fixed]
    if env:
        lines.append("    environment:")
        lines += ["      - " + e for e in env]
    return "\n".join(lines) + "\n"


def render_override(service, port, container_port):
    return "\n".join([
        "# Local port for this machine, written by init-project. Keep it out of git.",
        "services:",
        "  %s:" % service,
        "    ports:",
        '      - "127.0.0.1:%d:%d"' % (port, container_port),
    ]) + "\n"


def render_template(env_rel, refs, dev_command):
    lines = ["# 1Password references for %s, written by init-project." % env_rel,
             "# It holds no values, so it can be committed. Start the app with:",
             "#   op run --env-file %s.tpl -- %s" % (env_rel, dev_command)]
    lines += [env_line(name, ref) for name, ref in refs]
    return "\n".join(lines) + "\n"


def env_line(name, ref):
    return '%s="%s"' % (name, ref) if " " in ref else "%s=%s" % (name, ref)


def import_commands(folder, vault, item, groups):
    """Commands for the user's own terminal that put the values into 1Password.

    Each env file is loaded in a subshell, so its values go from the file to op without being
    printed, and the shell history holds only the names."""
    q = shlex.quote
    lines = ["cd %s" % q(folder),
             "op item get %s --vault %s >/dev/null 2>&1 || op item create --vault %s --category 'Secure Note' "
             "--title %s --tags env >/dev/null" % (q(item), q(vault), q(vault), q(item))]
    for rel, section, names in groups:
        fields = " ".join('"%s.%s[%s]=${%s-}"' % (section, n, field_type(n), n) for n in names)
        lines.append("( set -a; . %s; set +a; op item edit %s --vault %s %s >/dev/null )"
                     % (q("./" + rel), q(item), q(vault), fields))
    return lines


def port_hint(info, port):
    fw, dev, pm = info["framework"], info["dev_command"], info["package_manager"]
    if fw in HOST_FLAG:
        return "%s%s --port %d" % (dev, " --" if pm == "npm" else "", port)
    if info["kind"] == "web-app" and info["runtime"] == "node":
        return "PORT=%d %s" % (port, dev)
    if fw in ("fastapi", "flask"):
        return "%s --port %d" % (dev, port)
    if fw == "django":
        return "%s %d" % (dev, port)
    if fw == "foundry":
        return "anvil --port %d" % port
    if fw == "hardhat":
        return "npx hardhat node --port %d" % port
    return None


# ------------------------------------------------------------------ plan

def project_folder(path):
    folder = os.path.realpath(os.path.expanduser(path or "."))
    if not os.path.isdir(folder):
        raise Stop(2, "Not a folder: %s" % path)
    return folder


def clean_rel(path):
    rel = os.path.normpath(path)
    if os.path.isabs(rel) or rel.startswith(".."):
        raise Stop(2, "Give paths relative to the project folder: %s" % path)
    return rel


def check_name(value, what, hint):
    if not SAFE_NAME.match(value or ""):
        raise Stop(2, "The %s name %r can hold only letters, digits, spaces, \".\", \"_\", and \"-\". %s"
                   % (what, value, hint))


def add_file(plan, folder, rel, content, overwrite, port_file=False):
    path = os.path.join(folder, rel)
    item = {"path": rel, "port_file": port_file}
    if not os.path.lexists(path):
        item.update(action="create", content=content, before=None)
    elif rel in overwrite:
        with open(path, encoding="utf-8", errors="replace") as f:
            old = f.read()
        if old == content:
            item.update(action="skip", reason="already has this content")
        else:
            item.update(action="overwrite", content=content, before=sha256_of(path),
                        diff=list(difflib.unified_diff(old.splitlines(), content.splitlines(),
                                                       "current", "planned", lineterm="")))
    else:
        item.update(action="skip", reason="already exists; add --overwrite %s to replace it" % rel)
    plan["items"].append(item)


def add_lines(plan, folder, rel, lines, header=None):
    """Plan to add lines at the end of a file, or to create it. Existing content is never stored."""
    path = os.path.join(folder, rel)
    if not lines:
        return
    body = ([header] if header else []) + lines
    if os.path.lexists(path):
        plan["items"].append({"path": rel, "action": "append", "lines": body, "before": sha256_of(path),
                              "port_file": False})
    else:
        plan["items"].append({"path": rel, "action": "create", "content": "\n".join(body) + "\n", "before": None,
                              "port_file": False})


def plan_gitignore(plan, folder, wanted):
    """wanted: (path, True to keep it out of git, False to keep it in)."""
    present = {l.strip() for l in (read_text(os.path.join(folder, ".gitignore")) or "").splitlines()}
    use_git = in_git(folder)
    lines = []
    for rel, ignore in wanted:
        pattern = rel if ignore else "!" + rel
        if pattern in present or pattern in lines:
            continue
        if use_git and git_ignored(folder, rel) is ignore:
            continue
        lines.append(pattern)
    add_lines(plan, folder, ".gitignore", lines, "# Added by init-project")


def cmd_plan(args):
    folder = project_folder(args.dir)
    clean_plans()
    info = detect(folder)
    tpl = info["template"]
    overwrite = {clean_rel(p) for p in args.overwrite}
    for rel in overwrite:
        if os.path.basename(rel).startswith(".env"):
            raise Stop(2, "Env files are never overwritten: %s" % rel)
    for flag, value in (("--port", args.port), ("--from", args.start), ("--container-port", args.container_port)):
        if value is not None and not 1 <= value <= 65535:
            raise Stop(2, "%s must be between 1 and 65535." % flag)
    assign = args.assign_port or args.port is not None
    if not (args.docker or args.env or assign):
        raise Stop(2, "Nothing to plan: pass --docker, --assign-port, or --env.")
    record = load_record()
    plan = {"version": PLAN_VERSION, "id": secrets.token_hex(4), "folder": folder, "items": [], "port": None,
            "notes": list(info["notes"]), "next": []}
    keep_out = []

    # Env files first, so the compose file can pass their names through to the container.
    groups, templates = [], []
    env_plan = {"items": []}
    if args.env:
        if not info["op"]:
            raise Stop(3, "The 1Password CLI (op) is not installed, so the env files cannot be linked. "
                          "Install it from 1Password, sign in, and run again.")
        if not args.vault:
            raise Stop(2, "--env needs --vault NAME, the 1Password vault that will hold the values.")
        item = args.item or info["name"]
        check_name(args.vault, "vault", "Use the vault's ID from op vault list instead.")
        check_name(item, "item", "Pass --item NAME with another name.")
        envs = info["env_files"]
        if args.env_file:
            wanted = [clean_rel(p) for p in args.env_file]
            unknown = [p for p in wanted if p not in {e["path"] for e in envs}]
            if unknown:
                raise Stop(2, "Not an env file this script reads: %s" % ", ".join(unknown))
            envs = [e for e in envs if e["path"] in wanted]
        empty = [e["path"] for e in envs if not e["names"]]
        if empty:
            plan["notes"].append("Skipped %s: no variables found." % ", ".join(empty))
        envs = [e for e in envs if e["names"]]
        if not envs:
            raise Stop(1, "No env file with variables found. Looked for .env and .env.* in %s and in "
                          "apps/* and packages/*." % folder)
        for e in envs:
            section = section_for(e["path"])
            tpl_rel = e["path"] + ".tpl"
            refs = [(n, reference(args.vault, item, section, n)) for n in e["names"]]
            tpl_path = os.path.join(folder, tpl_rel)
            if os.path.lexists(tpl_path):
                have = set(env_names(tpl_path))
                missing = [env_line(n, r) for n, r in refs if n not in have]
                if missing:
                    add_lines(env_plan, folder, tpl_rel, missing)
                else:
                    env_plan["items"].append({"path": tpl_rel, "action": "skip", "port_file": False,
                                          "reason": "already lists every name in %s" % e["path"]})
            else:
                env_plan["items"].append({"path": tpl_rel, "action": "create", "before": None, "port_file": False,
                                      "content": render_template(e["path"], refs, info["dev_command"])})
            keep_out += [(e["path"], True), (tpl_rel, False)]
            groups.append((e["path"], section, e["names"]))
            templates.append(tpl_rel)
            if e["tracked"]:
                plan["notes"].append("%s is committed to git, so its values are in the git history. Rotate "
                                     "those keys after moving them, and remove the file from git when you are "
                                     "ready (git rm --cached %s)." % (e["path"], shlex.quote(e["path"])))
        plan["env"] = {"vault": args.vault, "item": item, "templates": templates}

    port = service = None
    if args.docker:
        compose_existing = info["files"]["compose"]
        compose_name = compose_existing or "docker-compose.yml"
        ours = compose_existing is None or compose_name in overwrite
        override_existing = info["files"]["override"]
        override_name = override_existing or override_for(compose_name)
        allowed = {"Dockerfile", ".dockerignore", compose_name, override_name}
        stray = sorted(overwrite - allowed)
        if stray:
            raise Stop(2, "--overwrite works only on the files this plan writes (%s), not %s"
                       % (", ".join(sorted(allowed)), ", ".join(stray)))
        # The template files are planned when the compose file is missing or one of them is named in
        # --overwrite. Otherwise the project keeps its own Docker files and gets only the local port.
        templated = ours or bool(overwrite & {"Dockerfile", ".dockerignore"})
        if templated and tpl is None:
            raise Stop(5, "There is no Docker template for a %s project (%s). Templates cover Node and "
                          "Python web apps and Foundry and Hardhat local chains." % (info["kind"], info["reason"]))
        if ours:
            if args.service or args.container_port:
                raise Stop(2, "--service and --container-port are for a compose file the project already has.")
            service, container_port = tpl["service"], tpl["port"]
        else:
            services = compose_services(read_text(os.path.join(folder, compose_name)))
            if not services:
                raise Stop(2, "Cannot find any service in %s." % compose_name)
            if args.service:
                if args.service not in services:
                    raise Stop(2, "%s has no service named %s. Its services: %s"
                               % (compose_name, args.service, ", ".join(services)))
                service = args.service
            elif tpl and tpl["service"] in services:
                service = tpl["service"]
            elif len(services) == 1:
                service = services[0]
            else:
                raise Stop(2, "%s has the services %s. Pass --service NAME for the one that gets the local port."
                           % (compose_name, ", ".join(services)))
            container_port = args.container_port or (tpl["port"] if tpl else None)
            if not container_port:
                raise Stop(2, "Pass --container-port N, the port the %s service listens on in its container." % service)
        fixed = None
        if override_existing and override_name not in overwrite:
            if args.port is not None:
                raise Stop(2, "%s already sets the local port. Add --overwrite %s to change it."
                           % (override_name, override_name))
            found = override_port(read_text(os.path.join(folder, override_name)))
            fixed = (found, override_name) if found else None
        if fixed or not override_existing or override_name in overwrite:
            port, why, check = choose_port(folder, service, args.port, args.start, record, fixed)
            plan["port"] = {"service": service, "port": port, "why": why, "check": check}
        else:
            plan["notes"].append("%s exists and sets no port this script can read, so no port is recorded."
                                 % override_name)
        pass_names = []
        for _, _, names in (g for g in groups if "/" not in g[0]):
            pass_names += [n for n in names if n not in pass_names]
        if templated and tpl["builds"]:
            add_file(plan, folder, "Dockerfile", render_dockerfile(info, tpl["port"]), overwrite)
            add_file(plan, folder, ".dockerignore", render_dockerignore(info), overwrite)
        if ours:
            add_file(plan, folder, compose_name, render_compose(info, service, override_name, pass_names), overwrite)
        if port is not None:
            add_file(plan, folder, override_name, render_override(service, port, container_port), overwrite,
                     port_file=True)
        keep_out.append((override_name, True))
        if not ours and pass_names:
            text = read_text(os.path.join(folder, compose_name)) or ""
            absent = [n for n in pass_names if not re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % n, text)]
            if absent:
                plan["notes"].append("To pass the 1Password values into the container, list these names under "
                                     "environment: in %s: %s" % (compose_name, ", ".join(absent)))
        if port is not None:
            plan["next"].append("Start it with: docker compose up --build")
            plan["next"].append("Then %s: http://localhost:%d" % ("point your tools at" if service == "chain" else "open",
                                                                 port))
    elif assign:
        if overwrite:
            raise Stop(2, "--overwrite applies only to the Docker files of --docker.")
        if args.service or args.container_port:
            raise Stop(2, "--service and --container-port are for --docker.")
        service = tpl["service"] if tpl else "app"
        port, why, check = choose_port(folder, service, args.port, args.start, record)
        plan["port"] = {"service": service, "port": port, "why": why, "check": check}
        hint = port_hint(info, port)
        if hint:
            plan["next"].append("Start it on port %d with: %s" % (port, hint))
    elif overwrite:
        raise Stop(2, "--overwrite applies only to the Docker files of --docker.")

    plan["items"] += env_plan["items"]
    if keep_out:
        plan_gitignore(plan, folder, keep_out)
    if groups:
        plan["next"].append("Put the values into 1Password from your own terminal (bash or zsh). These commands "
                            "read each env file in a subshell and print nothing:")
        plan["next"] += ["  " + line for line in import_commands(folder, args.vault, plan["env"]["item"], groups)]
        plan["next"].append("Then start the app with: op run --env-file %s -- %s" % (templates[0], info["dev_command"]))
        if args.docker and port is not None:
            plan["next"].append("Or in Docker: op run --env-file %s -- docker compose up" % templates[0])
        plan["next"].append("Once that works, the plain env files are no longer needed. They still hold the "
                            "values until you delete them.")

    p = plan["port"]
    port_known = p is None or any(e["folder"] == folder and e["service"] == p["service"] and e["port"] == p["port"]
                                  for e in record)
    clean_plans(folder)
    if not any(i["action"] != "skip" for i in plan["items"]) and port_known:
        print_plan(plan, info)
        print()
        print("Nothing to write: every file and the port are already in place.")
        return 0
    write_private(plan_path(plan["id"]), json.dumps(plan, indent=1) + "\n")
    print_plan(plan, info)
    print()
    print("Nothing has been written. To write these files, run: init_project.py apply %s" % plan["id"])
    return 0


def describe(info):
    parts = [info["kind"]]
    extra = [x for x in (info["framework"] if info["framework"] not in (None, "node") else None,
                         info["package_manager"]) if x]
    if extra:
        parts.append("(%s)" % ", ".join(extra))
    return " ".join(parts)


def print_plan(plan, info):
    print("Plan %s for %s" % (plan["id"], plan["folder"]))
    print("  project  %s, %s" % (info["name"], describe(info)))
    if plan["port"]:
        p = plan["port"]
        print("  port     %d for the %s service (%s)" % (p["port"], p["service"], p["why"]))
    if plan.get("env"):
        print("  1Password vault %s, item %s" % (plan["env"]["vault"], plan["env"]["item"]))
    for item in plan["items"]:
        print()
        if item["action"] == "skip":
            print("[skip] %s: %s" % (item["path"], item["reason"]))
            continue
        if item["action"] == "append":
            print("[append] %s" % item["path"])
            for line in item["lines"]:
                print("    + %s" % line)
            continue
        print("[%s] %s" % (item["action"], item["path"]))
        body = item["diff"] if item["action"] == "overwrite" else item["content"].splitlines()
        for line in body:
            print("    %s" % line if line else "")
    for note in plan["notes"]:
        print()
        print("Note: %s" % note)
    if plan["next"]:
        print()
        print("After writing:")
        for line in plan["next"]:
            print("  %s" % line)


# ------------------------------------------------------------------ apply

def ends_without_newline(path):
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        if f.tell() == 0:
            return False
        f.seek(-1, os.SEEK_END)
        return f.read(1) != b"\n"


def write_item(folder, item):
    path = os.path.join(folder, item["path"])
    parent = os.path.realpath(os.path.dirname(path))
    if parent != folder and not parent.startswith(folder + os.sep):
        raise OSError("it is outside the project folder")
    if item["action"] == "create":
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(item["content"])
    elif item["action"] == "overwrite":
        mode = os.stat(path).st_mode & 0o777
        tmp = path + ".init-project.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(item["content"])
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    elif item["action"] == "append":
        start = "\n" if ends_without_newline(path) else ""
        with open(path, "a", encoding="utf-8") as f:
            f.write(start + "\n".join(item["lines"]) + "\n")


def changed(folder, item):
    """Why an item can no longer be written as planned, or None."""
    path = os.path.join(folder, item["path"])
    if item["action"] == "create":
        return "it was created after the plan" if os.path.lexists(path) else None
    if sha256_of(path) != item["before"]:
        return "it changed after the plan"
    return None


def load_plan(plan_id):
    path = plan_path(plan_id)
    try:
        with open(path, encoding="utf-8") as f:
            plan = json.load(f)
    except FileNotFoundError:
        raise Stop(1, "No plan %s. Plans are removed after a day, after apply or discard, and when a newer plan "
                      "is made for the same folder. Run plan again." % plan_id)
    except (OSError, ValueError):
        raise Stop(2, "Cannot read the plan %s. Run plan again." % plan_id)
    if not isinstance(plan, dict) or plan.get("version") != PLAN_VERSION:
        raise Stop(2, "The plan %s was made by another version. Run plan again." % plan_id)
    return path, plan


def cmd_apply(args):
    clean_plans()
    path, plan = load_plan(args.plan_id)
    folder = plan["folder"]
    if not os.path.isdir(folder):
        os.remove(path)
        raise Stop(1, "The project folder %s is gone." % folder)
    record = load_record()
    skipped = 0
    port = plan.get("port")
    port_problem = None
    if port:
        others = {e["port"] for e in record if not (e["folder"] == folder and e["service"] == port["service"])}
        if port["port"] in others:
            port_problem = "port %d was assigned to another project after the plan" % port["port"]
        elif port["check"] and port_in_use(port["port"]):
            port_problem = "port %d came into use after the plan" % port["port"]
    for item in plan["items"]:
        if item["action"] == "skip":
            print("Kept %s: %s" % (item["path"], item["reason"]))
            continue
        why = changed(folder, item)
        if why is None and item.get("port_file") and port_problem:
            why = port_problem
        if why:
            skipped += 1
            print("Skipped %s: %s. Run plan again to see it." % (item["path"], why))
            continue
        try:
            write_item(folder, item)
        except OSError as e:
            skipped += 1
            print("Skipped %s: %s" % (item["path"], e.strerror or e))
            continue
        print("%s %s" % ("Replaced" if item["action"] == "overwrite" else
                         "Added lines to" if item["action"] == "append" else "Wrote", item["path"]))
    if port:
        if port_problem:
            skipped += 1
            print("Did not record a port: %s. Run plan again to pick another." % port_problem)
        else:
            record = [e for e in record if not (e["folder"] == folder and e["service"] == port["service"])]
            record.append({"folder": folder, "service": port["service"], "port": port["port"]})
            save_record(record)
            print("Recorded port %d for the %s service in %s" % (port["port"], port["service"], record_path()))
    os.remove(path)
    if plan["next"]:
        print()
        print("Next:")
        for line in plan["next"]:
            print("  %s" % line)
    return 4 if skipped else 0


def cmd_discard(args):
    path, _ = load_plan(args.plan_id)
    os.remove(path)
    print("Discarded plan %s. Nothing was written." % args.plan_id)
    return 0


# ------------------------------------------------------------------ other commands

def cmd_detect(args):
    info = detect(project_folder(args.dir))
    if args.json:
        print(json.dumps(info, indent=1))
        return 0
    tpl = info["template"]
    files = info["files"]
    print("folder        %s" % info["folder"])
    print("name          %s" % info["name"])
    print("kind          %s (%s)" % (info["kind"], info["reason"]))
    if info["runtime"] == "node":
        print("runtime       node %d%s, %s%s" % (info["node"], " from " + info["version_from"] if info["version_from"] else "",
                                                 info["package_manager"],
                                                 " from " + info["package_manager_from"] if info["package_manager_from"] else ""))
    elif info["runtime"] == "python":
        print("runtime       python %s%s" % (info["python"], " from " + info["version_from"] if info["version_from"] else ""))
    elif info["runtime"]:
        print("runtime       %s" % info["runtime"])
    if info["framework"] and info["framework"] != "node":
        print("framework     %s" % info["framework"])
    print("dev command   %s%s" % (info["dev_command"], "  (module guessed)" if info["app_module_guessed"] else ""))
    if tpl:
        print("docker        %s template, service %s on port %d in the container" % (tpl["name"], tpl["service"], tpl["port"]))
    else:
        print("docker        no template for this kind of project")
    print("docker files  Dockerfile %s, .dockerignore %s, compose %s, override %s" % (
        "yes" if files["Dockerfile"] else "no", "yes" if files[".dockerignore"] else "no",
        files["compose"] or "none", files["override"] or "none"))
    if info["env_files"]:
        print("env files     %s" % ", ".join("%s (%d name%s%s)" % (e["path"], len(e["names"]),
                                                                      "" if len(e["names"]) == 1 else "s",
                                                                      ", committed to git" if e["tracked"] else "")
                                             for e in info["env_files"]))
    else:
        print("env files     none")
    print("op            %s" % ("installed" if info["op"] else "not installed"))
    print("docker cli    %s" % ("installed" if info["docker"] else "not installed"))
    print("ports         %s" % (", ".join("%d for %s" % (p["port"], p["service"]) for p in info["ports"])
                                or "none assigned yet"))
    for note in info["notes"]:
        print("note          %s" % note)
    return 0


def cmd_ports(args):
    record = load_record()
    if args.forget:
        target = {os.path.realpath(os.path.expanduser(args.forget)), os.path.abspath(os.path.expanduser(args.forget))}
        kept = [e for e in record if e["folder"] not in target]
        if len(kept) == len(record):
            raise Stop(1, "No port is recorded for %s." % args.forget)
        save_record(kept)
        print("Forgot %d port%s for %s." % (len(record) - len(kept), "" if len(record) - len(kept) == 1 else "s",
                                           args.forget))
        return 0
    if not record:
        print("No ports recorded yet.")
        return 0
    for e in sorted(record, key=lambda e: e["port"]):
        print("%5d  %-8s %s%s" % (e["port"], e["service"], e["folder"],
                                  "" if os.path.isdir(e["folder"]) else "  (folder is gone)"))
    return 0


def cmd_wait(args):
    url = "http://127.0.0.1:%d/" % args.port
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    deadline = time.time() + args.timeout
    while True:
        status = None
        try:
            with opener.open(url, timeout=3) as r:
                status = r.status
        except urllib.error.HTTPError as e:
            status = e.code
        except (urllib.error.URLError, http.client.HTTPException, OSError, ValueError):
            status = None
        if status:
            print("http://localhost:%d answered with status %d" % (args.port, status))
            return 0
        if time.time() >= deadline:
            print("http://localhost:%d did not answer within %d seconds" % (args.port, args.timeout), file=sys.stderr)
            return 1
        time.sleep(1)


def main(argv):
    ap = argparse.ArgumentParser(description="Set up a project: detect it, pick a local port, render Docker "
                                             "files, and link env files to 1Password.")
    sub = ap.add_subparsers(dest="command", required=True)
    p = sub.add_parser("detect", help="tell what kind of project the folder is")
    p.add_argument("--dir", default=".")
    p.add_argument("--json", action="store_true")
    p = sub.add_parser("plan", help="show every file that would be written, without writing")
    p.add_argument("--dir", default=".")
    p.add_argument("--docker", action="store_true", help="Dockerfile, .dockerignore, compose file, and local port")
    p.add_argument("--assign-port", action="store_true", help="pick and record a local port without Docker")
    p.add_argument("--port", type=int, help="use this local port")
    p.add_argument("--from", dest="start", type=int, default=DEFAULT_FROM, help="first port to try (default 3100)")
    p.add_argument("--service", help="the service of an existing compose file that gets the port")
    p.add_argument("--container-port", type=int, help="the port that service listens on in its container")
    p.add_argument("--overwrite", action="append", default=[], help="replace this existing Docker file (repeatable)")
    p.add_argument("--env", action="store_true", help="write 1Password references for the env files")
    p.add_argument("--vault", help="the 1Password vault for the values")
    p.add_argument("--item", help="the 1Password item for the values (default: the folder name)")
    p.add_argument("--env-file", action="append", default=[], help="link only this env file (repeatable)")
    for name, helptext in (("apply", "write a plan's files after checking nothing changed"),
                           ("discard", "remove a plan without writing")):
        p = sub.add_parser(name, help=helptext)
        p.add_argument("plan_id")
    p = sub.add_parser("ports", help="list the local ports this script assigned")
    p.add_argument("--forget", metavar="DIR", help="remove the ports recorded for a folder")
    p = sub.add_parser("wait", help="wait until a local port answers HTTP")
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--timeout", type=int, default=30)
    args = ap.parse_args(argv)
    try:
        return {"detect": cmd_detect, "plan": cmd_plan, "apply": cmd_apply, "discard": cmd_discard,
                "ports": cmd_ports, "wait": cmd_wait}[args.command](args)
    except Stop as e:
        print(str(e), file=sys.stderr)
        return e.code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
