---
topic: messaging
subject: OP Stack Superchain interop and SuperchainERC20 (ERC-7802)
checked: 2026-11-17
source: Optimism, Superchain interop documentation and the SuperchainERC20 page
---

# SuperchainERC20 tokens can be deployed, but interop between OP Stack chains is not ready everywhere

SuperchainERC20 (ERC-7802) is a token standard for moving tokens between OP Stack chains through native interop instead of a third-party bridge. Token contracts that follow it are deployed on mainnet, but the interop upgrade that carries the messages is opt-in, rolls out chain by chain, and Optimism's interop documentation calls it in active development and not ready for production. A chain that has not taken the upgrade cannot receive SuperchainERC20 transfers, and no date for interop on every chain has been given.

For a design:

- Do not rely on Superchain interop to move assets until both chains have taken the upgrade; check each chain's status
- When a token follows ERC-7802 for later interop, say which bridge moves it until then
- Check the status of ERC-7802 with the evm-standards skill
