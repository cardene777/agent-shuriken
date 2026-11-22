---
status: specified
checked: 2026-11-11
source: The =nil; Foundation blog (its list of posts and the launch of the first testnet), =nil;'s official documentation (Overview), and =nil;'s repository (the README, release notes, and commit history of NilFoundation/nil)
---

# =nil; zkSharding

=nil; is an Ethereum L2 that splits the whole state across several execution shards and checks the state transitions inside a shard with zero-knowledge proofs.
The =nil; Foundation calls this form zkSharding.
After testnet v1 on 2024-10-30, no mainnet could be confirmed, and repository updates stopped on 2025-07-15.

| Point | What the official documents say |
|---|---|
| How shards are split | Transactions are processed in execution shards, each holding part of the state. The main shard exists only for synchronization, and contracts can be deployed only on execution shards |
| How blocks link | The README says the main shard points to the latest block of every execution shard, and a new block of an execution shard points to the latest block of the main shard |
| Proofs | A sync committee handles the data store and makes zero-knowledge proofs of the state transitions inside the shards |
| Checking the whole | The documentation says the validity of every shard can be shown with one zero-knowledge proof |
| Calls across shards | Built into the protocol; a contract can call a contract on another shard asynchronously |
| Ethereum's role | The documentation says Ethereum handles the data store and consensus, and =nil; is the execution layer |
| Testnet | The blog published testnet v1 on 2024-10-30, and said two more testnets would come before mainnet, with mainnet at the end of 2025 |
| Repository | The last release is nil_cli on 2025-05-15, and the last push was on 2025-07-15 |

## Current status

=nil; went only as far as testnet, and no mainnet can be confirmed.
The blog's latest post is from 2024-11-04, and there are no posts on the launch of testnet v2, testnet v3, or mainnet.
The documentation notes that some of the features it describes are not yet in a form developers can use.

The 2024 post's "zkSharding brings about the execution sharding of Eth 2.0" stopped at the testnet stage.

## Not yet shipped

Mainnet and testnets v2 and v3 are not found on the blog or in the repository.
No announcement of whether the =nil; Foundation stopped development was found, and none has been checked.
Which Ethereum contract verifies the zero-knowledge proofs is not written in the pages read and has not been checked.
