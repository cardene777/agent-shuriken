"""Writes the project a release-check eval case starts from, in the current folder.

Usage: python3 _release_fixture.py <upgrade|opcodes|unrelated>

upgrade    a Foundry project whose Vault, deployed behind a proxy, is about to be upgraded: src/ holds
           the new version, which adds a variable without shrinking the gap, reorders a struct's
           members, and changes the Deposited event; snapshots/ holds the deployed version's storage
           layout and ABI from forge inspect; out/ holds the new version's build
opcodes    a Foundry project with no evm_version set, built with forge's default (prague): its
           reentrancy lock uses a transient variable and its byte copies compile to MCOPY
unrelated  the deployed version of the upgrade project, before any change

The JSON files are forge 1.5.1 and solc 0.8.30 output, cut down to the ABI, the bytecode, and the
storage layout. Nothing is downloaded and nothing is compiled.
"""
import json
import sys
from pathlib import Path

DATA = json.loads(r'''{
 "upgrade": {
  "foundry.toml": "[profile.default]\nsrc = \"src\"\nout = \"out\"\nsolc = \"0.8.30\"\noptimizer = true\nextra_output = [\"storageLayout\"]\n",
  "src/Vault.sol": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.28;\n\n/// @notice Storage shared by every version of the vault implementation behind the proxy.\nabstract contract VaultStorage {\n    struct Position {\n        uint128 amount;\n        bool active;\n        uint64 since;\n    }\n\n    address public owner;\n    mapping(address => Position) internal positions;\n    uint256 public cap;\n\n    uint256[48] private __gap;\n}\n\n/// @title Vault\n/// @notice Implementation behind an ERC-1967 proxy. Records deposits per account up to a cap.\ncontract Vault is VaultStorage {\n    error NotOwner(address caller);\n    error AlreadyInitialized();\n    error ZeroAmount();\n    error CapExceeded(uint256 amount, uint256 cap);\n\n    event Deposited(address indexed account, uint256 amount, uint256 total);\n    event Closed(address indexed account);\n    event CapSet(uint256 cap);\n\n    uint256 public version;\n    bool private initialized;\n\n    function initialize(address owner_) external {\n        if (initialized) revert AlreadyInitialized();\n        initialized = true;\n        owner = owner_;\n        version = 1;\n    }\n\n    function upgradeToV2(uint256 cap_) external {\n        if (msg.sender != owner) revert NotOwner(msg.sender);\n        version = 2;\n        cap = cap_;\n        emit CapSet(cap_);\n    }\n\n    function setCap(uint256 cap_) external {\n        if (msg.sender != owner) revert NotOwner(msg.sender);\n        cap = cap_;\n        emit CapSet(cap_);\n    }\n\n    function deposit(uint128 amount) external {\n        if (amount == 0) revert ZeroAmount();\n        Position storage p = positions[msg.sender];\n        uint256 total = uint256(p.amount) + amount;\n        if (cap != 0 && total > cap) revert CapExceeded(total, cap);\n        p.amount = uint128(total);\n        if (!p.active) {\n            p.active = true;\n            p.since = uint64(block.timestamp);\n        }\n        emit Deposited(msg.sender, amount, total);\n    }\n\n    function close() external {\n        delete positions[msg.sender];\n        emit Closed(msg.sender);\n    }\n\n    function positionOf(address account) external view returns (uint128 amount, uint64 since, bool active) {\n        Position storage p = positions[account];\n        return (p.amount, p.since, p.active);\n    }\n}\n",
  "out/Vault.sol/Vault.json": {
   "abi": [
    {
     "type": "function",
     "name": "cap",
     "inputs": [],
     "outputs": [
      {
       "name": "",
       "type": "uint256",
       "internalType": "uint256"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "function",
     "name": "close",
     "inputs": [],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "function",
     "name": "deposit",
     "inputs": [
      {
       "name": "amount",
       "type": "uint128",
       "internalType": "uint128"
      }
     ],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "function",
     "name": "initialize",
     "inputs": [
      {
       "name": "owner_",
       "type": "address",
       "internalType": "address"
      }
     ],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "function",
     "name": "owner",
     "inputs": [],
     "outputs": [
      {
       "name": "",
       "type": "address",
       "internalType": "address"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "function",
     "name": "positionOf",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "internalType": "address"
      }
     ],
     "outputs": [
      {
       "name": "amount",
       "type": "uint128",
       "internalType": "uint128"
      },
      {
       "name": "since",
       "type": "uint64",
       "internalType": "uint64"
      },
      {
       "name": "active",
       "type": "bool",
       "internalType": "bool"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "function",
     "name": "setCap",
     "inputs": [
      {
       "name": "cap_",
       "type": "uint256",
       "internalType": "uint256"
      }
     ],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "function",
     "name": "upgradeToV2",
     "inputs": [
      {
       "name": "cap_",
       "type": "uint256",
       "internalType": "uint256"
      }
     ],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "function",
     "name": "version",
     "inputs": [],
     "outputs": [
      {
       "name": "",
       "type": "uint256",
       "internalType": "uint256"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "event",
     "name": "CapSet",
     "inputs": [
      {
       "name": "cap",
       "type": "uint256",
       "indexed": false,
       "internalType": "uint256"
      }
     ],
     "anonymous": false
    },
    {
     "type": "event",
     "name": "Closed",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "indexed": true,
       "internalType": "address"
      }
     ],
     "anonymous": false
    },
    {
     "type": "event",
     "name": "Deposited",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "indexed": true,
       "internalType": "address"
      },
      {
       "name": "amount",
       "type": "uint256",
       "indexed": false,
       "internalType": "uint256"
      },
      {
       "name": "total",
       "type": "uint256",
       "indexed": false,
       "internalType": "uint256"
      }
     ],
     "anonymous": false
    },
    {
     "type": "error",
     "name": "AlreadyInitialized",
     "inputs": []
    },
    {
     "type": "error",
     "name": "CapExceeded",
     "inputs": [
      {
       "name": "amount",
       "type": "uint256",
       "internalType": "uint256"
      },
      {
       "name": "cap",
       "type": "uint256",
       "internalType": "uint256"
      }
     ]
    },
    {
     "type": "error",
     "name": "NotOwner",
     "inputs": [
      {
       "name": "caller",
       "type": "address",
       "internalType": "address"
      }
     ]
    },
    {
     "type": "error",
     "name": "ZeroAmount",
     "inputs": []
    }
   ],
   "bytecode": {
    "object": "0x6080604052348015600e575f5ffd5b506105288061001c5f395ff3fe608060405234801561000f575f5ffd5b5060043610610090575f3560e01c806354469aea1161006357806354469aea146100e057806354fd4d50146100f35780638da5cb5b146100fc578063c4d66de814610126578063fd2d39c514610139575f5ffd5b8063182d9e3114610094578063355274ea146100a957806343d726d6146100c557806347786d37146100cd575b5f5ffd5b6100a76100a2366004610463565b6101b8565b005b6100b260025481565b6040519081526020015b60405180910390f35b6100a761022a565b6100a76100db366004610463565b61026e565b6100a76100ee36600461047a565b6102cf565b6100b260335481565b5f5461010e906001600160a01b031681565b6040516001600160a01b0390911681526020016100bc565b6100a76101343660046104a7565b61040a565b6101886101473660046104a7565b6001600160a01b03165f908152600160205260409020546001600160801b03811691600160881b820467ffffffffffffffff1691600160801b900460ff1690565b604080516001600160801b03909416845267ffffffffffffffff90921660208401521515908201526060016100bc565b5f546001600160a01b031633146101e95760405163245aecd360e01b81523360048201526024015b60405180910390fd5b600260338190558190556040518181527f9872d5eb566b79923d043f1b59aca655ca80a2bb5b6bca4824e515b0e398902f906020015b60405180910390a150565b335f8181526001602052604080822080546001600160c81b0319169055517f13607bf9d2dd20e1f3a7daf47ab12856f8aad65e6ae7e2c75ace3d0c424a40e89190a2565b5f546001600160a01b0316331461029a5760405163245aecd360e01b81523360048201526024016101e0565b60028190556040518181527f9872d5eb566b79923d043f1b59aca655ca80a2bb5b6bca4824e515b0e398902f9060200161021f565b806001600160801b03165f036102f857604051631f2a200560e01b815260040160405180910390fd5b335f9081526001602052604081208054909190610321906001600160801b0380861691166104cd565b90506002545f14158015610336575060025481115b156103625760025460405163f480e28560e01b81526101e0918391600401918252602082015260400190565b81546fffffffffffffffffffffffffffffffff19166001600160801b03821617808355600160801b900460ff166103c157815467ffffffffffffffff4216600160881b0268ffffffffffffffffff60801b1990911617600160801b1782555b604080516001600160801b03851681526020810183905233917f73a19dd210f1a7f902193214c0ee91dd35ee5b4d920cba8d519eca65a7b488ca910160405180910390a2505050565b60345460ff161561042d5760405162dc149f60e41b815260040160405180910390fd5b6034805460ff191660019081179091555f80546001600160a01b039093166001600160a01b031990931692909217909155603355565b5f60208284031215610473575f5ffd5b5035919050565b5f6020828403121561048a575f5ffd5b81356001600160801b03811681146104a0575f5ffd5b9392505050565b5f602082840312156104b7575f5ffd5b81356001600160a01b03811681146104a0575f5ffd5b808201808211156104ec57634e487b7160e01b5f52601160045260245ffd5b9291505056fea26469706673582212202bb683a8138afe4b02e97bc2b236160c7d40cd7e6b3ae5326b89eed46146b93e64736f6c634300081e0033"
   },
   "deployedBytecode": {
    "object": "0x608060405234801561000f575f5ffd5b5060043610610090575f3560e01c806354469aea1161006357806354469aea146100e057806354fd4d50146100f35780638da5cb5b146100fc578063c4d66de814610126578063fd2d39c514610139575f5ffd5b8063182d9e3114610094578063355274ea146100a957806343d726d6146100c557806347786d37146100cd575b5f5ffd5b6100a76100a2366004610463565b6101b8565b005b6100b260025481565b6040519081526020015b60405180910390f35b6100a761022a565b6100a76100db366004610463565b61026e565b6100a76100ee36600461047a565b6102cf565b6100b260335481565b5f5461010e906001600160a01b031681565b6040516001600160a01b0390911681526020016100bc565b6100a76101343660046104a7565b61040a565b6101886101473660046104a7565b6001600160a01b03165f908152600160205260409020546001600160801b03811691600160881b820467ffffffffffffffff1691600160801b900460ff1690565b604080516001600160801b03909416845267ffffffffffffffff90921660208401521515908201526060016100bc565b5f546001600160a01b031633146101e95760405163245aecd360e01b81523360048201526024015b60405180910390fd5b600260338190558190556040518181527f9872d5eb566b79923d043f1b59aca655ca80a2bb5b6bca4824e515b0e398902f906020015b60405180910390a150565b335f8181526001602052604080822080546001600160c81b0319169055517f13607bf9d2dd20e1f3a7daf47ab12856f8aad65e6ae7e2c75ace3d0c424a40e89190a2565b5f546001600160a01b0316331461029a5760405163245aecd360e01b81523360048201526024016101e0565b60028190556040518181527f9872d5eb566b79923d043f1b59aca655ca80a2bb5b6bca4824e515b0e398902f9060200161021f565b806001600160801b03165f036102f857604051631f2a200560e01b815260040160405180910390fd5b335f9081526001602052604081208054909190610321906001600160801b0380861691166104cd565b90506002545f14158015610336575060025481115b156103625760025460405163f480e28560e01b81526101e0918391600401918252602082015260400190565b81546fffffffffffffffffffffffffffffffff19166001600160801b03821617808355600160801b900460ff166103c157815467ffffffffffffffff4216600160881b0268ffffffffffffffffff60801b1990911617600160801b1782555b604080516001600160801b03851681526020810183905233917f73a19dd210f1a7f902193214c0ee91dd35ee5b4d920cba8d519eca65a7b488ca910160405180910390a2505050565b60345460ff161561042d5760405162dc149f60e41b815260040160405180910390fd5b6034805460ff191660019081179091555f80546001600160a01b039093166001600160a01b031990931692909217909155603355565b5f60208284031215610473575f5ffd5b5035919050565b5f6020828403121561048a575f5ffd5b81356001600160801b03811681146104a0575f5ffd5b9392505050565b5f602082840312156104b7575f5ffd5b81356001600160a01b03811681146104a0575f5ffd5b808201808211156104ec57634e487b7160e01b5f52601160045260245ffd5b9291505056fea26469706673582212202bb683a8138afe4b02e97bc2b236160c7d40cd7e6b3ae5326b89eed46146b93e64736f6c634300081e0033"
   },
   "storageLayout": {
    "storage": [
     {
      "astId": 11,
      "contract": "src/Vault.sol:Vault",
      "label": "owner",
      "offset": 0,
      "slot": "0",
      "type": "t_address"
     },
     {
      "astId": 16,
      "contract": "src/Vault.sol:Vault",
      "label": "positions",
      "offset": 0,
      "slot": "1",
      "type": "t_mapping(t_address,t_struct(Position)9_storage)"
     },
     {
      "astId": 18,
      "contract": "src/Vault.sol:Vault",
      "label": "cap",
      "offset": 0,
      "slot": "2",
      "type": "t_uint256"
     },
     {
      "astId": 22,
      "contract": "src/Vault.sol:Vault",
      "label": "__gap",
      "offset": 0,
      "slot": "3",
      "type": "t_array(t_uint256)48_storage"
     },
     {
      "astId": 58,
      "contract": "src/Vault.sol:Vault",
      "label": "version",
      "offset": 0,
      "slot": "51",
      "type": "t_uint256"
     },
     {
      "astId": 60,
      "contract": "src/Vault.sol:Vault",
      "label": "initialized",
      "offset": 0,
      "slot": "52",
      "type": "t_bool"
     }
    ],
    "types": {
     "t_address": {
      "encoding": "inplace",
      "label": "address",
      "numberOfBytes": "20"
     },
     "t_array(t_uint256)48_storage": {
      "encoding": "inplace",
      "label": "uint256[48]",
      "numberOfBytes": "1536",
      "base": "t_uint256"
     },
     "t_bool": {
      "encoding": "inplace",
      "label": "bool",
      "numberOfBytes": "1"
     },
     "t_mapping(t_address,t_struct(Position)9_storage)": {
      "encoding": "mapping",
      "key": "t_address",
      "label": "mapping(address => struct VaultStorage.Position)",
      "numberOfBytes": "32",
      "value": "t_struct(Position)9_storage"
     },
     "t_struct(Position)9_storage": {
      "encoding": "inplace",
      "label": "struct VaultStorage.Position",
      "numberOfBytes": "32",
      "members": [
       {
        "astId": 4,
        "contract": "src/Vault.sol:Vault",
        "label": "amount",
        "offset": 0,
        "slot": "0",
        "type": "t_uint128"
       },
       {
        "astId": 6,
        "contract": "src/Vault.sol:Vault",
        "label": "active",
        "offset": 16,
        "slot": "0",
        "type": "t_bool"
       },
       {
        "astId": 8,
        "contract": "src/Vault.sol:Vault",
        "label": "since",
        "offset": 17,
        "slot": "0",
        "type": "t_uint64"
       }
      ]
     },
     "t_uint128": {
      "encoding": "inplace",
      "label": "uint128",
      "numberOfBytes": "16"
     },
     "t_uint256": {
      "encoding": "inplace",
      "label": "uint256",
      "numberOfBytes": "32"
     },
     "t_uint64": {
      "encoding": "inplace",
      "label": "uint64",
      "numberOfBytes": "8"
     }
    }
   }
  },
  "snapshots/Vault.storage.json": {
   "storage": [
    {
     "astId": 11,
     "contract": "src/Vault.sol:Vault",
     "label": "owner",
     "offset": 0,
     "slot": "0",
     "type": "t_address"
    },
    {
     "astId": 16,
     "contract": "src/Vault.sol:Vault",
     "label": "positions",
     "offset": 0,
     "slot": "1",
     "type": "t_mapping(t_address,t_struct(Position)9_storage)"
    },
    {
     "astId": 20,
     "contract": "src/Vault.sol:Vault",
     "label": "__gap",
     "offset": 0,
     "slot": "2",
     "type": "t_array(t_uint256)48_storage"
    },
    {
     "astId": 44,
     "contract": "src/Vault.sol:Vault",
     "label": "version",
     "offset": 0,
     "slot": "50",
     "type": "t_uint256"
    },
    {
     "astId": 46,
     "contract": "src/Vault.sol:Vault",
     "label": "initialized",
     "offset": 0,
     "slot": "51",
     "type": "t_bool"
    }
   ],
   "types": {
    "t_address": {
     "encoding": "inplace",
     "label": "address",
     "numberOfBytes": "20"
    },
    "t_array(t_uint256)48_storage": {
     "encoding": "inplace",
     "label": "uint256[48]",
     "numberOfBytes": "1536",
     "base": "t_uint256"
    },
    "t_bool": {
     "encoding": "inplace",
     "label": "bool",
     "numberOfBytes": "1"
    },
    "t_mapping(t_address,t_struct(Position)9_storage)": {
     "encoding": "mapping",
     "key": "t_address",
     "label": "mapping(address => struct VaultStorage.Position)",
     "numberOfBytes": "32",
     "value": "t_struct(Position)9_storage"
    },
    "t_struct(Position)9_storage": {
     "encoding": "inplace",
     "label": "struct VaultStorage.Position",
     "numberOfBytes": "32",
     "members": [
      {
       "astId": 4,
       "contract": "src/Vault.sol:Vault",
       "label": "amount",
       "offset": 0,
       "slot": "0",
       "type": "t_uint128"
      },
      {
       "astId": 6,
       "contract": "src/Vault.sol:Vault",
       "label": "since",
       "offset": 16,
       "slot": "0",
       "type": "t_uint64"
      },
      {
       "astId": 8,
       "contract": "src/Vault.sol:Vault",
       "label": "active",
       "offset": 24,
       "slot": "0",
       "type": "t_bool"
      }
     ]
    },
    "t_uint128": {
     "encoding": "inplace",
     "label": "uint128",
     "numberOfBytes": "16"
    },
    "t_uint256": {
     "encoding": "inplace",
     "label": "uint256",
     "numberOfBytes": "32"
    },
    "t_uint64": {
     "encoding": "inplace",
     "label": "uint64",
     "numberOfBytes": "8"
    }
   }
  },
  "snapshots/Vault.abi.json": [
   {
    "type": "function",
    "name": "close",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
   },
   {
    "type": "function",
    "name": "deposit",
    "inputs": [
     {
      "name": "amount",
      "type": "uint128",
      "internalType": "uint128"
     }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
   },
   {
    "type": "function",
    "name": "initialize",
    "inputs": [
     {
      "name": "owner_",
      "type": "address",
      "internalType": "address"
     }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
   },
   {
    "type": "function",
    "name": "owner",
    "inputs": [],
    "outputs": [
     {
      "name": "",
      "type": "address",
      "internalType": "address"
     }
    ],
    "stateMutability": "view"
   },
   {
    "type": "function",
    "name": "positionOf",
    "inputs": [
     {
      "name": "account",
      "type": "address",
      "internalType": "address"
     }
    ],
    "outputs": [
     {
      "name": "amount",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "since",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "active",
      "type": "bool",
      "internalType": "bool"
     }
    ],
    "stateMutability": "view"
   },
   {
    "type": "function",
    "name": "version",
    "inputs": [],
    "outputs": [
     {
      "name": "",
      "type": "uint256",
      "internalType": "uint256"
     }
    ],
    "stateMutability": "view"
   },
   {
    "type": "event",
    "name": "Closed",
    "inputs": [
     {
      "name": "account",
      "type": "address",
      "indexed": true,
      "internalType": "address"
     }
    ],
    "anonymous": false
   },
   {
    "type": "event",
    "name": "Deposited",
    "inputs": [
     {
      "name": "account",
      "type": "address",
      "indexed": true,
      "internalType": "address"
     },
     {
      "name": "amount",
      "type": "uint256",
      "indexed": false,
      "internalType": "uint256"
     }
    ],
    "anonymous": false
   },
   {
    "type": "error",
    "name": "AlreadyInitialized",
    "inputs": []
   },
   {
    "type": "error",
    "name": "NotOwner",
    "inputs": [
     {
      "name": "caller",
      "type": "address",
      "internalType": "address"
     }
    ]
   },
   {
    "type": "error",
    "name": "ZeroAmount",
    "inputs": []
   }
  ]
 },
 "opcodes": {
  "foundry.toml": "[profile.default]\nsrc = \"src\"\nout = \"out\"\nsolc = \"0.8.30\"\noptimizer = true\n",
  "src/Vault.sol": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.28;\n\nimport {NonReentrant} from \"./utils/NonReentrant.sol\";\n\n/// @title Vault\n/// @notice Holds ether per account and keeps a short note with each deposit.\ncontract Vault is NonReentrant {\n    error NothingToWithdraw();\n    error TransferFailed();\n\n    event Deposited(address indexed account, uint256 amount, bytes note);\n    event Withdrawn(address indexed account, uint256 amount);\n\n    mapping(address => uint256) public balanceOf;\n    mapping(address => bytes) private notes;\n\n    function deposit(bytes calldata note) external payable {\n        balanceOf[msg.sender] += msg.value;\n        bytes memory kept = note;\n        notes[msg.sender] = kept;\n        emit Deposited(msg.sender, msg.value, kept);\n    }\n\n    function noteOf(address account) external view returns (bytes memory) {\n        bytes memory stored = notes[account];\n        bytes memory copy = new bytes(stored.length);\n        for (uint256 i = 0; i < stored.length; i++) {\n            copy[i] = stored[i];\n        }\n        return bytes.concat(copy);\n    }\n\n    function withdraw() external nonReentrant {\n        uint256 amount = balanceOf[msg.sender];\n        if (amount == 0) revert NothingToWithdraw();\n        balanceOf[msg.sender] = 0;\n        (bool ok, ) = msg.sender.call{value: amount}(\"\");\n        if (!ok) revert TransferFailed();\n        emit Withdrawn(msg.sender, amount);\n    }\n}\n",
  "src/utils/NonReentrant.sol": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.28;\n\n/// @notice Blocks a function from being entered again while it runs.\nabstract contract NonReentrant {\n    error Reentered();\n\n    bool private transient entered;\n\n    modifier nonReentrant() {\n        if (entered) revert Reentered();\n        entered = true;\n        _;\n        entered = false;\n    }\n}\n",
  "out/Vault.sol/Vault.json": {
   "abi": [
    {
     "type": "function",
     "name": "balanceOf",
     "inputs": [
      {
       "name": "",
       "type": "address",
       "internalType": "address"
      }
     ],
     "outputs": [
      {
       "name": "",
       "type": "uint256",
       "internalType": "uint256"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "function",
     "name": "deposit",
     "inputs": [
      {
       "name": "note",
       "type": "bytes",
       "internalType": "bytes"
      }
     ],
     "outputs": [],
     "stateMutability": "payable"
    },
    {
     "type": "function",
     "name": "noteOf",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "internalType": "address"
      }
     ],
     "outputs": [
      {
       "name": "",
       "type": "bytes",
       "internalType": "bytes"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "function",
     "name": "withdraw",
     "inputs": [],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "event",
     "name": "Deposited",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "indexed": true,
       "internalType": "address"
      },
      {
       "name": "amount",
       "type": "uint256",
       "indexed": false,
       "internalType": "uint256"
      },
      {
       "name": "note",
       "type": "bytes",
       "indexed": false,
       "internalType": "bytes"
      }
     ],
     "anonymous": false
    },
    {
     "type": "event",
     "name": "Withdrawn",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "indexed": true,
       "internalType": "address"
      },
      {
       "name": "amount",
       "type": "uint256",
       "indexed": false,
       "internalType": "uint256"
      }
     ],
     "anonymous": false
    },
    {
     "type": "error",
     "name": "NothingToWithdraw",
     "inputs": []
    },
    {
     "type": "error",
     "name": "Reentered",
     "inputs": []
    },
    {
     "type": "error",
     "name": "TransferFailed",
     "inputs": []
    }
   ],
   "bytecode": {
    "object": "0x6080604052348015600e575f5ffd5b506106f08061001c5f395ff3fe60806040526004361061003e575f3560e01c80632a6cb463146100425780633ccfd60b1461007757806370a082311461008d57806398b1e06a146100c6575b5f5ffd5b34801561004d575f5ffd5b5061006161005c36600461041d565b6100d9565b60405161006e9190610478565b60405180910390f35b348015610082575f5ffd5b5061008b610248565b005b348015610098575f5ffd5b506100b86100a736600461041d565b5f6020819052908152604090205481565b60405190815260200161006e565b61008b6100d436600461048a565b610362565b6001600160a01b0381165f90815260016020526040812080546060929190610100906104f8565b80601f016020809104026020016040519081016040528092919081815260200182805461012c906104f8565b80156101775780601f1061014e57610100808354040283529160200191610177565b820191905f5260205f20905b81548152906001019060200180831161015a57829003601f168201915b505050505090505f815167ffffffffffffffff81111561019957610199610530565b6040519080825280601f01601f1916602001820160405280156101c3576020820181803683370190505b5090505f5b825181101561021e578281815181106101e3576101e3610544565b602001015160f81c60f81b82828151811061020057610200610544565b60200101906001600160f81b03191690815f1a9053506001016101c8565b50806040516020016102309190610558565b60405160208183030381529060405292505050919050565b60ff5f5c161561026b5760405163b5dfd9e560e01b815260040160405180910390fd5b60015f805c60ff19168217905d50335f90815260208190526040812054908190036102a957604051630686827b60e51b815260040160405180910390fd5b335f818152602081905260408082208290555190919083908381818185875af1925050503d805f81146102f7576040519150601f19603f3d011682016040523d82523d5f602084013e6102fc565b606091505b505090508061031e576040516312171d8360e31b815260040160405180910390fd5b60405182815233907f7084f5476618d8e60b11ef0d7d3f06914655adb8793e28ff7f018d4c76d505d59060200160405180910390a2505f905060ff19815c16815d50565b335f908152602081905260408120805434929061038090849061056e565b9091555050604080516020601f84018190048102820181019092528281525f9184908490819084018382808284375f9201829052503381526001602052604090209394506103d492508491508390506105df565b50336001600160a01b03167f6e89d517057028190560dd200cf6bf792842861353d1173761dfa362e1c133f0348360405161041092919061069a565b60405180910390a2505050565b5f6020828403121561042d575f5ffd5b81356001600160a01b0381168114610443575f5ffd5b9392505050565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b602081525f610443602083018461044a565b5f5f6020838503121561049b575f5ffd5b823567ffffffffffffffff8111156104b1575f5ffd5b8301601f810185136104c1575f5ffd5b803567ffffffffffffffff8111156104d7575f5ffd5b8560208284010111156104e8575f5ffd5b6020919091019590945092505050565b600181811c9082168061050c57607f821691505b60208210810361052a57634e487b7160e01b5f52602260045260245ffd5b50919050565b634e487b7160e01b5f52604160045260245ffd5b634e487b7160e01b5f52603260045260245ffd5b5f82518060208501845e5f920191825250919050565b8082018082111561058d57634e487b7160e01b5f52601160045260245ffd5b92915050565b601f8211156105da57805f5260205f20601f840160051c810160208510156105b85750805b601f840160051c820191505b818110156105d7575f81556001016105c4565b50505b505050565b815167ffffffffffffffff8111156105f9576105f9610530565b61060d8161060784546104f8565b84610593565b6020601f82116001811461063f575f83156106285750848201515b5f19600385901b1c1916600184901b1784556105d7565b5f84815260208120601f198516915b8281101561066e578785015182556020948501946001909201910161064e565b508482101561068b57868401515f19600387901b60f8161c191681555b50505050600190811b01905550565b828152604060208201525f6106b2604083018461044a565b94935050505056fea2646970667358221220b7d75503d3aba56e75d99b9ede4386e3240dc96385ce42db6b825a52061515b564736f6c634300081e0033"
   },
   "deployedBytecode": {
    "object": "0x60806040526004361061003e575f3560e01c80632a6cb463146100425780633ccfd60b1461007757806370a082311461008d57806398b1e06a146100c6575b5f5ffd5b34801561004d575f5ffd5b5061006161005c36600461041d565b6100d9565b60405161006e9190610478565b60405180910390f35b348015610082575f5ffd5b5061008b610248565b005b348015610098575f5ffd5b506100b86100a736600461041d565b5f6020819052908152604090205481565b60405190815260200161006e565b61008b6100d436600461048a565b610362565b6001600160a01b0381165f90815260016020526040812080546060929190610100906104f8565b80601f016020809104026020016040519081016040528092919081815260200182805461012c906104f8565b80156101775780601f1061014e57610100808354040283529160200191610177565b820191905f5260205f20905b81548152906001019060200180831161015a57829003601f168201915b505050505090505f815167ffffffffffffffff81111561019957610199610530565b6040519080825280601f01601f1916602001820160405280156101c3576020820181803683370190505b5090505f5b825181101561021e578281815181106101e3576101e3610544565b602001015160f81c60f81b82828151811061020057610200610544565b60200101906001600160f81b03191690815f1a9053506001016101c8565b50806040516020016102309190610558565b60405160208183030381529060405292505050919050565b60ff5f5c161561026b5760405163b5dfd9e560e01b815260040160405180910390fd5b60015f805c60ff19168217905d50335f90815260208190526040812054908190036102a957604051630686827b60e51b815260040160405180910390fd5b335f818152602081905260408082208290555190919083908381818185875af1925050503d805f81146102f7576040519150601f19603f3d011682016040523d82523d5f602084013e6102fc565b606091505b505090508061031e576040516312171d8360e31b815260040160405180910390fd5b60405182815233907f7084f5476618d8e60b11ef0d7d3f06914655adb8793e28ff7f018d4c76d505d59060200160405180910390a2505f905060ff19815c16815d50565b335f908152602081905260408120805434929061038090849061056e565b9091555050604080516020601f84018190048102820181019092528281525f9184908490819084018382808284375f9201829052503381526001602052604090209394506103d492508491508390506105df565b50336001600160a01b03167f6e89d517057028190560dd200cf6bf792842861353d1173761dfa362e1c133f0348360405161041092919061069a565b60405180910390a2505050565b5f6020828403121561042d575f5ffd5b81356001600160a01b0381168114610443575f5ffd5b9392505050565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b602081525f610443602083018461044a565b5f5f6020838503121561049b575f5ffd5b823567ffffffffffffffff8111156104b1575f5ffd5b8301601f810185136104c1575f5ffd5b803567ffffffffffffffff8111156104d7575f5ffd5b8560208284010111156104e8575f5ffd5b6020919091019590945092505050565b600181811c9082168061050c57607f821691505b60208210810361052a57634e487b7160e01b5f52602260045260245ffd5b50919050565b634e487b7160e01b5f52604160045260245ffd5b634e487b7160e01b5f52603260045260245ffd5b5f82518060208501845e5f920191825250919050565b8082018082111561058d57634e487b7160e01b5f52601160045260245ffd5b92915050565b601f8211156105da57805f5260205f20601f840160051c810160208510156105b85750805b601f840160051c820191505b818110156105d7575f81556001016105c4565b50505b505050565b815167ffffffffffffffff8111156105f9576105f9610530565b61060d8161060784546104f8565b84610593565b6020601f82116001811461063f575f83156106285750848201515b5f19600385901b1c1916600184901b1784556105d7565b5f84815260208120601f198516915b8281101561066e578785015182556020948501946001909201910161064e565b508482101561068b57868401515f19600387901b60f8161c191681555b50505050600190811b01905550565b828152604060208201525f6106b2604083018461044a565b94935050505056fea2646970667358221220b7d75503d3aba56e75d99b9ede4386e3240dc96385ce42db6b825a52061515b564736f6c634300081e0033"
   }
  },
  "out/NonReentrant.sol/NonReentrant.json": {
   "abi": [
    {
     "type": "error",
     "name": "Reentered",
     "inputs": []
    }
   ],
   "bytecode": {
    "object": "0x"
   },
   "deployedBytecode": {
    "object": "0x"
   }
  }
 },
 "unrelated": {
  "foundry.toml": "[profile.default]\nsrc = \"src\"\nout = \"out\"\nsolc = \"0.8.30\"\noptimizer = true\nextra_output = [\"storageLayout\"]\n",
  "src/Vault.sol": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.28;\n\n/// @notice Storage shared by every version of the vault implementation behind the proxy.\nabstract contract VaultStorage {\n    struct Position {\n        uint128 amount;\n        uint64 since;\n        bool active;\n    }\n\n    address public owner;\n    mapping(address => Position) internal positions;\n\n    uint256[48] private __gap;\n}\n\n/// @title Vault\n/// @notice Implementation behind an ERC-1967 proxy. Records deposits per account.\ncontract Vault is VaultStorage {\n    error NotOwner(address caller);\n    error AlreadyInitialized();\n    error ZeroAmount();\n\n    event Deposited(address indexed account, uint256 amount);\n    event Closed(address indexed account);\n\n    uint256 public version;\n    bool private initialized;\n\n    function initialize(address owner_) external {\n        if (initialized) revert AlreadyInitialized();\n        initialized = true;\n        owner = owner_;\n        version = 1;\n    }\n\n    function deposit(uint128 amount) external {\n        if (amount == 0) revert ZeroAmount();\n        Position storage p = positions[msg.sender];\n        p.amount += amount;\n        if (!p.active) {\n            p.active = true;\n            p.since = uint64(block.timestamp);\n        }\n        emit Deposited(msg.sender, amount);\n    }\n\n    function close() external {\n        delete positions[msg.sender];\n        emit Closed(msg.sender);\n    }\n\n    function positionOf(address account) external view returns (uint128 amount, uint64 since, bool active) {\n        Position storage p = positions[account];\n        return (p.amount, p.since, p.active);\n    }\n}\n",
  "out/Vault.sol/Vault.json": {
   "abi": [
    {
     "type": "function",
     "name": "close",
     "inputs": [],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "function",
     "name": "deposit",
     "inputs": [
      {
       "name": "amount",
       "type": "uint128",
       "internalType": "uint128"
      }
     ],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "function",
     "name": "initialize",
     "inputs": [
      {
       "name": "owner_",
       "type": "address",
       "internalType": "address"
      }
     ],
     "outputs": [],
     "stateMutability": "nonpayable"
    },
    {
     "type": "function",
     "name": "owner",
     "inputs": [],
     "outputs": [
      {
       "name": "",
       "type": "address",
       "internalType": "address"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "function",
     "name": "positionOf",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "internalType": "address"
      }
     ],
     "outputs": [
      {
       "name": "amount",
       "type": "uint128",
       "internalType": "uint128"
      },
      {
       "name": "since",
       "type": "uint64",
       "internalType": "uint64"
      },
      {
       "name": "active",
       "type": "bool",
       "internalType": "bool"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "function",
     "name": "version",
     "inputs": [],
     "outputs": [
      {
       "name": "",
       "type": "uint256",
       "internalType": "uint256"
      }
     ],
     "stateMutability": "view"
    },
    {
     "type": "event",
     "name": "Closed",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "indexed": true,
       "internalType": "address"
      }
     ],
     "anonymous": false
    },
    {
     "type": "event",
     "name": "Deposited",
     "inputs": [
      {
       "name": "account",
       "type": "address",
       "indexed": true,
       "internalType": "address"
      },
      {
       "name": "amount",
       "type": "uint256",
       "indexed": false,
       "internalType": "uint256"
      }
     ],
     "anonymous": false
    },
    {
     "type": "error",
     "name": "AlreadyInitialized",
     "inputs": []
    },
    {
     "type": "error",
     "name": "NotOwner",
     "inputs": [
      {
       "name": "caller",
       "type": "address",
       "internalType": "address"
      }
     ]
    },
    {
     "type": "error",
     "name": "ZeroAmount",
     "inputs": []
    }
   ],
   "bytecode": {
    "object": "0x6080604052348015600e575f5ffd5b506103ad8061001c5f395ff3fe608060405234801561000f575f5ffd5b5060043610610060575f3560e01c806343d726d61461006457806354469aea1461006e57806354fd4d50146100815780638da5cb5b1461009d578063c4d66de8146100c7578063fd2d39c5146100da575b5f5ffd5b61006c610159565b005b61006c61007c3660046102f3565b61019d565b61008a60325481565b6040519081526020015b60405180910390f35b5f546100af906001600160a01b031681565b6040516001600160a01b039091168152602001610094565b61006c6100d5366004610320565b61029a565b6101296100e8366004610320565b6001600160a01b03165f908152600160205260409020546001600160801b03811691600160801b820467ffffffffffffffff1691600160c01b900460ff1690565b604080516001600160801b03909416845267ffffffffffffffff9092166020840152151590820152606001610094565b335f8181526001602052604080822080546001600160c81b0319169055517f13607bf9d2dd20e1f3a7daf47ab12856f8aad65e6ae7e2c75ace3d0c424a40e89190a2565b806001600160801b03165f036101c657604051631f2a200560e01b815260040160405180910390fd5b335f9081526001602052604081208054909183918391906101f19084906001600160801b0316610346565b92506101000a8154816001600160801b0302191690836001600160801b03160217905550805f0160189054906101000a900460ff1661025857805467ffffffffffffffff4216600160801b0268ffffffffffffffffff60801b1990911617600160c01b1781555b6040516001600160801b038316815233907f2da466a7b24304f47e87fa2e1e5a81b9831ce54fec19055ce277ca2f39ba42c49060200160405180910390a25050565b60335460ff16156102bd5760405162dc149f60e41b815260040160405180910390fd5b6033805460ff191660019081179091555f80546001600160a01b039093166001600160a01b031990931692909217909155603255565b5f60208284031215610303575f5ffd5b81356001600160801b0381168114610319575f5ffd5b9392505050565b5f60208284031215610330575f5ffd5b81356001600160a01b0381168114610319575f5ffd5b6001600160801b03818116838216019081111561037157634e487b7160e01b5f52601160045260245ffd5b9291505056fea2646970667358221220922c1486364843a4115b3ae78ca920e6629bd43170a36374e2c984f2d2b8fee064736f6c634300081e0033"
   },
   "deployedBytecode": {
    "object": "0x608060405234801561000f575f5ffd5b5060043610610060575f3560e01c806343d726d61461006457806354469aea1461006e57806354fd4d50146100815780638da5cb5b1461009d578063c4d66de8146100c7578063fd2d39c5146100da575b5f5ffd5b61006c610159565b005b61006c61007c3660046102f3565b61019d565b61008a60325481565b6040519081526020015b60405180910390f35b5f546100af906001600160a01b031681565b6040516001600160a01b039091168152602001610094565b61006c6100d5366004610320565b61029a565b6101296100e8366004610320565b6001600160a01b03165f908152600160205260409020546001600160801b03811691600160801b820467ffffffffffffffff1691600160c01b900460ff1690565b604080516001600160801b03909416845267ffffffffffffffff9092166020840152151590820152606001610094565b335f8181526001602052604080822080546001600160c81b0319169055517f13607bf9d2dd20e1f3a7daf47ab12856f8aad65e6ae7e2c75ace3d0c424a40e89190a2565b806001600160801b03165f036101c657604051631f2a200560e01b815260040160405180910390fd5b335f9081526001602052604081208054909183918391906101f19084906001600160801b0316610346565b92506101000a8154816001600160801b0302191690836001600160801b03160217905550805f0160189054906101000a900460ff1661025857805467ffffffffffffffff4216600160801b0268ffffffffffffffffff60801b1990911617600160c01b1781555b6040516001600160801b038316815233907f2da466a7b24304f47e87fa2e1e5a81b9831ce54fec19055ce277ca2f39ba42c49060200160405180910390a25050565b60335460ff16156102bd5760405162dc149f60e41b815260040160405180910390fd5b6033805460ff191660019081179091555f80546001600160a01b039093166001600160a01b031990931692909217909155603255565b5f60208284031215610303575f5ffd5b81356001600160801b0381168114610319575f5ffd5b9392505050565b5f60208284031215610330575f5ffd5b81356001600160a01b0381168114610319575f5ffd5b6001600160801b03818116838216019081111561037157634e487b7160e01b5f52601160045260245ffd5b9291505056fea2646970667358221220922c1486364843a4115b3ae78ca920e6629bd43170a36374e2c984f2d2b8fee064736f6c634300081e0033"
   },
   "storageLayout": {
    "storage": [
     {
      "astId": 11,
      "contract": "src/Vault.sol:Vault",
      "label": "owner",
      "offset": 0,
      "slot": "0",
      "type": "t_address"
     },
     {
      "astId": 16,
      "contract": "src/Vault.sol:Vault",
      "label": "positions",
      "offset": 0,
      "slot": "1",
      "type": "t_mapping(t_address,t_struct(Position)9_storage)"
     },
     {
      "astId": 20,
      "contract": "src/Vault.sol:Vault",
      "label": "__gap",
      "offset": 0,
      "slot": "2",
      "type": "t_array(t_uint256)48_storage"
     },
     {
      "astId": 44,
      "contract": "src/Vault.sol:Vault",
      "label": "version",
      "offset": 0,
      "slot": "50",
      "type": "t_uint256"
     },
     {
      "astId": 46,
      "contract": "src/Vault.sol:Vault",
      "label": "initialized",
      "offset": 0,
      "slot": "51",
      "type": "t_bool"
     }
    ],
    "types": {
     "t_address": {
      "encoding": "inplace",
      "label": "address",
      "numberOfBytes": "20"
     },
     "t_array(t_uint256)48_storage": {
      "encoding": "inplace",
      "label": "uint256[48]",
      "numberOfBytes": "1536",
      "base": "t_uint256"
     },
     "t_bool": {
      "encoding": "inplace",
      "label": "bool",
      "numberOfBytes": "1"
     },
     "t_mapping(t_address,t_struct(Position)9_storage)": {
      "encoding": "mapping",
      "key": "t_address",
      "label": "mapping(address => struct VaultStorage.Position)",
      "numberOfBytes": "32",
      "value": "t_struct(Position)9_storage"
     },
     "t_struct(Position)9_storage": {
      "encoding": "inplace",
      "label": "struct VaultStorage.Position",
      "numberOfBytes": "32",
      "members": [
       {
        "astId": 4,
        "contract": "src/Vault.sol:Vault",
        "label": "amount",
        "offset": 0,
        "slot": "0",
        "type": "t_uint128"
       },
       {
        "astId": 6,
        "contract": "src/Vault.sol:Vault",
        "label": "since",
        "offset": 16,
        "slot": "0",
        "type": "t_uint64"
       },
       {
        "astId": 8,
        "contract": "src/Vault.sol:Vault",
        "label": "active",
        "offset": 24,
        "slot": "0",
        "type": "t_bool"
       }
      ]
     },
     "t_uint128": {
      "encoding": "inplace",
      "label": "uint128",
      "numberOfBytes": "16"
     },
     "t_uint256": {
      "encoding": "inplace",
      "label": "uint256",
      "numberOfBytes": "32"
     },
     "t_uint64": {
      "encoding": "inplace",
      "label": "uint64",
      "numberOfBytes": "8"
     }
    }
   }
  }
 }
}''')


def main(argv):
    if len(argv) != 1 or argv[0] not in DATA:
        print("usage: python3 _release_fixture.py <%s>" % "|".join(DATA), file=sys.stderr)
        return 2
    for name, content in DATA[argv[0]].items():
        path = Path(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content if isinstance(content, str) else json.dumps(content, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
