#!/bin/bash
# Writes the shop project and the registry this case starts from (mode: registered).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" registered
