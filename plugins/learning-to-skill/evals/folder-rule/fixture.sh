#!/bin/bash
# Writes the shop repository with AGENTS.md and web/AGENTS.md.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" web
