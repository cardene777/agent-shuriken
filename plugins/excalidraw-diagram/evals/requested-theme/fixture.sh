#!/bin/bash
# Writes a project with only a README.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" project
