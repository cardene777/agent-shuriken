---
topic: deployment
subject: CREATE2 factories for the same address on every chain (ERC-7955, Safe Singleton Factory, CreateX)
checked: 2026-11-18
source: Ethereum, ERC-7955 specification (Draft), EIP-7997 specification (Last Call), and EIP-7773 Glamsterdam upgrade; Safe Research, Meet ERC-7955: No Private Key Required; pcaversaccio, CreateX source (`CreateX.sol`, v1.0.0 and main)
---

# The same address needs the same factory, salt, and code on every chain

A contract deployed with CREATE2 gets the same address on every chain only when the factory has the same address there and the salt and the full creation code, constructor arguments included, are the same. The Safe Singleton Factory is permissioned: Safe must deploy it to a new chain. Factories deployed with a keyless transaction (Nick's method) do not work on chains that accept only EIP-155 replay-protected transactions, and a different gas schedule can make them undeployable. ERC-7955, a Draft, describes a permissionless CREATE2 factory deployed to the same address through EIP-7702 on any chain that supports EIP-1014 and EIP-7702, which can then deploy any contract, other factories such as CreateX included; anyone can front-run its deployment to delay it. EIP-7997, in Last Call and scheduled for Ethereum's Glamsterdam upgrade, makes the keyless factory at 0x4e59b44847b379578588920cA78FbF26c0B4956C a required part of a chain's state.
CreateX reads the salt's first 20 bytes and its 21st byte. When the 20 bytes are the caller's address, only that caller reaches the address; when they name any other non-zero address, CreateX does not revert but hashes the salt, so the contract lands at a different address without that protection. A 21st byte of 0x01 after the caller's or the zero address mixes in the chain ID, which gives a different address on each chain.

For a design:

- Name the factory and check that it exists at the expected address on every target chain before relying on it
- Keep the salt and the creation code the same on every chain, and pass chain-specific values through an initializer protected against front-running instead of the constructor
- With CreateX, deploy from the account the salt names, and choose the 21st byte for the same address on every chain or one per chain
- After deployment, compare the code at each address across chains, and record the addresses
- Check the status of ERC-7955 and EIP-7997 with the evm-standards skill
