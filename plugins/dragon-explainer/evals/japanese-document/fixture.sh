#!/bin/bash
# Writes queue-lite, a small Node.js job queue for the explainer to describe, and no docs/explainers folder.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" project
