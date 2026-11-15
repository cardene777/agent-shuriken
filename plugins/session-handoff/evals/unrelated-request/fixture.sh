#!/bin/bash
# Writes the shop project outside git, with no saved state.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" plain
