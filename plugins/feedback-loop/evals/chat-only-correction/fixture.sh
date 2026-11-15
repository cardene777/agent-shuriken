#!/bin/bash
# Writes the shop repository; the correction is about a chat reply, not a file.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" plain
