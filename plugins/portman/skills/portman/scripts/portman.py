#!/usr/bin/env python3
"""Keep a registry of the localhost ports each project uses, so dev servers never collide.

The registry lives in ~/.local/share/portman/registry.json (or under PORTMAN_HOME), in a folder
readable only by you. The script reads which ports are in use with lsof (or /proc/net on Linux),
docker when it is installed, and a local socket test. It writes nothing outside the registry,
except the files `apply --confirm` writes in the project folder.

Usage:
  portman.py list [--project NAME] [--json]
  portman.py add PROJECT NAME PORT [--service NAME] [--target PORT] [--dir DIR]
  portman.py remove PROJECT [NAME...]                  shows what would be removed
  portman.py remove --confirm PROJECT/NAME=PORT...     removes those entries if they still match
  portman.py check [PORT...]
  portman.py suggest [--from PORT] [--count N] [--allow-common]
  portman.py doctor
  portman.py apply [--project NAME] [--dir DIR] [--confirm TOKEN]

Exit codes: 0 on success, 1 when something is not registered or a request is refused,
2 for bad input or a registry that cannot be read, 3 when an entry or a file changed after the preview.
"""
import argparse
import contextlib
import difflib
import errno
import fcntl
import hashlib
import json
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile

FORMAT_VERSION = 1
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
PROJECT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
SERVICE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
ITEM_RE = re.compile(r"^([A-Za-z0-9][A-Za-z0-9._-]*)/([A-Za-z0-9][A-Za-z0-9_-]*)=([0-9]+)$")
# Suggestions stay below 32768, where the ephemeral ranges of macOS and Linux begin.
SUGGEST_MAX = 32767
# Ports that popular tools take by default. Suggestions skip them unless --allow-common is given.
COMMON_PORTS = {
    1433: "SQL Server",
    3000: "Node.js, React, Next.js, Rails, and Grafana dev servers",
    3001: "a second Node.js dev server",
    3306: "MySQL",
    4000: "Phoenix, Jekyll, and GraphQL dev servers",
    4200: "Angular",
    4321: "Astro",
    5000: "Flask, and AirPlay Receiver on macOS",
    5173: "Vite",
    5174: "a second Vite server",
    5432: "PostgreSQL",
    5672: "RabbitMQ",
    6006: "Storybook",
    6379: "Redis",
    7000: "AirPlay Receiver on macOS",
    8000: "Django, uvicorn, and Python's http.server",
    8008: "alternative HTTP servers",
    8080: "alternative HTTP servers and many proxies",
    8081: "the React Native bundler",
    8443: "alternative HTTPS servers",
    8888: "Jupyter",
    9000: "PHP-FPM, SonarQube, and MinIO",
    9200: "Elasticsearch",
    9229: "the Node.js inspector",
    11211: "Memcached",
    27017: "MongoDB",
}
COMPOSE_FILES = ("compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml")
OVERRIDE_HEADER = "# Written by portman from its registry. portman apply rewrites this file."
ENV_FILE = ".env.local"
ENV_BEGIN = "# >>> portman >>>"
ENV_END = "# <<< portman <<<"
# Programs that forward a container's published port; the container is named instead of them.
DOCKER_FORWARDERS = ("com.docker", "vpnkit", "docker-proxy", "rootlessport", "gvproxy")
LONG_KEYS = ("target", "published", "host_ip", "protocol", "mode", "name", "app_protocol")


class Refused(Exception):
    """A request the script will not carry out. code is the exit code."""

    def __init__(self, message, code=1):
        super().__init__(message)
        self.code = code


