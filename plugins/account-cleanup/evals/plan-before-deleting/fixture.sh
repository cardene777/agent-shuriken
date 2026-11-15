#!/bin/bash
# Writes Chrome's saved passwords for made-up sites, then has the plugin's own scripts collect, look up,
# and describe them for a user in Japan, with one service that cannot be deleted.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" planned
