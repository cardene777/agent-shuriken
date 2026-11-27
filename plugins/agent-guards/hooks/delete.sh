#!/usr/bin/env bash
# agent-guards: Refuses broad deletes and deletes of places in the protected-paths list, and commands that change
# mounts, disks, or the packet filter, or run a script with administrator privileges.
# Reads one PreToolUse event on stdin and prints a deny decision or nothing. AGENT_GUARDS_DELETE=off and
# AGENT_GUARDS_SYSTEM=off each turn off one check; the hook exits at once when both are off.
off() { case "$1" in [Oo][Ff][Ff]) return 0 ;; esac; return 1; }
if off "${AGENT_GUARDS_DELETE:-}" && off "${AGENT_GUARDS_SYSTEM:-}"; then
  exit 0
fi
if ! command -v python3 > /dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"agent-guards (delete): python3 is not on PATH, so it cannot judge this call. Install Python 3, or set AGENT_GUARDS_DELETE=off and AGENT_GUARDS_SYSTEM=off to turn this hook off."}}'
  exit 0
fi
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_guards.py" delete
