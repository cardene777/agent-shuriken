#!/bin/bash
# Writes the project this case starts from (mode: opcodes).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_release_fixture.py" opcodes
