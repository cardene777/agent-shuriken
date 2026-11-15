#!/bin/bash
# Writes pantry, whose README has the typo the request asks to fix.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" app
