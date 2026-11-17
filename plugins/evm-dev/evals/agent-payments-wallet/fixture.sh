#!/bin/bash
# Writes the project this case starts from: a README for a research agent that pays data APIs with
# x402, and an empty docs folder.
set -eu
mkdir -p docs
cat > README.md <<'EOF'
# Research agent

Our research agent runs on our own server and buys data from APIs that charge per request with HTTP 402 payments (x402), in USDC on Base.
The finance team funds it with at most 200 USDC a month from the company treasury, which is a Safe multisig.
A person on the team must be able to stop the agent from paying at any time.
The agent must never be able to move the treasury's funds or pay anyone other than the data APIs we approve.
EOF
