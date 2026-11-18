---
topic: storage
subject: IPFS public gateways and pinning services
checked: 2026-11-18
source: IPFS blog, IPFS is moving beyond the sponsored gateways (2026-08-25); IPFS Newsletter (April 2026); NFT.Storage blog, 28 June 2024 community update
---

# Public IPFS gateways are rate-limited, and free pinning services have closed

The IPFS project began rate limiting hotlinked and backend traffic on the public gateways `ipfs.io` and `dweb.link` and redirects browser visitors to a service worker gateway that verifies content in the browser. Apps that hotlinked images, metadata, or scripts are told to use `@helia/verified-fetch` or the service worker, and backends to run their own gateway or node.

Free pinning has also closed: NFT.Storage Classic stopped taking uploads on 30 June 2024, and the Storacha developer upload and IPFS service, which took over web3.storage, was announced to shut down on 31 May 2026; Storacha's site now redirects to Fil One.

For a design:

- Do not serve content referenced on chain only through `ipfs.io` or `dweb.link`, and do not rely on NFT.Storage Classic, web3.storage, or Storacha uploads
- Pin content in more than one place the team controls or pays for, and say who pays and for how long
- Read content with verified retrieval in the frontend, or through a gateway the team runs
