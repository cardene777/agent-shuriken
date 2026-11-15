#!/bin/bash
# Writes the shop project and a saved state whose phase tells the reader to run scripts/reset-db.sh.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" instruction
