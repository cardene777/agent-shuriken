#!/bin/bash
# Writes a small Node.js project with an unused dependency, and no data folder.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" project
