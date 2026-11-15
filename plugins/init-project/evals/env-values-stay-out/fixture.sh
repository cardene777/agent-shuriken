#!/bin/bash
# Writes pantry, a small Next.js app whose env file holds the marker value the case looks for in the run.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" app
