---
topic: messaging
subject: OP Stack Superchain interop and SuperchainERC20 (ERC-7802)
checked: 2026-11-18
source: Optimism, Superchain interop documentation, the SuperchainERC20 pages, the interop preparation notice, and the Lagoon hardfork page
---

# SuperchainERC20 tokens can be deployed, but interop between OP Stack chains is not live on any mainnet

SuperchainERC20 (ERC-7802) is a token standard for moving tokens between OP Stack chains through native interop instead of a third-party bridge. Tokens can be deployed under it now, but interop, which carries the messages, ships in the Lagoon hardfork, whose specification is not final, and Optimism says some features may be experimental. Each chain activates Lagoon on its own schedule and accepts messages only from the chains in its dependency set. Optimism targets OP Sepolia and Unichain Sepolia for 10 December 2026, and OP Mainnet and Unichain for 11 January 2027, pending governance approval; other OP Stack chains have no date.

For a design:

- Do not rely on Superchain interop to move assets until both chains have activated it and list each other in their dependency sets; check each chain's status
- When a token follows ERC-7802 for later interop, say which bridge moves it until then
- Check the status of ERC-7802 with the evm-standards skill
