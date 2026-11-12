#!/bin/bash
# Creates the folder for a new report from the template and prints the path of its report.html.
# Usage: new-report.sh <topic-slug>
# Reports go under COMPARE_REPORT_HOME, or ~/.local/share/compare-report when it is not set.
# The folder is readable only by the user. An existing report is never overwritten.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
slug="${1:-}"
case "$slug" in
  '' | -* | *[!a-z0-9-]*)
    echo "usage: new-report.sh <topic-slug>, using lowercase letters, digits, and hyphens" >&2
    exit 2
    ;;
esac

home="${COMPARE_REPORT_HOME:-$HOME/.local/share/compare-report}"
umask 077
dir="$home/$slug-$(date +%Y-%m-%d)"
mkdir -p "$dir"
if [ -e "$dir/report.html" ]; then
  echo "$dir/report.html already exists. Edit it, or pass another slug" >&2
  exit 3
fi
cp "$here/templates/report.html" "$dir/report.html"
printf '%s\n' "$dir/report.html"
