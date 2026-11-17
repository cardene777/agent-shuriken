---
topic: deployment
subject: CREATE2 factories for the same address on every chain (ERC-7955, Safe Singleton Factory, CreateX)
checked: 2026-11-17
source: Ethereum, ERC-7955 specification (Draft); Safe Research, Meet ERC-7955: No Private Key Required; Ethereum Magicians, EIP-7997 Deterministic Factory Predeploy discussion
---

# The same address needs the same factory, salt, and code on every chain

A contract deployed with CREATE2 gets the same address on every chain only when the factory has the same address there and the salt and the full creation code, constructor arguments included, are the same. The Safe Singleton Factory is permissioned: Safe must deploy it to a new chain. ERC-7955, a Draft, describes a permissionless CREATE2 factory deployed to the same address through EIP-7702, which can in turn deploy CreateX or other factories; it does not work on chains that accept only EIP-155 replay-protected transactions, and a different gas schedule can make it undeployable. EIP-7997 proposes a predeployed factory instead.

For a design:

- Name the factory and check that it exists at the expected address on every target chain before relying on it
- Keep the salt and the creation code the same on every chain, and pass chain-specific values through an initializer protected against front-running instead of the constructor
- After deployment, compare the code at each address across chains, and record the addresses
- Check the status of ERC-7955 and EIP-7997 with the evm-standards skill