def run(cmd, timeout=20):
    """Run cmd and return (exit code, stdout), or (None, "") when it cannot be started."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None, ""
    return r.returncode, r.stdout


def plural(n, one, many):
    return "%d %s" % (n, one if n == 1 else many)


def shown(path):
    """The path as printed: ~ for the home folder, so output shared in a chat carries no account name."""
    home = os.path.expanduser("~").rstrip("/")
    for prefix in (home, os.path.realpath(home)):
        if prefix and (path == prefix or path.startswith(prefix + "/")):
            return "~" + path[len(prefix):]
    return path


# ------------------------------------------------------------------ the registry

def state_home():
    return os.environ.get("PORTMAN_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "portman")


def registry_path():
    return os.path.join(state_home(), "registry.json")


def load_registry():
    """Return the registry. Raises Refused (exit 2) when it cannot be read or its shape is wrong."""
    path = registry_path()
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        return {"version": FORMAT_VERSION, "projects": {}}
    except OSError as e:
        raise Refused("Cannot read %s: %s" % (path, e.strerror), 2)
    try:
        data = json.loads(text)
    except ValueError as e:
        raise Refused("%s is not valid JSON (%s). Fix or move the file, then run again." % (path, e), 2)
    if not isinstance(data, dict) or "version" not in data:
        raise Refused("%s is not a portman registry: it has no version." % path, 2)
    if data["version"] != FORMAT_VERSION:
        raise Refused("%s has format version %r, but this portman reads version %d only."
                      % (path, data["version"], FORMAT_VERSION), 2)
    problems = shape_problems(data)
    if problems:
        raise Refused("%s has entries portman cannot read:\n  %s" % (path, "\n  ".join(problems)), 2)
    return data


def shape_problems(data):
    """List what is wrong with the structure of the registry, for entries edited by hand."""
    projects = data.get("projects")
    if not isinstance(projects, dict):
        return ["projects is not an object"]
    out = []
    for project, info in projects.items():
        if not PROJECT_RE.match(project):
            out.append("project name %r has characters other than letters, digits, '.', '_', and '-'" % project)
        if not isinstance(info, dict) or not isinstance(info.get("ports"), list):
            out.append("%s: ports is not a list" % project)
            continue
        if "dir" in info and not isinstance(info["dir"], str):
            out.append("%s: dir is not a string" % project)
        for e in info["ports"]:
            if not isinstance(e, dict):
                out.append("%s: a port entry is not an object" % project)
                continue
            name, port = e.get("name"), e.get("port")
            if not isinstance(name, str) or not NAME_RE.match(name):
                out.append("%s: port name %r is not valid" % (project, name))
            if not valid_port(port):
                out.append("%s/%s: port %r is not a number from 1 to 65535" % (project, name, port))
            if "service" in e and not (isinstance(e["service"], str) and SERVICE_RE.match(e["service"])):
                out.append("%s/%s: service %r is not valid" % (project, name, e["service"]))
            if "target" in e and not valid_port(e["target"]):
                out.append("%s/%s: target %r is not a number from 1 to 65535" % (project, name, e["target"]))
    return out


def valid_port(value):
    return isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= 65535


def entries(data):
    """Yield (project, entry) in registry order."""
    for project, info in data["projects"].items():
        for e in info["ports"]:
            yield project, e


def env_var(name):
    return "PORT_" + name.upper().replace("-", "_")


def duplicates(data):
    """List ports registered twice, names repeated in a project, and names that give the same variable."""
    out = []
    owners = {}
    for project, e in entries(data):
        owners.setdefault(e["port"], []).append("%s/%s" % (project, e["name"]))
    for port, who in sorted(owners.items()):
        if len(who) > 1:
            out.append("port %d is registered %d times: %s" % (port, len(who), ", ".join(who)))
    for project, info in data["projects"].items():
        names, variables = set(), {}
        for e in info["ports"]:
            if e["name"] in names:
                out.append("%s has the port name %s twice" % (project, e["name"]))
            names.add(e["name"])
            var = env_var(e["name"])
            if var in variables and variables[var] != e["name"]:
                out.append("%s: %s and %s both become %s" % (project, variables[var], e["name"], var))
            variables.setdefault(var, e["name"])
    return out


@contextlib.contextmanager
def locked():
    """Hold the registry lock, so two runs never change the registry at the same time."""
    home = state_home()
    os.makedirs(home, mode=0o700, exist_ok=True)
    os.chmod(home, 0o700)
    fd = os.open(os.path.join(home, "registry.lock"), os.O_RDWR | os.O_CREAT, 0o600)
    try:
        os.fchmod(fd, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def save_registry(data):
    """Replace the registry in one step, readable only by you. Call it while holding locked()."""
    fd, tmp = tempfile.mkstemp(prefix=".registry.", dir=state_home())
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, registry_path())
    except BaseException:
        with contextlib.suppress(OSError):
            os.unlink(tmp)
        raise


# ------------------------------------------------------------------ what is using a port

def probe(port):
    """Return True when something holds the TCP port on this machine, by connecting and binding."""
    # Tests turn the socket test off so that only the stand-ins for lsof and docker decide.
    if os.environ.get("PORTMAN_NO_PROBE") == "1":
        return False
    for host, family in (("127.0.0.1", socket.AF_INET), ("::1", socket.AF_INET6)):
        try:
            s = socket.socket(family, socket.SOCK_STREAM)
        except OSError:
            continue
        s.settimeout(0.5)
        try:
            s.connect((host, port))
            return True
        except socket.timeout:
            return True
        except OSError:
            pass
        finally:
            s.close()
    for host, family in (("0.0.0.0", socket.AF_INET), ("::", socket.AF_INET6)):
        try:
            s = socket.socket(family, socket.SOCK_STREAM)
        except OSError:
            continue
        try:
            if family == socket.AF_INET6:
                s.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
            s.bind((host, port))
        except OSError as e:
            if e.errno == errno.EADDRINUSE:
                return True
            # EACCES for ports below 1024 and EADDRNOTAVAIL without IPv6 say nothing about the port.
        finally:
            s.close()
    return False


class Machine:
    """The listening TCP ports of this machine, read once per run."""

    def __init__(self):
        self.listeners = {}
        self.source = None
        self.docker = "not installed"
        self._cwds = {}
        if not self._read_lsof():
            self._read_proc()
        self._read_docker()

    def _lsof(self):
        return os.environ.get("PORTMAN_LSOF") or shutil.which("lsof")

    def _read_lsof(self):
        lsof = self._lsof()
        if not lsof:
            return False
        code, out = run([lsof, "+c", "0", "-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"])
        # lsof exits 1 with no output when nothing is listening; anything else means it did not work.
        if not (code == 0 or (code == 1 and not out.strip())):
            return False
        pid, command = None, ""
        for line in out.splitlines():
            if line.startswith("p") and line[1:].isdigit():
                pid, command = int(line[1:]), ""
            elif line.startswith("c"):
                command = line[1:]
            elif line.startswith("n") and pid is not None:
                m = re.search(r":(\d+)$", line)
                if m:
                    self._add(int(m.group(1)), {"kind": "process", "pid": pid, "command": command})
        self.source = "lsof"
        return True

    def _read_proc(self):
        base = os.environ.get("PORTMAN_PROC_NET", "/proc/net")
        found = False
        for name in ("tcp", "tcp6"):
            try:
                with open(os.path.join(base, name), encoding="ascii") as f:
                    rows = f.read().splitlines()[1:]
            except OSError:
                continue
            found = True
            for row in rows:
                cols = row.split()
                # State 0A is LISTEN; the local address ends in the port in hexadecimal.
                if len(cols) > 3 and cols[3] == "0A" and ":" in cols[1]:
                    self._add(int(cols[1].rsplit(":", 1)[1], 16), {"kind": "unnamed"})
        if found:
            self.source = "/proc/net"

    def _read_docker(self):
        docker = os.environ.get("PORTMAN_DOCKER") or shutil.which("docker")
        if not docker:
            return
        code, out = run([docker, "ps", "--format", "{{json .}}"], timeout=15)
        if code is None:
            return
        if code != 0:
            self.docker = "not answering"
            return
        self.docker = "running"
        for line in out.splitlines():
            try:
                c = json.loads(line)
            except ValueError:
                continue
            labels = dict(kv.split("=", 1) for kv in (c.get("Labels") or "").split(",") if "=" in kv)
            holder = {"kind": "container", "name": c.get("Names", ""),
                      "compose_project": labels.get("com.docker.compose.project", ""),
                      "working_dir": labels.get("com.docker.compose.project.working_dir", "")}
            for m in re.finditer(r":(\d+)(?:-(\d+))?->[\d-]+/tcp", c.get("Ports") or ""):
                first = int(m.group(1))
                last = int(m.group(2) or first)
                for port in range(first, min(last, first + 1000) + 1):
                    self._add(port, holder)

    def _add(self, port, holder):
        held = self.listeners.setdefault(port, [])
        if holder not in held:
            held.append(holder)

    def holders(self, port):
        """Return who holds the port: [] when it is free, a list of holders when it is in use."""
        held = list(self.listeners.get(port, []))
        if any(h["kind"] == "container" for h in held):
            held = [h for h in held if not (h["kind"] == "process" and h["command"].startswith(DOCKER_FORWARDERS))]
        if held:
            return held
        return [{"kind": "unnamed"}] if probe(port) else []

    def cwd(self, pid):
        """Return the working folder of a process, or None when lsof cannot tell."""
        if pid not in self._cwds:
            self._cwds[pid] = None
            lsof = self._lsof()
            code, out = run([lsof, "-a", "-p", str(pid), "-d", "cwd", "-Fn"]) if lsof else (None, "")
            for line in out.splitlines() if code == 0 else []:
                if line.startswith("n/"):
                    self._cwds[pid] = line[1:]
        return self._cwds[pid]


def describe(holder):
    if holder["kind"] == "process":
        return "pid %d %s" % (holder["pid"], holder["command"] or "(unnamed)")
    if holder["kind"] == "container":
        return "container %s" % holder["name"]
    return "a program that could not be named"


def compose_name(project):
    """The name Docker Compose gives a project folder: lower case letters, digits, '-', and '_'."""
    return re.sub(r"^[^a-z0-9]+", "", re.sub(r"[^a-z0-9_-]", "", project.lower()))


def inside(path, folder):
    path, folder = os.path.realpath(path), os.path.realpath(folder)
    return path == folder or path.startswith(folder.rstrip(os.sep) + os.sep)


def owner(holder, project, info, machine):
    """Return 'this project', 'another program', or 'unclear' for a holder of one of project's ports."""
    folder = info.get("dir")
    if holder["kind"] == "container":
        if holder["compose_project"] and holder["compose_project"] == compose_name(project):
            return "this project"
        if holder["working_dir"] and folder and inside(holder["working_dir"], folder):
            return "this project"
        return "another program" if holder["compose_project"] else "unclear"
    if holder["kind"] == "process" and folder:
        cwd = machine.cwd(holder["pid"])
        if cwd:
            return "this project" if inside(cwd, folder) else "another program"
    return "unclear"


