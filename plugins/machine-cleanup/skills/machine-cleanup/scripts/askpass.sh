#!/bin/sh
# The askpass program of machine-cleanup. sudo -A runs it, as the user, with its prompt as the first
# argument, when the agent runs the command apply printed. It opens the operating system's password
# dialog and prints what was typed to standard output, which sudo reads. It writes nothing anywhere
# else, so the password never reaches the agent, a file, or a log.
prompt=${1:-"machine-cleanup needs your administrator password"}
if [ "$(uname -s)" = Darwin ]; then
  exec osascript -e 'on run argv' \
    -e 'display dialog (item 1 of argv) with title "machine-cleanup" default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK" with icon caution' \
    -e 'return text returned of result' -e 'end run' "$prompt"
fi
if command -v zenity > /dev/null 2>&1; then
  exec zenity --password --title="$prompt"
fi
if command -v kdialog > /dev/null 2>&1; then
  exec kdialog --title machine-cleanup --password "$prompt"
fi
if command -v ssh-askpass > /dev/null 2>&1; then
  exec ssh-askpass "$prompt"
fi
echo "machine-cleanup: no password dialog is installed (zenity, kdialog, or ssh-askpass)" >&2
exit 1
