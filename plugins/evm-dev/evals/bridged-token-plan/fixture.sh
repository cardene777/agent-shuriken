#!/bin/bash
# Writes the project this case starts from: a README for a token on Ethereum that holders want to
# move to Base, and an empty docs folder.
set -eu
mkdir -p docs
cat > README.md <<'EOF'
# PEARL

PEARL is an ERC-20 token on Ethereum mainnet with 18 decimals and a fixed supply of 100,000,000.
Holders want to move PEARL to Base to use it there, and back to Ethereum when they like.
The team's treasury is a Safe multisig on Ethereum.
We have not chosen a bridge or a message protocol yet.
EOF
