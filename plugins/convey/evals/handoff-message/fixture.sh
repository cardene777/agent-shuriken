#!/bin/bash
# Writes the source text the case starts from (see _fixture.py).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" handoff
