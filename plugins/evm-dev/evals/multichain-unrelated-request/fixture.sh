#!/bin/bash
# Writes the project this case starts from: one deployment script that requires a chain ID.
set -eu
mkdir -p script
cat > README.md <<'EOF'
# PEARL deployment

`script/Deploy.s.sol` deploys the token.
EOF
cat > script/Deploy.s.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        require(block.chainid == 8453, "wrong chain");
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}
EOF
