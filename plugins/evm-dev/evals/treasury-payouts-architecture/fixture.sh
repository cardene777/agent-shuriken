#!/bin/bash
# Writes the project this case starts from: a README for a DAO whose treasury pays contributors on a
# schedule, and an empty contracts folder.
set -eu
mkdir -p contracts
cat > README.md <<'EOF'
# Guild payouts

A DAO pays its contributors in USDC from its treasury on Ethereum mainnet, once a month and without anyone pressing a button.
Contributors and their monthly amounts are approved by a token vote, and the approved list changes a few times a year.
Contributors see their past and upcoming payouts on a small web page.
The DAO's council must hear about it at once when anyone changes the payout list, the contract's roles, or the treasury's signers.
`contracts/` will hold the payout contract. The DAO wants to run it on a testnet for two months before mainnet.
EOF
