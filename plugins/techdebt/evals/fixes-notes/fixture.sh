#!/bin/bash
# Writes the state this case starts from (mode: drafted).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" drafted
