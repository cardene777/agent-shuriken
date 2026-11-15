#!/bin/bash
# Writes the shop repository whose AGENTS.md already says to run pnpm test:checkout.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" existing
