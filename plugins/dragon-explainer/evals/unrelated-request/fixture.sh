#!/bin/bash
# Writes queue-lite, a small Node.js job queue, for a code change that needs no explainer.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" project
