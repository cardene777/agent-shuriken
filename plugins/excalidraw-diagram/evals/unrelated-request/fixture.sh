#!/bin/bash
# Writes a project with docs/flow.mmd, a small Mermaid flowchart to read.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" flow
