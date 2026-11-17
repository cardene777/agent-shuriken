#!/bin/bash
# Writes the project this case starts from: a README for a savings app on Base whose users already
# have wallets, and an empty docs folder.
set -eu
mkdir -p docs
cat > README.md <<'EOF'
# Tidepool

Tidepool is a savings app on Base. Users deposit USDC into a vault contract and withdraw it later.
Most users already have a wallet, MetaMask or Coinbase Wallet, with an ordinary address and their USDC in it.
Today a deposit takes two transactions, an approval and the deposit, and users pay gas in ETH, which many of them do not hold.
We want a deposit to be one confirmation, and we will pay the gas for each user's first five deposits.
We never want to hold users' keys or seed phrases.
EOF
