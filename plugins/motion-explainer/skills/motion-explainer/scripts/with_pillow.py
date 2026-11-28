"""Runs a script of the skill again through uv with Pillow, unless it already runs that way.

build.py and capture.py cut and shrink pictures with Pillow. uv fetches Pillow at the pinned version
into its cache for one run, so nothing is installed into the user's Python. Without uv, the script
writes nothing, says how to install uv, and exits 3. Uses only the Python standard library.
"""

import os
import shutil
import sys

PILLOW = "Pillow==13.0.0"
INSIDE = "MOTION_EXPLAINER_WITH_PILLOW"


def ensure(script):
    """Returns when Pillow can be imported in this run; otherwise starts the script again through uv."""
    if os.environ.get(INSIDE) == "1":
        return
    uv = shutil.which("uv")
    if not uv:
        print("motion-explainer: %s needs Pillow, which uv fetches for one run, and uv was not found; "
              "install uv (for example with `brew install uv` or `pipx install uv`) and run it again"
              % os.path.basename(script), file=sys.stderr)
        sys.exit(3)
    env = dict(os.environ, **{INSIDE: "1"})
    args = [uv, "run", "--no-project", "--quiet", "--with", PILLOW, "python3", os.path.abspath(script)] + sys.argv[1:]
    os.execve(uv, args, env)
