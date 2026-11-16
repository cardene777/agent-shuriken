---
topic: oracles
subject: Chainlink Data Feeds
checked: 2026-11-17
source: Chainlink, Deprecation of Chainlink Data Feeds and the developer changelog (feeds scheduled for deprecation)
---

# Chainlink deprecates feeds with little use, in batches through 2026

Chainlink schedules Data Feeds for deprecation when they have low or no usage or no path to economic sustainability, and announces them in batches in its changelog; batches in 2026 had shutdown dates from March to November 2026. Monitoring of a feed stops two weeks before its deprecation date, after which its answer can stop updating.

For a design:

- Check that each feed the design names is not on the list of feeds scheduled for deprecation, and say what the contract does if a feed stops
- Read `latestRoundData` and reject an answer that is zero, negative, or older than the feed's heartbeat; never trust `answer` alone
- On a rollup, read the sequencer uptime feed and refuse prices for a grace period after the sequencer comes back
- Keep the feed address settable through the timelock, so a deprecated feed can be replaced without an upgrade
