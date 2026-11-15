"""Writes the state an eval case starts from into the run's workspace and HOME.

Usage: python3 _fixture.py <mode>

Every mode writes a small shop project, outside git, with package.json and a compose.yaml whose
service web publishes 3000:3000. The run's HOME is a temporary folder, so the registry goes to its
~/.local/share/portman/. The modes:

  plain       nothing more: the registry stays empty
  registered  shop/web=4417 in the registry, with the workspace as its folder
  env         registered, and a .env.local with two lines of the project's own
  broken      env, with a portman block that has its first line and not its last
  gone        registered, and oldshop/web=4520, whose folder no longer exists
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "skills", "portman", "scripts", "portman.py")

PACKAGE = '{\n  "name": "shop",\n  "private": true,\n  "scripts": {\n    "dev": "next dev"\n  }\n}\n'
COMPOSE = 'services:\n  web:\n    build: .\n    ports:\n      - "3000:3000"\n'
ENV = "NEXT_PUBLIC_SHOP_NAME=Corner Shop\nSHOP_COUPON_CODE=canary-corner-1923\n"
BROKEN = "\n# >>> portman >>>\nPORT=4417\n"


def write(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def add(project, name, port, folder):
    # Registers with the plugin's own script. The fixture reads nothing from this machine: no socket
    # test, no lsof, no docker, so what runs on the user's machine does not change the starting state.
    env = {k: v for k, v in os.environ.items() if not k.startswith("PORTMAN_")}
    env.update(PORTMAN_NO_PROBE="1", PORTMAN_LSOF="/nonexistent/lsof", PORTMAN_DOCKER="/nonexistent/docker",
               PORTMAN_PROC_NET="/nonexistent/net")
    subprocess.run([sys.executable, SCRIPT, "add", project, name, str(port), "--dir", folder],
                   check=True, env=env, stdout=subprocess.DEVNULL)


def main(mode):
    if mode not in ("plain", "registered", "env", "broken", "gone"):
        sys.exit("unknown mode: " + mode)
    write("package.json", PACKAGE)
    write("compose.yaml", COMPOSE)
    if mode == "plain":
        return
    add("shop", "web", 4417, os.getcwd())
    if mode in ("env", "broken"):
        write(".env.local", ENV + (BROKEN if mode == "broken" else ""))
    if mode == "gone":
        old = os.path.join(os.path.expanduser("~"), "projects", "oldshop")
        os.makedirs(old, exist_ok=True)
        add("oldshop", "web", 4520, old)
        shutil.rmtree(old)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "plain")
