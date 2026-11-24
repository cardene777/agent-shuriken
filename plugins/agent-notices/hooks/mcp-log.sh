#!/usr/bin/env bash
# agent-notices: Writes one line per MCP call, without its arguments or result, when turned on.
# Reads one hook event on stdin and prints a notice for the agent, or nothing; it never stops a call.
# It is off unless AGENT_NOTICES_MCP_LOG=on.
case "${AGENT_NOTICES_MCP_LOG:-}" in [Oo][Nn]) ;; *) exit 0 ;; esac
command -v python3 > /dev/null 2>&1 || exit 0
exec python3 -I "${BASH_SOURCE[0]%/*}/lib/agent_notices.py" mcp-log
