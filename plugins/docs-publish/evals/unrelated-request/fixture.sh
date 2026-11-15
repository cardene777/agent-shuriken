#!/bin/bash
# Writes the tiny-slug library, whose README has the typo the prompt names, with no docs.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" project
