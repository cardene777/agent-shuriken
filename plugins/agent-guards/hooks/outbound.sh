#!/usr/bin/env bash
# agent-guards: Refuses gh sends and git commits whose text or change holds a key-shaped value, chain transactions
# sent to a target that is not on this machine, and sends to repositories of owners not in the own-owners list.
# Reads one PreToolUse event on stdin and prints a deny decision or nothing. AGENT_GUARDS_OUTBOUND=off,
# AGENT_GUARDS_CHAIN=off, and AGENT_GUARDS_OTHER_REPOS=off each turn off one check; the hook exits at once when all are off.
off() { case "$1" in [Oo][Ff][Ff]) return 0 ;; esac; return 1; }
if off "${AGENT_GUARDS_OUTBOUND:-}" && off "${AGENT_GUARDS_CHAIN:-}" && off "${AGENT_GUARDS_OTHER_REPOS:-}"; then
  exit 0
fi
if ! command -v python3 > /dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"agent-guards (outbound): python3 is not on PATH, so it cannot judge this call. Install Python 3, or set AGENT_GUARDS_OUTBOUND=off, AGENT_GUARDS_CHAIN=off, and AGENT_GUARDS_OTHER_REPOS=off to turn this hook off."}}'
  exit 0
fi
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_guards.py" outbound
