#!/bin/bash
# Writes the shop repository with src/login.py, which rejects passwords that contain a space.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" login
