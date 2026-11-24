#!/usr/bin/env bash
# agent-notices: Notes a temporary directory with less free space than AGENT_NOTICES_TMP_MIN_GB (5 GB by default).
# Reads one hook event on stdin and prints a notice for the agent, or nothing; it never stops a call.
# AGENT_NOTICES_TMP_SPACE=off turns it off.
case "${AGENT_NOTICES_TMP_SPACE:-}" in [Oo][Ff][Ff]) exit 0 ;; esac
command -v python3 > /dev/null 2>&1 || exit 0
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_notices.py" tmp-space
