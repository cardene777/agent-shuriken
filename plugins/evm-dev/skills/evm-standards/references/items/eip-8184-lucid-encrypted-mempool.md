---
status: specified
checked: 2026-11-18
source: ethereum/EIPs: the EIP-8184, EIP-7805, EIP-8081 (the Hegotá meta EIP), and EIP-7732 documents; as a company's view, Shutter Network's documentation page `The Road Towards an Encrypted Mempool On Ethereum L1`; and as research, the HackMD explainer `New Threshold Encryption Schemes for Mempool Privacy and Timelock Encryption` and the IACR ePrint 2024/263 and 2024/669 papers
can: Sealed transactions would travel through the public mempool and inclusion lists and stay hidden until their order is fixed.
---

# EIP-8184 (LUCID, an encrypted mempool delivered through inclusion lists)

A standard that distributes sealed transactions (ST) through the public mempool and inclusion lists and hides their contents until the order is fixed.
The builder commits to transactions before seeing their contents, and key publishers release keys after the commitment.
It does not fix a single encryption scheme, and it also allows the sender to decrypt the transaction themselves.

| Step | What the document says |
|---|---|
| Send | The sender encrypts the transaction following instructions that the key publisher publishes outside the protocol, and broadcasts it to the public mempool as an ST. An ST consists of a ticket that pays the fees (ST ticket) and the ciphertext. The ticket holds a commitment to the key (`key_commitment`) and a commitment to the decrypted transaction (`reveal_commitment`) |
| Put into an inclusion list | EIP-7805 inclusion lists are extended so they can carry STs and bundles of STs from the same key publisher. One list can carry at most 2 of these in total (`MAX_ST_COMMITS_PER_IL`) |
| Commit | After learning the lists it must honor and the keys, the builder puts a commitment to the hashes of STs and ST bundles (ST-commitment) into its bid (`ExecutionPayloadBid`). The proposer puts the winning bid into the beacon block |
| Release keys | The key publisher looks at the commitments in the beacon block and releases keys after checking its own commitment, that the total gas of all commitments fits in the top-of-block share (`tob_gas_limit`, one eighth of the block gas limit), and that the beacon block will become canonical, for example after seeing attestations for it. When there is only one ST, the sender can also release the key |
| Vote on key timeliness | The PTC (the committee that votes on whether the payload arrived in time) votes, per commitment, on whether the key arrived by the deadline |
| Execute | Decrypted transactions run at the start of the next block. Execution is done against the header of the block that committed to the ticket, so the builder cannot slip in information after seeing the decryption |

Commitments are ordered by the top-of-block fee (`tob_fee`), highest first.
Releasing the key returns 127/128 of the top-of-block fee, and not releasing it loses all of it, so revealing contents only when it is convenient carries a price.
The document does not list EIP-7732 as a required standard, but it extends and uses the bid (`ExecutionPayloadBid`) and the PTC that EIP-7732 adds.

## Why it builds on FOCIL

The document's `Motivation` says that FOCIL relies on transactions being broadcast publicly, so it cannot give censorship resistance to transactions from which MEV can be extracted.
If transactions are broadcast while still encrypted and commitments are made before the contents are revealed, users no longer have to choose between protection from MEV and a trustless way into blocks.
It says this widens the range that inclusion lists actually protect.

On the other hand, the `Censorship resistance without FOCIL` section of `Rationale` says that even without FOCIL, transactions that create MEV can get moderate censorship resistance.
Because the contents and the signer of the decrypted transaction stay hidden until the key is released, builders cannot exclude a transaction by its contents.
It says the combination with FOCIL may be left out of the first implementation.
It says builders can still exclude transactions by the signer and the key publisher visible on the ticket.

## Why it does not fix a single encryption scheme

The document lists six conditions for an encryption scheme built into the protocol.

| Condition | Meaning |
|---|---|
| No setup interaction | Setup needs no interaction (silent setup), and public keys are small |
| Non-interactive decryption | Decryption needs no interaction among participants |
| No trusted setup | No setup that relies on trusting someone (trusted setup) is needed |
| Practical ciphertext size | Ciphertexts are a practical size |
| CCA2 security | It withstands chosen-ciphertext attacks |
| Quantum resistance | It has a credible path to quantum resistance |

It says no known scheme meets all six at Ethereum's scale, and waiting for advances in cryptography would delay things too much, so it does not fix a single scheme.

The `Trust graph` section proposes, for a later version, a form based on the trust links of EIP-8105.
Unlike EIP-8105, it does not forbid commitments from untrusted key publishers coming first, except when the limit (`max_preceding_untrusted_commitments`) is set to 0.
The EIP-8105 form is covered by the `eip-8105-encrypted-mempool` item.

## The case for combining inclusion lists and encrypted mempools

This section is a company's view, not the content of the document.

Shutter Network's documentation page `The Road Towards an Encrypted Mempool On Ethereum L1` describes the two mechanisms as follows.

| Mechanism | What the page says |
|---|---|
| Encrypted mempools | Builders cannot see the details of encrypted transactions, so they cannot front-run or censor them. A block proposer could still censor encrypted transactions simply because they are encrypted |
| Inclusion lists (FOCIL) | FOCIL can force the proposer to include such transactions as well, which improves the censorship resistance of an encrypted mempool. The page also says an encrypted mempool is highly beneficial for inclusion lists to be widely adopted |

EIP-8184 puts sealed transactions into inclusion lists, so it has the same shape as the combination on the page.
The EIP-8184 document does not cite this page as a source.

## Research on encryption that meets some of the conditions

This section is researchers' views, not the content of the document.

The HackMD explainer `New Threshold Encryption Schemes for Mempool Privacy and Timelock Encryption` presents two threshold encryption schemes that keep mempool transactions hidden until execution.

| Scheme | What the explainer and papers say | Relation to the six conditions |
|---|---|---|
| Silent Threshold Encryption (IACR ePrint 2024/263, `Threshold Encryption with Silent Setup`, CRYPTO 2024) | The joint public key is derived by a fixed computation from public keys that each participant made locally. Each committee member makes a partial decryption locally, and anyone can combine them | It meets no setup interaction and non-interactive decryption. The scheme relies on pairings, and its security is shown in the Generic Group Model. A path to quantum resistance is not in the paper's abstract |
| Batched Threshold Encryption (IACR ePrint 2024/669, USENIX Security 2024) | It decrypts a batch of ciphertexts together, with communication that does not depend on the batch size | It reduces the communication for decryption, but the explainer says it makes the problem of heavy setup worse |

## Current status

The document's status is `Draft`, and it was created on 2026-03-04.
It lists EIP-2718 and EIP-7805 as required standards.
When checked on 2026-11-18, it was in none of the four lists (`Scheduled for Inclusion`, `Considered for Inclusion`, `Proposed for Inclusion`, `Declined for Inclusion`) of the Hegotá meta EIP (EIP-8081, status `Draft`).
The required EIP-7805 (FOCIL) is `Draft`, and the Hegotá meta EIP lists it as `Scheduled for Inclusion`.

## Not yet shipped

It has not become `Final` and does not run on mainnet.
It says the mechanism by which the key publisher of a multi-key bundle bears the penalty for failed decryption in place of the sender is left out of the first version and can be added in a later upgrade.
The value of `DOMAIN_LUCID_KEY_TIMELINESS`, used to sign the key timeliness votes, is not yet decided in the document.
Which upgrade it will go into has not been decided.
