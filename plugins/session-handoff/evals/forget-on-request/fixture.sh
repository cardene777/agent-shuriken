#!/bin/bash
# Writes the shop project and the state an earlier session saved for it.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" saved
