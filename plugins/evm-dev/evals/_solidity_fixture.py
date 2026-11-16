"""Writes the project a solidity-code eval case starts from, in the current folder.

Usage: python3 _solidity_fixture.py <erc4337|proxy|eoa|upgradeable>

The library files are short stand-ins that keep the real paths, names, and signatures of the
installed version, so an agent that looks under lib/ or node_modules/ sees what a real project has.
Nothing is downloaded, and no file holds a key.
"""
import json
import sys
from pathlib import Path

FOUNDRY_TOML = """[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.34"
optimizer = true
"""

REMAPPINGS = """@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
forge-std/=lib/forge-std/src/
"""


def write(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def package(path, name, version):
    write(path, json.dumps({"name": name, "version": version}, indent=2) + "\n")


def foundry(oz_version):
    write("foundry.toml", FOUNDRY_TOML)
    write("remappings.txt", REMAPPINGS)
    package("lib/forge-std/package.json", "forge-std", "1.17.0")
    write("lib/forge-std/src/Test.sol", "// SPDX-License-Identifier: MIT OR Apache-2.0\npragma solidity >=0.8.13 <0.9.0;\n\nabstract contract Test {}\n")
    package("lib/openzeppelin-contracts/package.json", "openzeppelin-solidity", oz_version)


def erc4337():
    foundry("5.7.0")
    oz = "lib/openzeppelin-contracts/contracts/"
    write(oz + "interfaces/IERC4337.sol", """// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.7.0) (interfaces/IERC4337.sol)
pragma solidity >=0.8.4;

struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}
""")
    write(oz + "account/utils/ERC4337Utils.sol", """// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.7.0) (account/utils/ERC4337Utils.sol)
pragma solidity ^0.8.24;

import {PackedUserOperation} from "../../interfaces/IERC4337.sol";

library ERC4337Utils {
    function paymaster(PackedUserOperation calldata self) internal pure returns (address) {
        return self.paymasterAndData.length < 52 ? address(0) : address(bytes20(self.paymasterAndData[0:20]));
    }
}
""")
    write("src/.gitkeep", "")


def proxy():
    foundry("5.6.1")
    package("lib/openzeppelin-contracts-upgradeable/package.json", "openzeppelin-solidity-upgradeable", "5.6.1")
    oz = "lib/openzeppelin-contracts/contracts/"
    write(oz + "proxy/ERC1967/ERC1967Proxy.sol", """// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.6.0) (proxy/ERC1967/ERC1967Proxy.sol)
pragma solidity ^0.8.22;

contract ERC1967Proxy {
    constructor(address implementation, bytes memory _data) payable {}
}
""")
    write(oz + "proxy/utils/Initializable.sol", "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\nabstract contract Initializable {}\n")
    write(oz + "proxy/utils/UUPSUpgradeable.sol", "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.22;\n\nabstract contract UUPSUpgradeable {}\n")
    write("lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol",
          "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\nabstract contract OwnableUpgradeable {}\n")
    write("src/Vault.sol", """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title Vault
/// @notice Holds deposits for one owner. Deployed behind a proxy.
contract Vault is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
""")


def eoa():
    foundry("5.6.1")
    write("lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol",
          "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.24;\n\nabstract contract ERC721 {\n    constructor(string memory name_, string memory symbol_) {}\n    function _safeMint(address to, uint256 tokenId) internal {}\n}\n")
    write("src/Pass.sol", """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title Pass
/// @notice A free membership pass, one mint per call.
contract Pass is ERC721 {
    uint256 public nextId;

    constructor() ERC721("Pass", "PASS") {}

    function mint() external {
        _safeMint(msg.sender, nextId++);
    }
}
""")


def upgradeable():
    """A Hardhat 3 project on OpenZeppelin 5.5.0, where the upgradeable reentrancy guards are gone."""
    write("package.json", json.dumps({
        "name": "vault",
        "type": "module",
        "devDependencies": {"hardhat": "^3.22.0"},
        "dependencies": {"@openzeppelin/contracts": "5.5.0", "@openzeppelin/contracts-upgradeable": "5.5.0"},
    }, indent=2) + "\n")
    package("node_modules/hardhat/package.json", "hardhat", "3.22.0")
    package("node_modules/@openzeppelin/contracts/package.json", "@openzeppelin/contracts", "5.5.0")
    package("node_modules/@openzeppelin/contracts-upgradeable/package.json", "@openzeppelin/contracts-upgradeable", "5.5.0")
    oz = "node_modules/@openzeppelin/contracts/"
    for path, name in (("utils/ReentrancyGuard.sol", "ReentrancyGuard"),
                       ("utils/ReentrancyGuardTransient.sol", "ReentrancyGuardTransient"),
                       ("proxy/utils/Initializable.sol", "Initializable"),
                       ("proxy/utils/UUPSUpgradeable.sol", "UUPSUpgradeable"),
                       ("access/Ownable.sol", "Ownable")):
        write(oz + path, "// SPDX-License-Identifier: MIT\n// OpenZeppelin Contracts (last updated v5.5.0) (%s)\npragma solidity ^0.8.20;\n\nabstract contract %s {}\n" % (path, name))
    up = "node_modules/@openzeppelin/contracts-upgradeable/"
    for path, name in (("proxy/utils/Initializable.sol", "Initializable"), ("proxy/utils/UUPSUpgradeable.sol", "UUPSUpgradeable")):
        write(up + path, "// SPDX-License-Identifier: MIT\n// OpenZeppelin Contracts (last updated v5.5.0) (%s)\npragma solidity ^0.8.20;\n\nimport {%s} from \"@openzeppelin/contracts/%s\";\n" % (path, name, path))
    write(up + "access/OwnableUpgradeable.sol", "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\nabstract contract OwnableUpgradeable {}\n")
    write("hardhat.config.ts", """import { defineConfig } from "hardhat/config";

export default defineConfig({
  solidity: "0.8.28",
});
""")
    write("contracts/Vault.sol", """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Vault
/// @notice Holds ether deposits; each depositor withdraws their own balance.
contract Vault is Ownable {
    mapping(address => uint256) public balanceOf;

    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed();

    constructor(address owner_) Ownable(owner_) {}

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        uint256 available = balanceOf[msg.sender];
        if (amount > available) revert InsufficientBalance(amount, available);
        balanceOf[msg.sender] = available - amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
""")


if __name__ == "__main__":
    modes = {"erc4337": erc4337, "proxy": proxy, "eoa": eoa, "upgradeable": upgradeable}
    if len(sys.argv) != 2 or sys.argv[1] not in modes:
        sys.exit("usage: _solidity_fixture.py <%s>" % "|".join(modes))
    modes[sys.argv[1]]()
