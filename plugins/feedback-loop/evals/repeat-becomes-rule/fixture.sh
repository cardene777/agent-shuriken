#!/bin/bash
# Writes the shop repository with the guide whose install step says npm install -g.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" plain
