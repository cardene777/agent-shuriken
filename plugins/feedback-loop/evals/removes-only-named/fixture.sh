#!/bin/bash
# Writes the shop repository with the guide and its FAQ section.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" plain
