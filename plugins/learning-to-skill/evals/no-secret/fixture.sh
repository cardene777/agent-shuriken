#!/bin/bash
# Writes the shop repository with AGENTS.md (Setup and Testing) and README.md.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" plain
