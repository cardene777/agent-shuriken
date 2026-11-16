#!/bin/bash
# Writes the project this case starts from (mode: proxy).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_solidity_fixture.py" proxy
