#!/bin/bash
# Writes the project this case starts from: one sale contract with an end time.
set -eu
mkdir -p contracts
cat > README.md <<'EOF'
# Lumen token sale

`contracts/Sale.sol` is the sale contract.
EOF
cat > contracts/Sale.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Sale {
    uint256 public immutable endTime;
    mapping(address => uint256) public paid;

    error SaleEnded();

    constructor(uint256 endTime_) {
        endTime = endTime_;
    }

    function buy() external payable {
        if (block.timestamp >= endTime) revert SaleEnded();
        paid[msg.sender] += msg.value;
    }
}
EOF
