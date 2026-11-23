---
status: announced
checked: 2026-11-23
source: Ethereum Magicians: the thread `An Ethlabs view on post-quantum and post-AI timelines: pqai27` (first post 2026-11-11) and the thread `Thoughts on pqai, Hegota, and FOCIL` (first post 2026-11-17, replies 2026-11-18); ethereum/EIPs: EIP-8081 (the Hegotá meta EIP)
---

# pqai27 (a proposal to reach post-quantum and AI-resistant security in 2027)

A proposal by Ethlabs, posted on Ethereum Magicians on 2026-11-11, to make Ethereum secure against quantum computers and AI-driven attacks in 2027, and to rethink the coming upgrades around that goal.
It is a proposal under discussion, not a decision of the core developers.

| Point | What the first post says |
|---|---|
| Hegotá | pqai27 means rethinking the coming hard forks, Hegotá among them. Its sketch of the execution layer in Hegotá is Frames with a post-quantum signature scheme (SPHINCS) and post-quantum account EIPs |
| Quick slots | Ethlabs withdraws quick slots from Hegotá to put its resources into pqai27, and will work toward quicker slots in 2028 |
| FOCIL | FOCIL, the consensus-layer headliner of Hegotá, should be scheduled only in a way that keeps pqai27 achievable. Without FOCIL, the execution layer can ship Frames early |
| Frames | Frames (EIP-8141) are already scheduled as the Hegotá headliner and are on the critical path for pqai27 |
| Glamsterdam | Glamsterdam ships as planned |

## The case for shipping finished features in parallel

A separate thread, `Thoughts on pqai, Hegota, and FOCIL`, opened on 2026-11-17 by Thomas Thiery, argues to speed up pqai without stopping everything else.
Its first post asks to keep working on the features already scheduled for inclusion, and says Hegotá can keep moving with FOCIL and Frames, and that deferring FOCIL and others would not make the unready parts arrive sooner.
Two replies on 2026-11-18 differ.
Toni Wahrstätter would do the post-quantum work as slim feature forks (Frames, leanVM, and others) and bring FOCIL back once post-quantum consensus is known.
Ladislaus asks what deferring FOCIL would speed up, and calls reopening decisions to schedule features premature.

## Current status

As of 2026-11-23, the Hegotá meta (EIP-8081, status `Draft`) still lists FOCIL (EIP-7805) and Frames (EIP-8141) as `Scheduled for Inclusion`, and Quick Slots (EIP-8198) as `Considered for Inclusion`.
No change to the meta EIP has followed the proposal yet.
The status therefore stays `announced`.
When the meta EIP or a core developers' decision reflects the proposal, the facts come from that document.
FOCIL is covered by the `eip-7805-focil` item, and the aggregator role of post-quantum consensus by the `eip-8292-pq-attestation-aggregators` item.

## Not yet shipped

- Whether the core developers adopt the 2027 goal
- Which upgrade carries the post-quantum signatures, and when FOCIL and quick slots ship
