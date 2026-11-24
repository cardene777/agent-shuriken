#!/usr/bin/env bash
# agent-notices: Notes an environment variable an edit added that the repository's .env.example does not list.
# Reads one hook event on stdin and prints a notice for the agent, or nothing; it never stops a call.
# AGENT_NOTICES_ENV_EXAMPLE=off turns it off.
case "${AGENT_NOTICES_ENV_EXAMPLE:-}" in [Oo][Ff][Ff]) exit 0 ;; esac
command -v python3 > /dev/null 2>&1 || exit 0
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_notices.py" env-example
