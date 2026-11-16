#!/bin/bash
# Writes the project this case starts from: a README for banks that settle ISO 20022 payments on a
# permissioned chain, and an empty contracts folder.
set -eu
mkdir -p contracts
cat > README.md <<'EOF'
# Corridor settlement

Five banks settle cross-border customer payments with each other on a permissioned EVM chain that they run together.
Each bank's payment hub receives ISO 20022 `pacs.008` customer credit transfers over Swift under CBPR+ and returns `pacs.002` payment status reports.
`contracts/` will hold the settlement contract that records each payment between the banks and its status.
The banks plan to go live in early 2027.
EOF
