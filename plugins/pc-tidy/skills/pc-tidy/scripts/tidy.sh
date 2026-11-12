#!/usr/bin/env bash

# List things that have gone unused for a long time, and remove only the ones the user picks.
# The implementation is `tidy.py` in the same directory.
#
# Usage
#   tidy.sh list [--json]                     Measure candidates and write the list and the selection page
#   tidy.sh explain --notes <file> [--json]   Save a name and description per number and rebuild the page
#   tidy.sh comment --paste <file> [--json]   Save the comments from pasted text and rebuild the page
#   tidy.sh apply --select <numbers> [--json] Remove only these numbers from the latest list (e.g. `1,3,5-8`)
#
# State lives in `$PC_TIDY_HOME` (default `~/.local/share/pc-tidy`).
# Nothing outside this directory is needed, so copying the skill directory alone is enough on another Mac.
# `list` walks the whole home directory, so it runs under `nice -n 10`, which lowers only its CPU priority.
# Disk I/O is left alone: throttling I/O as well with `taskpolicy` made almost no progress while other work was running.

set -u

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
python=$(command -v python3 2>/dev/null || printf '/usr/bin/python3')

if [ "${1:-}" = list ] && [ -z "${PC_TIDY_LOW_PRIORITY:-}" ] && command -v nice >/dev/null 2>&1; then
  export PC_TIDY_LOW_PRIORITY=1
  exec nice -n 10 "$python" -I "$dir/tidy.py" "$@"
fi
exec "$python" -I "$dir/tidy.py" "$@"
