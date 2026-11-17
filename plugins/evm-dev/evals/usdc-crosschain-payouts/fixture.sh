#!/bin/bash
# Writes the project this case starts from: a README for a marketplace that collects USDC on
# Arbitrum and pays sellers on Base, and an empty docs folder.
set -eu
mkdir -p docs
cat > README.md <<'EOF'
# Marketplace payouts

Our marketplace collects USDC from buyers into a treasury contract on Arbitrum One.
Every day we pay sellers on Base, and sellers want native USDC there, not a wrapped token.
Today someone moves the funds by hand through an exchange.
We want a flow driven by contracts that moves the day's USDC from Arbitrum to a payout contract on Base and pays each seller when it arrives.
EOF
