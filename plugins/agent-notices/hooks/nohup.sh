#!/usr/bin/env bash
# agent-notices: Notes a command started with nohup in the background, which gives no completion notice.
# Reads one hook event on stdin and prints a notice for the agent, or nothing; it never stops a call.
# AGENT_NOTICES_NOHUP=off turns it off.
case "${AGENT_NOTICES_NOHUP:-}" in [Oo][Ff][Ff]) exit 0 ;; esac
command -v python3 > /dev/null 2>&1 || exit 0
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_notices.py" nohup
