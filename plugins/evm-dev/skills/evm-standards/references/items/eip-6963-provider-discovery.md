---
status: specified
checked: 2026-11-11
source: ethereum/EIPs: the EIP-6963 document; reown-com/appkit: the source code
---

# EIP-6963 (Finding multiple wallets installed in the browser)

A standard that lets a dapp find all wallet extensions installed in the browser and choose among them.
Instead of competing for a single `window.ethereum`, wallets announce themselves through browser window events.

| Point | What the document says |
|---|---|
| Announce | A wallet dispatches the `eip6963:announceProvider` event |
| Request | When a dapp dispatches the `eip6963:requestProvider` event, wallets announce themselves again |
| What is announced | A unique `uuid`, a name, an icon, and `rdns`, a reverse domain name |
| Identification | `rdns` stays the same across sessions, so a dapp can remember the wallet chosen before |

## Current status

The document's status is `Final`, and its type is `Interface`.
It was created on 2023-05-01 and requires EIP-1193 (the wallet provider interface).

In the current source of Reown's AppKit (formerly Web3Modal), wallets found through EIP-6963 are added as connection options when `enableEIP6963` is not passed.
This is because `appkit-base-client.ts` turns it on with `options.enableEIP6963 !== false`, and the wagmi connector skips adding them only when the value is `false`.
The type annotation in `OptionsController.ts` in the same repository says `@default false`, which contradicts what the source does.
This was checked on 2026-11-11 by reading the repository's default branch.

## Not yet shipped

Nothing in the standard remains.
Whether wallets and dapp tools outside AppKit support it has not been checked.
