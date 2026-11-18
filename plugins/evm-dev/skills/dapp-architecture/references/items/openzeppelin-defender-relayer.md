---
topic: transactions
subject: OpenZeppelin Defender and OpenZeppelin Relayer
checked: 2026-11-18
source: OpenZeppelin, Doubling Down on Open Source and Phasing Out Defender, the Defender sunset FAQ, and the openzeppelin-relayer repository
---

# OpenZeppelin Defender was retired on 1 July 2026

OpenZeppelin retired the hosted Defender service on 1 July 2026. Its Relayer and Monitor continue as open-source tools that the team hosts itself, shipped as Docker images and released under the AGPL v3; OpenZeppelin also takes requests for a hosted setup.

For a design:

- Do not choose Defender Relayers, Actions (autotasks), or Sentinels; a design that relies on them will not run
- A self-hosted OpenZeppelin Relayer is a service the team operates: name who runs it, where its signing key is kept, and how its balance and nonce are watched
- The AGPL v3 applies to the relayer software, so check it with whoever approves licenses before changing and offering it as a service