def state_text(holders, project=None, info=None, machine=None):
    if not holders:
        return "free"
    parts = []
    for h in holders:
        text = describe(h)
        if project is not None:
            who = owner(h, project, info, machine)
            if who != "unclear":
                text += " (%s)" % who
        parts.append(text)
    return "in use: " + "; ".join(parts)


def find_free(start, data, machine, count, allow_common=False, skip=()):
    """Return up to count ports from start upward that are not registered, not in use, and not common."""
    registered = {e["port"] for _, e in entries(data)} | set(skip)
    found = []
    port = max(start, 1024)
    while port <= SUGGEST_MAX and len(found) < count:
        if port not in registered and (allow_common or port not in COMMON_PORTS) and not machine.holders(port):
            found.append(port)
        port += 1
    return found


# ------------------------------------------------------------------ list, add, remove, check, suggest

def print_rows(header, rows):
    widths = [max([len(header[i])] + [len(r[i]) for r in rows]) for i in range(len(header) - 1)]
    fmt = "  ".join("%%-%ds" % w for w in widths) + "  %s"
    print((fmt % header).rstrip())
    for r in rows:
        print((fmt % r).rstrip())


def cmd_list(args):
    data = load_registry()
    projects = data["projects"]
    if args.project and args.project not in projects:
        raise Refused("No ports are registered for %s." % args.project)
    if not any(True for _ in entries(data)):
        raise Refused("The registry is empty. Register a port with: portman.py add <project> <name> <port>")
    machine = Machine()
    rows = []
    for project, e in entries(data):
        if args.project and project != args.project:
            continue
        info = projects[project]
        holders = machine.holders(e["port"])
        if args.json:
            print(json.dumps({"project": project, "name": e["name"], "port": e["port"], "variable": env_var(e["name"]),
                              "service": e.get("service"), "target": e.get("target"), "dir": info.get("dir"),
                              "state": "in use" if holders else "free",
                              "holders": [dict(h, owner=owner(h, project, info, machine)) for h in holders]},
                             ensure_ascii=False))
        else:
            rows.append((project, e["name"], str(e["port"]), state_text(holders, project, info, machine)))
    if not args.json:
        print_rows(("project", "name", "port", "state"), rows)
    return 0


def check_port_arg(value, what="port"):
    if not re.match(r"^[0-9]{1,5}$", value or "") or not 1 <= int(value) <= 65535:
        raise Refused("%s must be a number from 1 to 65535, not %r" % (what, value), 2)
    return int(value)


