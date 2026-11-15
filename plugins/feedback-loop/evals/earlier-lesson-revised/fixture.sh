#!/bin/bash
# Writes the shop repository with an earlier closed correction to the install step, whose case
# forbids npm install -g, and the guide saying npm install -g again.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" earlier
