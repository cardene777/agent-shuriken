---
topic: oracles
subject: Chainlink Data Feeds
checked: 2026-11-18
source: Chainlink, Deprecation of Chainlink Data Feeds and the developer changelog (feeds scheduled for deprecation)
---

# Chainlink deprecates feeds with little use, in batches through 2026

Chainlink schedules Data Feeds for deprecation when they have low or no usage or no path to economic sustainability, and announces them in batches in its changelog. The batches announced in 2026 that named a date had shutdown dates from March to November 2026, five to fourteen days after the announcement, and Data Feeds support ended on whole networks, Fantom on 12 January and Ronin on 16 February 2026. Chainlink stops monitoring the data quality of a feed two weeks before its deprecation date, after which its answer can stop updating.

For a design:

- Check that each feed the design names is not on the list of feeds scheduled for deprecation, and say what the contract does if a feed stops
- Read `latestRoundData` and reject an answer that is zero, negative, or older than the feed's heartbeat; never trust `answer` alone
- On a rollup, read the sequencer uptime feed and refuse prices for a grace period after the sequencer comes back
- Keep the feed address settable through the timelock, so a deprecated feed can be replaced without an upgrade
