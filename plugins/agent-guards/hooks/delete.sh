#!/usr/bin/env bash
# agent-guards: Refuses broad deletes and deletes of places in the protected-paths list, commands that change
# mounts, disks, or the packet filter, or run a script with administrator privileges, and commands that end
# system processes, every process, or processes they cannot name.
# Reads one PreToolUse event on stdin and prints a deny decision or nothing. AGENT_GUARDS_DELETE=off,
# AGENT_GUARDS_SYSTEM=off, and AGENT_GUARDS_PROCESSES=off each turn off one check; the hook exits at once when all
# three are off.
off() { case "$1" in [Oo][Ff][Ff]) return 0 ;; esac; return 1; }
if off "${AGENT_GUARDS_DELETE:-}" && off "${AGENT_GUARDS_SYSTEM:-}" && off "${AGENT_GUARDS_PROCESSES:-}"; then
  exit 0
fi
if ! command -v python3 > /dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"agent-guards (delete): python3 is not on PATH, so it cannot judge this call. Install Python 3, or set AGENT_GUARDS_DELETE=off, AGENT_GUARDS_SYSTEM=off, and AGENT_GUARDS_PROCESSES=off to turn this hook off."}}'
  exit 0
fi
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_guards.py" delete
