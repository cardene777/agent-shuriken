#!/bin/bash
# Writes pantry, a small Next.js app with an env file of made-up values, and no Docker files.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" app
