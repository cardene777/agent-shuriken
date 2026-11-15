#!/bin/bash
# Writes the shop repository with AGENTS.md and a README.md whose typo is to be fixed.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" plain
