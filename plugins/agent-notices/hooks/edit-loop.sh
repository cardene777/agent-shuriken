#!/usr/bin/env bash
# agent-notices: Notes the fifth edit of one file in a session, and every fifth after it, so the agent looks for the cause.
# Reads one hook event on stdin and prints a notice for the agent, or nothing; it never stops a call.
# AGENT_NOTICES_EDIT_LOOP=off turns it off; AGENT_NOTICES_EDIT_LOOP_EVERY and AGENT_NOTICES_EDIT_LOOP_SKILL change the notice.
case "${AGENT_NOTICES_EDIT_LOOP:-}" in [Oo][Ff][Ff]) exit 0 ;; esac
command -v python3 > /dev/null 2>&1 || exit 0
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_notices.py" edit-loop
