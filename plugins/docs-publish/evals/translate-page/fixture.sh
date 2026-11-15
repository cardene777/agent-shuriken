#!/bin/bash
# Writes the tiny-slug library, lays out its docs, and finishes the English Quickstart. The Japanese
# Quickstart is still the starter page.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" translate-ready
