#!/bin/bash
# Writes a project with docs/login.mmd, a login flowchart in the Mermaid subset the plugin converts.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" mermaid
