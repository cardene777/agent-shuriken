---
topic: tokens
subject: Chainlink CCIP Cross-Chain Token (CCT) standard and token pool rate limits
checked: 2026-11-17
source: Chainlink, CCIP documentation (Cross-Chain Token standard, token pools, rate limit management)
---

# A CCIP token pool without rate limits lets any amount through

Chainlink's Cross-Chain Token standard lets a token issuer move its own token over CCIP through a token pool on each chain, which locks and releases or burns and mints. Each pool keeps an outbound and an inbound rate limit for every connected chain, set separately for standard transfers and for Faster-Than-Finality transfers, and changed by the pool's `rateLimitAdmin` role. A pool with no rate limit enabled allows unlimited transfers, and Chainlink strongly recommends setting them. Each limit is a token bucket: its capacity can be used at once, and it refills at a set rate per second. Pools from v1.6.1 on, including v2.0, convert incoming amounts before the inbound limit is applied, so both limits are set in the local chain's decimals; older pools did not enforce the inbound limit correctly when the decimals differed between chains.

For a design:

- Set an outbound and an inbound rate limit for every lane, and say who holds `rateLimitAdmin` on each chain
- Keep the same decimals on every chain where possible; set each limit in the local chain's decimals, and upgrade a pool older than v1.6.1 before the decimals differ
- Say whether the pools lock and release or burn and mint, and on which chain the canonical supply lives
