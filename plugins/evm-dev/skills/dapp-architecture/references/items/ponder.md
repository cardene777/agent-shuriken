---
topic: indexing
subject: Ponder
checked: 2026-11-17
source: Ponder, documentation and migration guide
---

# Ponder is a self-hosted TypeScript indexer on 0.x versions

Ponder is an open-source TypeScript framework for indexing EVM data. The team runs it on its own infrastructure and reads the indexed data directly from Postgres. Its documentation lists versions up to 0.17.

For a design:

- Pin the Ponder version, since it is still before 1.0 and the migration guide lists breaking changes between minor versions
- The indexer needs its own RPC provider and a Postgres database, which belong in Components and Environments
- It fits a team that wants the index in its own database next to the app's other data, without paying per query
