#!/usr/bin/env bash
# agent-notices: Notes ten tool calls in a row that each came in a message of their own, in Claude Code only.
# Reads one hook event on stdin and prints a notice for the agent, or nothing; it never stops a call.
# AGENT_NOTICES_SEQUENTIAL=off turns it off; AGENT_NOTICES_SEQUENTIAL_AFTER changes the count.
case "${AGENT_NOTICES_SEQUENTIAL:-}" in [Oo][Ff][Ff]) exit 0 ;; esac
command -v python3 > /dev/null 2>&1 || exit 0
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_notices.py" sequential
