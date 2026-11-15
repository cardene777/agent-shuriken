#!/bin/bash
# Writes Chrome's saved passwords and history for made-up sites, with no password in any row, and no data folder.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" browser
