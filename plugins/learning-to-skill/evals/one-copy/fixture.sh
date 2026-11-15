#!/bin/bash
# Writes the shop repository with AGENTS.md and a CLAUDE.md that does not import it.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" claude
