#!/bin/bash
# Writes the shop repository whose AGENTS.md has a vaguer line about the checkout tests.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" close
