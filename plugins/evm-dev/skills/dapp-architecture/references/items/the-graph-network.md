---
topic: indexing
subject: The Graph Network and Subgraph Studio
checked: 2026-11-17
source: The Graph, The Road to Sunsetting the Hosted Service and the Sunrise upgrade FAQ
---

# The Graph's hosted service is gone; subgraphs run on The Graph Network

The Graph's free hosted service stopped on 12 June 2024. Every subgraph query is now served by The Graph Network, and subgraphs are published from Subgraph Studio, which the shutdown did not change.

For a design:

- Do not plan on the hosted service or on endpoints under its old domain; a design that names it is out of date
- A subgraph on the network is queried with an API key and paid for per query, so name who holds the key and pays, and keep the key out of the frontend bundle when it is billed to the team
- Check that the chain is still supported in Subgraph Studio before choosing it, since support for a chain can end
- Self-hosting graph-node or using another indexer is the fallback when the network does not support the chain or the cost does not fit
