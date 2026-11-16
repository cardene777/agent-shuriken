#!/bin/bash
# Writes the project this case starts from (mode: eoa).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_solidity_fixture.py" eoa
