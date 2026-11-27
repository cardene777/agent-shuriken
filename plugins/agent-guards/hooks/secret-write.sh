#!/usr/bin/env bash
# agent-guards: Refuses writes to key files, .env files, and the places in secret-paths, writes through a second name
# (hard link) of a file, and keys written into shell startup files, from a shell command, the file tools, or a Codex patch.
# Reads one PreToolUse event on stdin and prints a deny decision or nothing. AGENT_GUARDS_SECRET_WRITE=off,
# AGENT_GUARDS_HARD_LINKS=off, and AGENT_GUARDS_STARTUP_KEYS=off each turn off one check; the hook exits at once when all are off.
off() { case "$1" in [Oo][Ff][Ff]) return 0 ;; esac; return 1; }
if off "${AGENT_GUARDS_SECRET_WRITE:-}" && off "${AGENT_GUARDS_HARD_LINKS:-}" && off "${AGENT_GUARDS_STARTUP_KEYS:-}"; then
  exit 0
fi
if ! command -v python3 > /dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"agent-guards (secret-write): python3 is not on PATH, so it cannot judge this call. Install Python 3, or set AGENT_GUARDS_SECRET_WRITE=off, AGENT_GUARDS_HARD_LINKS=off, and AGENT_GUARDS_STARTUP_KEYS=off to turn this hook off."}}'
  exit 0
fi
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_guards.py" secret-write
