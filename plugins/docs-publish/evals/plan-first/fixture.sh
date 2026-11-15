#!/bin/bash
# Writes the tiny-slug library into the workspace, with no docs yet.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" project
