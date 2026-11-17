#!/bin/bash
# Writes the project this case starts from (mode: unrelated).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_release_fixture.py" unrelated
