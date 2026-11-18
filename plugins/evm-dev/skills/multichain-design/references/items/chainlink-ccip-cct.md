---
topic: tokens
subject: Chainlink CCIP Cross-Chain Token (CCT) standard and token pool rate limits
checked: 2026-11-18
source: Chainlink, CCIP documentation (Cross-Chain Token standard, token pools, rate limit management including how rate limits work, common scenarios, and emergency actions, token units and decimals) and the chainlink-ccip repository at contracts-ccip-v2.0.0 (`RateLimiter.sol`)
---

# A CCIP token pool without rate limits lets any amount through

Chainlink's Cross-Chain Token standard lets a token issuer move its own token over CCIP through a token pool on each chain, which locks and releases or burns and mints. Each pool keeps an outbound and an inbound rate limit for every connected chain; a v2.0 pool can also set a separate limit for Faster-Than-Finality transfers, which otherwise use the standard one. The pool's owner and its `rateLimitAdmin` role can change the limits. A pool with no rate limit enabled allows unlimited transfers, and Chainlink strongly recommends setting them. Each limit is a token bucket: its capacity can be used at once, and it refills at a set rate per second. Pools from v1.6.1 on, including v2.0, set both limits in the local chain's decimals; inbound limits on some older pools were in the source chain's decimals, and v1.5.1 pools did not enforce the inbound limit correctly when the decimals differed between chains.
On a v2.0 pool every change to a limit's configuration sets its available tokens to the new capacity, a full refill, so lowering a limit during a drain hands out a full bucket of the new size; v1.x pools keep refilling at the normal rate after a change. Chainlink's way to halt a lane is a capacity and rate of 0 with the limit still enabled, set by the owner or `rateLimitAdmin` on both chains and for the Faster-Than-Finality bucket too; disabling a limit removes it, and only the owner can remove the lane.

For a design:

- Set an outbound and an inbound rate limit for every lane, with each inbound limit 5 to 10 percent above the matching outbound limit as Chainlink advises, and say who owns each pool and who holds `rateLimitAdmin` on each chain
- Keep the same decimals on every chain where possible; set each limit in the local chain's decimals, and upgrade a pool older than v1.6.1, or read on chain which decimals its inbound limit uses, before the decimals differ
- Say whether the pools lock and release or burn and mint, and on which chain the canonical supply lives
- Write the incident step as setting the lane's limits to 0 with the limit enabled, not as lowering them, and say who can do it on each chain
