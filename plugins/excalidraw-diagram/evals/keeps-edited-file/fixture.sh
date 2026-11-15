#!/bin/bash
# Writes a pipeline diagram built by this plugin, then changes a label in its .excalidraw file,
# as if the user edited it in Excalidraw.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" edited
