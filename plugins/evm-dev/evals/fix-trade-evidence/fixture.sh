#!/bin/bash
# Writes the project this case starts from: a README for a tokenized-bond venue that records FIX
# executions on a permissioned chain, and an empty contracts folder.
set -eu
mkdir -p contracts
cat > README.md <<'EOF'
# Bond trade register

A venue for tokenized bonds records executed trades on a permissioned EVM chain, so that the issuer's paying agent and the custodian see the same trades.
The order gateway receives FIX execution reports (`35=8`) from three brokers, including corrections and cancellations of earlier fills.
`contracts/` will hold the trade register.
EOF