def cmd_add(args):
    if not PROJECT_RE.match(args.project):
        raise Refused("Project names use letters, digits, '.', '_', and '-', and start with a letter or digit.", 2)
    if not NAME_RE.match(args.name):
        raise Refused("Port names use letters, digits, '_', and '-', and start with a letter or digit.", 2)
    port = check_port_arg(args.port)
    entry = {"name": args.name, "port": port}
    if args.service:
        if not SERVICE_RE.match(args.service):
            raise Refused("Service names use letters, digits, '.', '_', and '-'.", 2)
        entry["service"] = args.service
    if args.target:
        entry["target"] = check_port_arg(args.target, "--target")
    folder = None
    if args.dir:
        folder = os.path.realpath(os.path.expanduser(args.dir))
        if not os.path.isdir(folder):
            raise Refused("%s is not a folder." % args.dir, 2)
    with locked():
        data = load_registry()
        for project, e in entries(data):
            if e["port"] == port:
                raise Refused("Port %d is already registered to %s/%s." % (port, project, e["name"]))
        info = data["projects"].setdefault(args.project, {"ports": []})
        for e in info["ports"]:
            if e["name"] == args.name:
                raise Refused("%s already has a port named %s (%d). Remove it first to change it."
                              % (args.project, args.name, e["port"]))
            if env_var(e["name"]) == env_var(args.name):
                raise Refused("%s and %s would both become %s. Pick another name."
                              % (e["name"], args.name, env_var(args.name)))
        info["ports"].append(entry)
        if folder:
            info["dir"] = folder
        save_registry(data)
    print("Registered %s/%s=%d" % (args.project, args.name, port))
    if folder:
        print("Recorded %s as the folder of %s" % (shown(folder), args.project))
    if port in COMMON_PORTS:
        print("Note: %d is the default port of %s, so other tools may try to use it." % (port, COMMON_PORTS[port]))
    if port < 1024:
        print("Note: ports below 1024 need administrator rights on most systems.")
    holders = Machine().holders(port)
    if holders:
        print("Note: port %d is in use right now by %s." % (port, "; ".join(describe(h) for h in holders)))
    return 0


def cmd_remove(args):
    if args.confirm:
        if args.project:
            raise Refused("Pass either PROJECT [NAME...] to preview, or --confirm items, not both.", 2)
        return remove_confirmed(args.confirm)
    if not args.project:
        raise Refused("Name the project whose ports to remove.", 2)
    data = load_registry()
    info = data["projects"].get(args.project)
    if info is None:
        raise Refused("No ports are registered for %s." % args.project)
    items = []
    for name in args.names or [e["name"] for e in info["ports"]]:
        e = next((e for e in info["ports"] if e["name"] == name), None)
        if e is None:
            raise Refused("%s has no port named %s." % (args.project, name))
        items.append("%s/%s=%d" % (args.project, name, e["port"]))
    print("Would remove from the registry:")
    for item in items:
        print("  " + item)
    print("Nothing was changed. To remove them, run:")
    print("  portman.py remove " + " ".join("--confirm " + i for i in items))
    return 0


def remove_confirmed(items):
    parsed = []
    for item in items:
        m = ITEM_RE.match(item)
        if not m:
            raise Refused("%r is not in the form PROJECT/NAME=PORT, as the preview prints it." % item, 2)
        parsed.append((m.group(1), m.group(2), int(m.group(3)), item))
    skipped = 0
    with locked():
        data = load_registry()
        changed = False
        for project, name, port, item in parsed:
            info = data["projects"].get(project)
            e = next((e for e in info["ports"] if e["name"] == name), None) if info else None
            if e is None:
                print("skipped %s: no longer registered" % item)
                skipped += 1
            elif e["port"] != port:
                print("skipped %s: now registered as %d" % (item, e["port"]))
                skipped += 1
            else:
                info["ports"].remove(e)
                changed = True
                print("removed %s" % item)
                if not info["ports"]:
                    del data["projects"][project]
                    print("%s has no ports left and is no longer in the registry" % project)
        if changed:
            save_registry(data)
    return 3 if skipped else 0


def cmd_check(args):
    data = load_registry()
    machine = Machine()
    registered = {e["port"]: "%s/%s" % (p, e["name"]) for p, e in entries(data)}
    if not args.ports:
        rows = []
        for project, e in entries(data):
            holders = machine.holders(e["port"])
            if holders:
                info = data["projects"][project]
                rows.append(("%s/%s" % (project, e["name"]), str(e["port"]), state_text(holders, project, info, machine)))
        if rows:
            print_rows(("entry", "port", "state"), rows)
        else:
            print("No registered port is in use right now.")
        return 0
    ports = [check_port_arg(value) for value in args.ports]
    for port in ports:
        parts = [state_text(machine.holders(port))]
        if port in registered:
            parts.append("registered to %s" % registered[port])
        if port in COMMON_PORTS:
            parts.append("the default port of %s" % COMMON_PORTS[port])
        if port < 1024:
            parts.append("needs administrator rights on most systems")
        print("%-6d %s" % (port, "; ".join(parts)))
    return 0


def cmd_suggest(args):
    start = check_port_arg(args.start, "--from")
    if start > SUGGEST_MAX:
        raise Refused("Suggestions stay at or below %d, where the ephemeral ports begin." % SUGGEST_MAX, 2)
    if not 1 <= args.count <= 50:
        raise Refused("--count must be from 1 to 50.", 2)
    data = load_registry()
    found = find_free(start, data, Machine(), args.count, args.allow_common)
    if not found:
        raise Refused("No free port from %d to %d." % (max(start, 1024), SUGGEST_MAX))
    what = "not registered and not in use" if args.allow_common else "not registered, not in use, and not a common default"
    print("Free ports from %d (%s):" % (max(start, 1024), what))
    for port in found:
        print("  %d" % port)
    return 0


# ------------------------------------------------------------------ doctor

