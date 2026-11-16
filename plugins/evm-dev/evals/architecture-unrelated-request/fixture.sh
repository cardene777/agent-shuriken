#!/bin/bash
# Writes the project this case starts from: one marketplace contract with a pause switch.
set -eu
mkdir -p contracts
cat > README.md <<'EOF'
# Studio market

`contracts/Market.sol` is the marketplace contract.
EOF
cat > contracts/Market.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Market {
    address public operator;
    bool public paused;

    error Paused();
    error NotOperator();

    constructor(address operator_) {
        operator = operator_;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    function setPaused(bool paused_) external {
        if (msg.sender != operator) revert NotOperator();
        paused = paused_;
    }

    function buy(uint256 editionId) external payable whenNotPaused {
        editionId;
    }
}
EOF
