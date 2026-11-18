---
topic: indexing
subject: Ponder
checked: 2026-11-18
source: Ponder, documentation, migration guide, the ponder package on the npm registry, and the ponder repository source at the 0.18.9 tag; Base, Transaction Finality; Ethereum Foundation, Single slot finality
---

# Ponder is a self-hosted TypeScript indexer on 0.x versions

Ponder is an open-source TypeScript framework for indexing EVM data. The team runs it on its own infrastructure and reads the indexed data directly from Postgres. Its npm releases reached 0.18.0 in October 2026 and 0.18.9 in November 2026, still before 1.0.

In 0.18.x each chain's `reorgWindow` is a number of seconds between block timestamps, an integer from 0 to 600 that defaults to 180. Ponder treats a block as finalized once it is older than that window, not when the chain finalizes it, and stops with a fatal error when a reorg reaches past that point. An Ethereum block takes about 15 minutes to finalize, and a Base block about 20 minutes, until its batch on Ethereum is finalized; both are longer than 600 seconds. The chain option `maxRequestsPerSecond` is deprecated in 0.18.x, and Ponder adjusts each RPC's request rate to the provider's limits by itself.

For a design:

- Pin the Ponder version, since it is still before 1.0 and the migration guide lists breaking changes between minor versions
- The indexer needs its own RPC provider and a Postgres database, which belong in Components and Environments
- Judge finality from the RPC's `finalized` block, not from `reorgWindow`, and plan to re-index from the deployment block when a reorg goes deeper than the window
- It fits a team that wants the index in its own database next to the app's other data, without paying per query
