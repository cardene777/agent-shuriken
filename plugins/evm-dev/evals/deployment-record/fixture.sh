#!/bin/bash
# Writes the project this case starts from (mode: record).
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_deploy_fixture.py" record
