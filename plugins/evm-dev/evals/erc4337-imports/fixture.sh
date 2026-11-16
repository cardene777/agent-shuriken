#!/bin/bash
# Writes the project this case starts from (mode: erc4337).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_solidity_fixture.py" erc4337
