#!/bin/bash
# Writes the project this case starts from (mode: hardhat).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_tests_fixture.py" hardhat