def cmd_doctor(args):
    path = registry_path()
    data = load_registry()
    machine = Machine()
    exists = os.path.exists(path)
    print("Registry    %s, %s, %s%s" % (shown(path), plural(len(data["projects"]), "project", "projects"),
                                       plural(sum(1 for _ in entries(data)), "port", "ports"),
                                       "" if exists else " (not created yet)"))
    problems = 0
    if exists:
        for p, want in ((state_home(), 0o700), (path, 0o600)):
            if os.stat(p).st_mode & 0o777 != want:
                print("Permissions %s can be read by others; run: chmod %o %s" % (shown(p), want, shown(p)))
                problems += 1
    if machine.source == "lsof":
        print("Listeners   read with lsof, which names only your own programs; other ports are tested one by one")
    elif machine.source:
        print("Listeners   read from %s, which does not name the programs" % machine.source)
    else:
        print("Listeners   unknown: neither lsof nor /proc/net is available, so only registered ports are tested")
    print("Docker      %s" % {"running": "running", "not answering": "installed but not answering (is it started?)",
                              "not installed": "not installed (optional)"}[machine.docker])

    dups = duplicates(data)
    print()
    print("[Duplicates] %s" % (len(dups) or "none"))
    for d in dups:
        print("  " + d)
    problems += len(dups)

    others, unclear, own = [], [], []
    offered = set()
    for project, e in entries(data):
        holders = machine.holders(e["port"])
        if not holders:
            continue
        info = data["projects"][project]
        kinds = {owner(h, project, info, machine) for h in holders}
        line = "%s/%s  %d  %s" % (project, e["name"], e["port"], "; ".join(describe(h) for h in holders))
        if "another program" in kinds:
            free = find_free(e["port"] + 1, data, machine, 1, skip=offered)
            offered.update(free)
            others.append(line + (". Free instead: %d" % free[0] if free else ""))
        elif "unclear" in kinds:
            unclear.append(line + ("" if info.get("dir") else ". No folder is recorded for %s" % project))
        else:
            own.append(line)
    problems += len(others)
    for title, lines, always in (("Collisions", others, True), ("In use, owner unclear", unclear, False),
                                 ("In use by its own project", own, False)):
        if lines or always:
            print()
            print("[%s] %s" % (title, len(lines) or "none"))
            for line in lines:
                print("  " + line)

    # A project whose folder is gone, such as a removed git worktree, still holds its ports.
    gone = ["%s/%s  %d  %s" % (project, e["name"], e["port"], shown(data["projects"][project]["dir"]))
            for project, e in entries(data)
            if data["projects"][project].get("dir") and not os.path.isdir(data["projects"][project]["dir"])]
    if gone:
        print()
        print("[Folders gone] %d. Remove them with: portman.py remove PROJECT" % len(gone))
        for line in gone:
            print("  " + line)
    problems += len(gone)

    registered = {e["port"] for _, e in entries(data)}
    loose = sorted(p for p in machine.listeners if p not in registered and 1024 <= p <= SUGGEST_MAX)
    print()
    if machine.source is None:
        print("[Unregistered] unknown for programs, because lsof and /proc/net are not available%s"
              % ("; containers below" if loose else ""))
    else:
        print("[Unregistered] %s" % (plural(len(loose), "port", "ports") + " in use outside the registry" if loose else "none"))
    for port in loose:
        print("  %-6d %s" % (port, "; ".join(describe(h) for h in machine.holders(port))))
    print()
    print("No problems found." if not problems else "%s found." % plural(problems, "problem", "problems"))
    return 0


# ------------------------------------------------------------------ reading a Compose file

def strip_comment(line):
    out, quote = [], None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            break
        out.append(ch)
    return "".join(out).rstrip()


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def split_colons(value):
    """Split on ':' outside ${...}, so "${WEB_PORT:-3000}:3000" stays two parts."""
    parts, depth, current = [], 0, ""
    for ch in value:
        depth += {"{": 1, "}": -1}.get(ch, 0)
        if ch == ":" and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += ch
    return parts + [current]


def parse_short(text):
    """Parse a short-syntax port such as "127.0.0.1:3000:3000/tcp", or return None when it is not one."""
    value, protocol = unquote(text), None
    if re.search(r"/(tcp|udp|sctp)$", value):
        value, protocol = value.rsplit("/", 1)
    parts = split_colons(value)
    if not parts[-1].isdigit():
        return None
    published = parts[-2] if len(parts) >= 2 else None
    if published is not None and re.match(r"^[0-9]+-[0-9]+$", published):
        return None
    return {"ip": ":".join(parts[:-2]) if len(parts) >= 3 else None, "published": published,
            "target": int(parts[-1]), "protocol": protocol, "long": None}


def parse_long(fields):
    fields = {k: unquote(v) for k, v in fields.items()}
    if not fields.get("target", "").isdigit():
        return None
    published = fields.get("published")
    if published is not None and re.match(r"^[0-9]+-[0-9]+$", published):
        return None
    return {"ip": fields.get("host_ip"), "published": published, "target": int(fields["target"]),
            "protocol": fields.get("protocol"), "long": fields}


