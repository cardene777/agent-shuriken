#!/usr/bin/env bash
# agent-notices: Creates the file CLAUDE_CLIENT_PRESENCE_FILE names at session start and removes it at session end.
# Reads one hook event on stdin and prints a notice for the agent, or nothing; it never stops a call.
# AGENT_NOTICES_PRESENCE=off turns it off.
case "${AGENT_NOTICES_PRESENCE:-}" in [Oo][Ff][Ff]) exit 0 ;; esac
command -v python3 > /dev/null 2>&1 || exit 0
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_notices.py" presence
