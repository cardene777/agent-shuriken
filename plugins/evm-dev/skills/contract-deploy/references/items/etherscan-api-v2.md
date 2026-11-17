---
topic: verification
subject: Etherscan API V2 and the Free tier's chain coverage
checked: 2026-11-17
source: Etherscan, V2 migration guide; Etherscan Information Center, Etherscan API V1 will be fully deprecated by 15th August 2025, and what's changing in the free API tier coverage and why; Etherscan, API changelog
---

# Etherscan's V1 API is gone; V2 uses one key for every chain, and the Free tier no longer covers every chain

Etherscan deprecated its V1 endpoints on 15 August 2025. V2 serves every supported chain from one base path with a `chainid` parameter and one Etherscan API key; keys from the old per-chain explorers do not work. Since late 2025 the Free tier has covered fewer chains: Gnosis moved to paid plans from 1 September 2026 and HyperEVM from 1 December 2026, Arbitrum, Linea, Celo, and Katana share one Free-tier pool per chain that can run out, support for Scroll, opBNB, and Blast ended during 2026, and support for Abstract Mainnet ends on 30 November 2026. The changelog says source code and ABI endpoints stay free on all plans.

For a deployment:

- Check the target chain in Etherscan's supported chains list and the plan the user has before planning to verify there
- Pass the key through the tool's own setting (`ETHERSCAN_API_KEY` for Foundry, a `configVariable` in Hardhat 3) and never print it
- When Etherscan does not cover the chain, verify on Sourcify or the chain's Blockscout instead
