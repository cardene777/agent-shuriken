#!/usr/bin/env bash
# agent-guards: Refuses gh sends and git commits whose text or change holds a key-shaped value.
# Reads one PreToolUse event on stdin and prints a deny decision or nothing. AGENT_GUARDS_OUTBOUND=off turns it off.
case "${AGENT_GUARDS_OUTBOUND:-}" in [Oo][Ff][Ff]) exit 0 ;; esac
if ! command -v python3 > /dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"agent-guards (outbound): python3 is not on PATH, so it cannot judge this call. Install Python 3, or set AGENT_GUARDS_OUTBOUND=off to turn this hook off."}}'
  exit 0
fi
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_guards.py" outbound
