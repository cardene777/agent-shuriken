#!/bin/bash
# Remove the password manager item for a deleted account in a way the user can undo.
# 1Password moves it to the archive with `op item delete --archive`; Bitwarden moves it to the trash with `bw delete item`.
# Neither deletes it permanently (the user does that in the app).
# Chrome items are not removed by command; the user removes them in Chrome's password manager page.
#
# Usage: remove-item.sh <1password|bitwarden|chrome> <item ID> [--account <1Password account>]

. "$(dirname "$0")/common.sh"

if [ $# -lt 2 ]; then
  echo "Usage: remove-item.sh <1password|bitwarden|chrome> <item ID> [--account <account>]" >&2
  exit 2
fi
source_name=$1
id=$2

case "$source_name" in
  1password)
    need op "Install the 1Password CLI (op)."
    args=(item delete "$id" --archive)
    signin=(signin)
    if [ "${3:-}" = "--account" ] && [ -n "${4:-}" ]; then
      args+=(--account "$4")
      signin+=(--account "$4")
    fi
    # The first call after the app's approval has expired fails without waiting for approval.
    # Wait for the app's approval (Touch ID) with signin, then retry once
    if ! op "${args[@]}"; then
      op "${signin[@]}" >/dev/null 2>&1
      op "${args[@]}" || exit 1
    fi
    echo "Moved 1Password item $id to the archive."
    ;;
  bitwarden)
    need bw "Install the Bitwarden CLI (bw)."
    bw delete item "$id"
    echo "Moved Bitwarden item $id to the trash."
    ;;
  chrome)
    echo "Chrome items are not removed by command. Open chrome://password-manager/passwords in Chrome and remove the item for that site." >&2
    exit 2
    ;;
  *)
    echo "account-cleanup: unknown source: $source_name" >&2
    exit 2
    ;;
esac