def read_compose(path):
    """Return {service: {"ports": [mapping], "readable": bool}} from a Compose file.

    It reads the common layout: a top-level `services:` key, one key per service, and each service's
    `ports:` list in short, flow, or long syntax. A service that uses anchors, `<<` merges, `extends`,
    port ranges, tabs, or a layout it does not know is marked unreadable, and apply leaves it alone.
    """
    with open(path, encoding="utf-8") as f:
        raw_lines = f.read().splitlines()
    lines = []
    for line in raw_lines:
        text = strip_comment(line)
        if text.strip():
            lead = text[:len(text) - len(text.lstrip(" \t"))]
            lines.append((len(lead), text.strip(), "\t" in lead))
    start = next((k for k, (ind, text, _) in enumerate(lines) if ind == 0 and text == "services:"), None)
    if start is None:
        return {}
    blocks, service_indent = [], None
    for ind, text, tab in lines[start + 1:]:
        if ind == 0:
            break
        if service_indent is None:
            service_indent = ind
        if ind <= service_indent:
            m = re.match(r"^[\"']?([A-Za-z0-9._-]+)[\"']?\s*:\s*(.*)$", text)
            blocks.append({"name": m.group(1) if m else None, "rest": m.group(2) if m else text, "body": [], "tab": tab})
        elif blocks:
            blocks[-1]["body"].append((ind, text))
            blocks[-1]["tab"] = blocks[-1]["tab"] or tab
    services = {}
    for b in blocks:
        if b["name"] is None:
            continue
        readable = not b["tab"] and (b["rest"] in ("", "{}") or b["rest"].startswith("&"))
        svc = services[b["name"]] = {"ports": [], "readable": readable}
        body = b["body"]
        child = body[0][0] if body else None
        j = 0
        while j < len(body):
            ind, text = body[j]
            j += 1
            if ind != child:
                continue
            key, _, value = text.partition(":")
            key, value = key.strip().strip("\"'"), value.strip()
            if key in ("<<", "extends"):
                svc["readable"] = False
            if key == "ports":
                items = []
                while j < len(body) and (body[j][0] > child or (body[j][0] == child and body[j][1].startswith("-"))):
                    items.append(body[j])
                    j += 1
                ports = parse_ports(value, items)
                if ports is None:
                    svc["readable"] = False
                else:
                    svc["ports"] = ports
    return services


def parse_ports(value, items):
    """Parse the value of a `ports:` key and the lines below it, or return None when it cannot."""
    if value.startswith("["):
        if not value.endswith("]") or items:
            return None
        out = []
        for part in re.findall(r"\"[^\"]*\"|'[^']*'|[^,\s][^,]*", value[1:-1]):
            m = parse_short(part.strip())
            if m is None:
                return None
            out.append(m)
        return out
    if value:
        return None
    found, current, item_indent = [], None, items[0][0] if items else 0
    for ind, text in items:
        if ind == item_indent and (text == "-" or text.startswith("- ")):
            if current is not None:
                found.append(current)
            content = text[1:].strip()
            key, sep, rest = content.partition(":")
            if sep and key.strip() in LONG_KEYS and (rest == "" or rest.startswith(" ")):
                current = ("long", {key.strip(): rest.strip()})
            elif not content or content.startswith(("*", "&", "!")):
                return None
            else:
                current = ("short", parse_short(content))
                if current[1] is None:
                    return None
        elif current is not None and current[0] == "long" and ind > item_indent:
            key, sep, rest = text.partition(":")
            if not sep or key.strip() not in LONG_KEYS:
                return None
            current[1][key.strip()] = rest.strip()
        else:
            return None
    if current is not None:
        found.append(current)
    out = []
    for kind, fields in found:
        m = parse_long(fields) if kind == "long" else fields
        if m is None:
            return None
        out.append(m)
    return out


# ------------------------------------------------------------------ apply

def yaml_scalar(value):
    return value if re.match(r"^[A-Za-z0-9._/-]+$", value) else json.dumps(value)


def mapping_lines(m, published):
    """Return the YAML lines of one port mapping, with its host port set to published when given."""
    if m["long"] is not None and any(k in m["long"] for k in ("mode", "name", "app_protocol")):
        fields = dict(m["long"])
        if published is not None:
            fields["published"] = str(published)
        keys = [k for k in LONG_KEYS if k in fields]
        values = [json.dumps(fields[k]) if k == "published" else yaml_scalar(fields[k]) for k in keys]
        return ["      - %s: %s" % (keys[0], values[0])] + ["        %s: %s" % kv for kv in zip(keys[1:], values[1:])]
    host = str(published) if published is not None else m["published"]
    text = str(m["target"])
    if host is not None:
        text = "%s:%s" % (host, text)
    if m["ip"] is not None:
        text = "%s:%s" % (m["ip"], text)
    if m["protocol"]:
        text += "/" + m["protocol"]
    return ["      - %s" % json.dumps(text)]


def plan_override(data, project, services):
    """Return (YAML text or None, notes) for the ports of project in the Compose services."""
    notes = []
    by_service = {}
    for e in data["projects"][project]["ports"]:
        svc = e.get("service") or e["name"]
        if svc not in services:
            notes.append("The Compose file has no service named %s, so %s/%s goes only to %s"
                         % (svc, project, e["name"], ENV_FILE))
            continue
        by_service.setdefault(svc, []).append(e)
    out = []
    for svc, regs in by_service.items():
        base = services[svc]
        if not base["readable"]:
            notes.append("The ports of service %s use a layout portman does not read (anchors, merges, extends, "
                         "port ranges, or tabs), so it is left alone. Edit its ports by hand" % svc)
            continue
        tcp = [m for m in base["ports"] if (m["protocol"] or "tcp") == "tcp"]
        wanted = {}
        for e in regs:
            target = e.get("target") or (tcp[0]["target"] if len(tcp) == 1 else None)
            if target is None:
                notes.append("Service %s publishes %s, so portman cannot tell which container port %s/%s is. "
                             "Remove it and add it again with --target"
                             % (svc, "no ports" if not tcp else "%d ports" % len(tcp), project, e["name"]))
            elif target in wanted:
                notes.append("%s/%s and %s/%s both point at container port %d of %s, so only %s is used"
                             % (project, wanted[target]["name"], project, e["name"], target, svc, wanted[target]["name"]))
            else:
                wanted[target] = e
        if not wanted:
            continue
        lines, used = [], set()
        for m in base["ports"]:
            e = wanted.get(m["target"]) if (m["protocol"] or "tcp") == "tcp" else None
            if e is not None and m["target"] not in used:
                used.add(m["target"])
                lines += mapping_lines(m, e["port"])
            else:
                lines += mapping_lines(m, None)
        for target, e in wanted.items():
            if target not in used:
                lines += mapping_lines({"ip": None, "published": None, "target": target, "protocol": None,
                                        "long": None}, e["port"])
        # Compose adds the ports of an override to the Compose file's ports; !override replaces them instead.
        out += ["  %s:" % svc, "    ports: !override" if base["ports"] else "    ports:"] + lines
    if not out:
        return None, notes
    return "\n".join([OVERRIDE_HEADER, "services:"] + out) + "\n", notes


