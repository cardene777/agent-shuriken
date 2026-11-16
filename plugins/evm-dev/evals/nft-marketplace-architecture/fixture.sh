#!/bin/bash
# Writes the project this case starts from: a README for an NFT marketplace whose buyers are new to
# crypto, an empty contracts folder, and an empty web folder.
set -eu
mkdir -p contracts web
cat > README.md <<'EOF'
# Studio market

A marketplace where independent illustrators sell limited editions of their work as NFTs on Base, and fans buy them.
Most buyers are new to crypto: they sign in with an embedded wallet and should be able to buy without holding ETH first, while artists list editions themselves.
Artwork images and metadata are stored on IPFS and referenced from each token.
The market lists every edition, each artist's sales history, and who owns what, and it must keep working when the team is asleep.
The team is three people; one of them can operate servers. The operator must be able to pause sales if something goes wrong.
`contracts/` will hold the marketplace and edition contracts, and `web/` the Next.js frontend.
The launch on mainnet is planned for early 2027, after a public test on a testnet.
EOF
