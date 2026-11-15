#!/bin/bash
# Writes the tiny-slug library and lays out its docs in English and Japanese with the starter pages.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" laid-out
