#!/bin/bash
# Writes the project this case starts from: a README for a token sale on Arbitrum that takes USDC
# and ETH, and an empty contracts folder.
set -eu
mkdir -p contracts
cat > README.md <<'EOF'
# Lumen token sale

The Lumen team sells 20% of a fixed supply of 1,000,000,000 LUMEN tokens on Arbitrum One over two weeks.
Buyers pay in USDC or in ETH; an ETH payment is valued in dollars at the current ETH price, and every buyer pays the same dollar price per token.
Each wallet may buy at most 5,000 dollars' worth, and the sale raises at most 2,000,000 dollars. If it is oversubscribed, each buyer receives a share in proportion to what they paid and gets the rest back.
Bought tokens vest: 10% at the end of the sale, then the rest monthly over twelve months.
The sale must end and pay out on time even if the team is offline, and the team must be able to stop it if something goes wrong.
`contracts/` will hold the token, sale, and vesting contracts.
EOF
