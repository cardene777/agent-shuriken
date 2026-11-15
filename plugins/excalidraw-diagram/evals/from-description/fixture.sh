#!/bin/bash
# Writes a project with only a README, so the diagram goes to the folder the prompt names.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" project
