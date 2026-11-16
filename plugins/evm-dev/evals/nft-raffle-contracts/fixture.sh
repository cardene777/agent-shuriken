#!/bin/bash
# Writes the project this case starts from: a README for a weekly NFT raffle on Ethereum mainnet,
# and an empty contracts folder.
set -eu
mkdir -p contracts
cat > README.md <<'EOF'
# Weekly art raffle

Each week a gallery puts one NFT from its collection up as a prize on Ethereum mainnet.
Anyone may buy raffle tickets with ETH, 0.01 ETH each, up to 100 tickets per address.
When the week ends, one ticket is drawn and its holder receives the NFT, and the ticket money goes to the gallery's treasury.
If fewer than 200 tickets were sold, there is no draw: the NFT goes back to the gallery and every buyer can get their ETH back.
The draw must be one nobody can predict or choose, including the gallery, and it must happen on time even when the gallery's staff are offline.
`contracts/` will hold the raffle contract.
EOF
