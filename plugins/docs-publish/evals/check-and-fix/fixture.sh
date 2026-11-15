#!/bin/bash
# Writes the tiny-slug library with finished docs in English and Japanese, then breaks a link in the
# Japanese FAQ and changes the English Slugs page after its translation was recorded.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" check-and-fix
