#!/bin/bash
# Writes pantry with a hand-written 1Password template whose PANTRY_DB_HOST line must be kept.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" template
