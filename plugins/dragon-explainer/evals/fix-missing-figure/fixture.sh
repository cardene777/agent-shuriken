#!/bin/bash
# Writes queue-lite and its explainer in docs/explainers/queue-lite/, whose Retries section has no figure.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" fix
