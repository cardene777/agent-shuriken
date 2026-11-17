---
topic: layout
subject: ERC-7201 namespaced storage, which solc's layout output leaves out
checked: 2026-11-17
source: ERC-7201, Namespaced Storage Layout; OpenZeppelin Contracts 5.x documentation, Upgradeable contracts; forge 1.5.1 and solc 0.8.30 run on a throwaway project
---

# Variables in a namespaced struct are invisible to the storage layout output

ERC-7201 puts a contract's variables in a struct stored at a slot derived from a namespace, marked with `/// @custom:storage-location erc7201:<namespace>` on the struct. The slot is `keccak256(abi.encode(uint256(keccak256("<namespace>")) - 1)) & ~bytes32(uint256(0xff))`, and the contract reaches the struct through inline assembly. OpenZeppelin Contracts Upgradeable 5.x keeps all its state this way.

solc's `storageLayout` lists only ordinary state variables. A contract that keeps everything in namespaced structs shows an empty layout, so a layout comparison passes whatever changed inside the structs.

For a release:

- Compare each namespaced struct by reading it in both versions: members may only be appended at the end, never removed, reordered, or retyped
- Never change the namespace string, since that moves the whole struct
- OpenZeppelin's upgrade check validates namespaced structs; to do that it recompiles a modified copy of the sources, and may download the matching solc from the Solidity binaries server when it is not cached