def env_block(data, project):
    """Return the lines of the portman block and the port PORT is set to."""
    ports = data["projects"][project]["ports"]
    main = next((e for e in ports if e["name"] == "app"), ports[0])
    lines = [ENV_BEGIN, "PORT=%d" % main["port"]] + ["%s=%d" % (env_var(e["name"]), e["port"]) for e in ports] + [ENV_END]
    return lines, main["port"]


def plan_env(text, data, project):
    """Return (new text, notes) for the env file, changing only the lines between the portman markers."""
    block, _ = env_block(data, project)
    if text is None:
        return "\n".join(block) + "\n", []
    lines = text.splitlines(True)
    begins = [i for i, l in enumerate(lines) if l.rstrip("\r\n") == ENV_BEGIN]
    ends = [i for i, l in enumerate(lines) if l.rstrip("\r\n") == ENV_END]
    if len(begins) > 1 or len(ends) > 1 or len(begins) != len(ends) or (begins and ends[0] < begins[0]):
        raise Refused("%s has an incomplete or repeated portman block (the lines %s and %s). "
                      "Fix it by hand, then run again." % (ENV_FILE, ENV_BEGIN, ENV_END))
    new_block = [l + "\n" for l in block]
    if begins:
        before, after = lines[:begins[0]], lines[ends[0] + 1:]
    else:
        before, after = list(lines), []
        if before and not before[-1].endswith("\n"):
            before[-1] += "\n"
        if before and before[-1].strip():
            before.append("\n")
    names = {l.split("=", 1)[0] for l in block[1:-1]}
    notes = []
    for first, part in ((1, before), (len(before) + len(new_block) + 1, after)):
        for n, line in enumerate(part, first):
            m = re.match(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
            if m and m.group(1) in names:
                notes.append("Line %d of %s also sets %s, outside the portman block. portman leaves that line "
                             "as it is; remove it if the registered port should win" % (n, ENV_FILE, m.group(1)))
    return "".join(before + new_block + after), notes


def git_ignored(folder, name):
    """True when git ignores the file, False when it does not, None outside a git repository."""
    code, _ = run(["git", "-C", folder, "check-ignore", "-q", "--", name], timeout=10)
    return {0: True, 1: False}.get(code)


def compose_version_note(text):
    """A note when the installed Docker Compose is too old to read !override, or None."""
    if "!override" not in text:
        return None
    docker = os.environ.get("PORTMAN_DOCKER") or shutil.which("docker")
    if not docker:
        return None
    code, out = run([docker, "compose", "version", "--short"], timeout=15)
    m = re.match(r"^v?(\d+)\.(\d+)", out.strip()) if code == 0 else None
    if m and (int(m.group(1)), int(m.group(2))) < (2, 24):
        return ("Docker Compose %s does not read !override, which makes the override replace the ports of the "
                "Compose file instead of adding to them. It needs version 2.24 or later" % out.strip())
    return None


def project_folder(given):
    if given:
        folder = os.path.expanduser(given)
        if not os.path.isdir(folder):
            raise Refused("%s is not a folder." % given, 2)
        return os.path.realpath(folder)
    code, out = run(["git", "rev-parse", "--show-toplevel"], timeout=10)
    return os.path.realpath(out.strip() if code == 0 and out.strip() else os.getcwd())


def read_bytes(path):
    try:
        with open(path, "rb") as f:
            return f.read()
    except FileNotFoundError:
        return None


def indent(text):
    return "\n".join("      " + l for l in text.rstrip("\n").split("\n"))


def plan_apply(data, args):
    """Return (project, folder, changes, notes, main port). changes is [(path, old bytes or None, new text)]."""
    folder = project_folder(args.dir)
    project = args.project or next((p for p, i in data["projects"].items()
                                    if i.get("dir") and os.path.realpath(i["dir"]) == folder), os.path.basename(folder))
    if not data["projects"].get(project, {}).get("ports"):
        raise Refused("No ports are registered for %s. Register them with: portman.py add %s <name> <port> --dir %s"
                      % (project, project, shown(folder)))
    planned, notes = [], []
    env_path = os.path.realpath(os.path.join(folder, ENV_FILE))
    old = read_bytes(env_path)
    text, env_notes = plan_env(None if old is None else old.decode("utf-8", "replace"), data, project)
    planned.append((env_path, old, text))
    notes += env_notes
    base = next((n for n in COMPOSE_FILES if os.path.isfile(os.path.join(folder, n))), None)
    if base:
        stem, ext = os.path.splitext(base)
        name = stem + ".override" + ext
        path = os.path.join(folder, name)
        text, compose_notes = plan_override(data, project, read_compose(os.path.join(folder, base)))
        notes += compose_notes
        others = [n for n in (os.path.splitext(c)[0] + ".override" + os.path.splitext(c)[1] for c in COMPOSE_FILES)
                  if n != name and os.path.exists(os.path.join(folder, n))]
        old = read_bytes(path)
        if text and old is not None and not old.decode("utf-8", "replace").startswith(OVERRIDE_HEADER):
            notes.append("%s exists and was not written by portman, so it is left as it is. Add these lines to it by hand:\n%s"
                         % (name, indent(text)))
        elif text and others:
            notes.append("%s exists, so portman does not add %s. Add these lines to %s by hand:\n%s"
                         % (others[0], name, others[0], indent(text)))
        elif text:
            planned.append((os.path.realpath(path), old, text))
            note = compose_version_note(text)
            if note:
                notes.append(note)
    changes = [(p, old, text) for p, old, text in planned if old is None or old.decode("utf-8", "replace") != text]
    for path, _, _ in changes:
        rel = os.path.relpath(path, folder)
        if git_ignored(folder, rel) is False:
            notes.append("%s is not ignored by git, or is already committed. Add it to .gitignore so the ports "
                         "of this machine stay out of commits" % rel)
    _, main_port = env_block(data, project)
    return project, folder, changes, notes, main_port


def token_of(folder, project, changes):
    """A short fingerprint of the planned change and the files it starts from."""
    h = hashlib.sha256(json.dumps([folder, project]).encode())
    for path, old, text in changes:
        h.update(json.dumps([path, None if old is None else old.hex(), text]).encode())
    return h.hexdigest()[:12]


def write_file(path, text):
    """Replace path in one step, keeping its permissions, or create it readable only by you."""
    mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o600
    fd, tmp = tempfile.mkstemp(prefix=".portman.", dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(OSError):
            os.unlink(tmp)
        raise


def cmd_apply(args):
    if args.confirm:
        # Plan again under the lock, and write only when the plan and the files are what the preview showed.
        with locked():
            data = load_registry()
            project, folder, changes, notes, main_port = plan_apply(data, args)
            if not changes:
                print("Nothing to change: the files in %s already have the ports of %s." % (shown(folder), project))
                return 0
            if token_of(folder, project, changes) != args.confirm:
                raise Refused("The registry or the files changed after the preview, so nothing was written. "
                              "Run apply without --confirm to see the change again.", 3)
            for path, _, text in changes:
                write_file(path, text)
                print("Wrote %s" % os.path.relpath(path, folder))
            if data["projects"][project].get("dir") != folder:
                data["projects"][project]["dir"] = folder
                save_registry(data)
                print("Recorded %s as the folder of %s" % (shown(folder), project))
        print("Open http://localhost:%d" % main_port)
        return 0
    data = load_registry()
    project, folder, changes, notes, main_port = plan_apply(data, args)
    print("Project %s, folder %s" % (project, shown(folder)))
    if not changes:
        print("Nothing to change: the files already have the ports of %s." % project)
    for path, old, text in changes:
        rel = os.path.relpath(path, folder)
        print()
        print("%s (%s)" % (rel, "new file" if old is None else "changed"))
        before = [] if old is None else old.decode("utf-8", "replace").splitlines()
        # No context lines: the lines around the portman block may hold secrets, and only changed lines are shown.
        for line in difflib.unified_diff(before, text.splitlines(), rel, rel + " after apply", lineterm="", n=0):
            print("  " + line)
    if notes:
        print()
        print("Notes:")
        for n in notes:
            print("  - " + n)
    if changes:
        print()
        print("Nothing was written. To write these changes, run:")
        # The folder may be printed with ~ and quoted; --dir expands ~ itself, so the command works either way.
        print("  portman.py apply --project %s --dir %s --confirm %s"
              % (project, shlex.quote(shown(folder)), token_of(folder, project, changes)))
    return 0


# ------------------------------------------------------------------ main

def main(argv):
    ap = argparse.ArgumentParser(description="Keep a registry of the localhost ports each project uses.")
    sub = ap.add_subparsers(dest="command")
    p = sub.add_parser("list", help="show every registered port and whether it is in use right now")
    p.add_argument("--project", help="only this project")
    p.add_argument("--json", action="store_true", help="print one JSON object per port")
    p = sub.add_parser("add", help="register a port for a project")
    p.add_argument("project")
    p.add_argument("name", help="what the port is for, such as app, api, or db; it becomes PORT_<NAME>")
    p.add_argument("port")
    p.add_argument("--service", help="the Compose service that publishes it, when it is not named like the port")
    p.add_argument("--target", help="the port inside the container, when the Compose file does not tell")
    p.add_argument("--dir", help="the project folder, so a server running there counts as the project's own")
    p = sub.add_parser("remove", help="remove ports from the registry, after a preview")
    p.add_argument("project", nargs="?")
    p.add_argument("names", nargs="*")
    p.add_argument("--confirm", action="append", default=[], metavar="PROJECT/NAME=PORT",
                   help="an entry printed by the preview; removed only if it still matches")
    p = sub.add_parser("check", help="show what holds ports right now")
    p.add_argument("ports", nargs="*")
    p = sub.add_parser("suggest", help="find free ports that are not registered and not a common default")
    p.add_argument("--from", dest="start", default="3000")
    p.add_argument("--count", type=int, default=5)
    p.add_argument("--allow-common", action="store_true", help="also suggest ports such as 3000, 5173, 8000, and 8080")
    sub.add_parser("doctor", help="find duplicates, collisions, and ports used by programs outside the registry")
    p = sub.add_parser("apply", help="write the project's ports to its env file and Compose override, after a preview")
    p.add_argument("--project")
    p.add_argument("--dir")
    p.add_argument("--confirm", metavar="TOKEN", help="the token the preview printed")
    args = ap.parse_args(argv)
    if args.command is None:
        args = ap.parse_args(["list"])
    commands = {"list": cmd_list, "add": cmd_add, "remove": cmd_remove, "check": cmd_check,
                "suggest": cmd_suggest, "doctor": cmd_doctor, "apply": cmd_apply}
    try:
        return commands[args.command](args)
    except Refused as e:
        print(str(e), file=sys.stderr)
        return e.code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
