# Review checklist for a financial-standards design

Go through this list after `verify` passes. A design that fails any rule in the first table is not finished: fix it and check again. Say which rules you could not judge and why.

## Rules a design must never break

| Rule | What fails it |
|---|---|
| Nothing private on chain | The original message, names, addresses, account numbers or card numbers, the purpose of a payment, or free-text remittance information is stored in contract state or in events |
| Commitments, not bare hashes | Confidentiality is claimed from a hash of the payload alone, without a random salt, a domain that separates its uses, and a stated way for an authorized party to recompute it |
| Public data stays public | Data on a public chain is called private because the API needs a login |
| The contract does not parse XML | The contract parses XML, validates against a schema or a profile, or correlates messages, instead of accepting signed evidence produced off-chain |
| Correlation has a reason | Messages are treated as one case because of an external message ID alone, with no internal case ID and no recorded reason for linking them |
| Reports are not settlement | A status report, a statement, or a notification is treated as settlement or as the direct cause of a state change; it is not settlement finality |
| The ledger is not the law | On-chain state is presented as the legal finality of a bank, a clearing house, a central securities depository, or a regulator |
| Someone is allowed, and can be revoked | Anyone can change state, or permissions and their revocation are not defined |
| Corrections append | Corrections, cancellations, expiry, or retention are handled by overwriting or deleting records instead of appending new ones that refer to the old |
| The version and profile are fixed | The standard's version and profile, and the messages or data model used, are not pinned |
| Off-chain responsibilities are separated | Keeping the original, managing personal data and keys, validation, correlation, signing, and audit disclosure have no owner or no defined boundary between them |
| Signed evidence cannot be replayed | The signer, authorization, key ID, revocation, nonce, expiry, signing domain, and the protection against replay on another chain or contract are not defined |
| Writes are idempotent | Saving off-chain and sending to the chain are assumed to happen exactly once; there is no idempotent retry, resend, handling of chain reorganizations, or reconciliation |

## Each section is complete

- Standard and business: the flow, the states, and how each message element maps to a meaning and to evidence
- Application: for each operation, the starting point, preconditions, input, validation and rejection, the results on success, failure, retry, and cancellation, the business state, what is audited or disclosed, and a pointer to Integration
- Data and storage: the formats, schema versions, serialization, IDs, times, digests, salts, and key references, and the structure, references, indexes, placement reasons, and encryption at rest of each store
- On-chain and Off-chain: each component's responsibility, what it stores, who may access it, how long it is kept, how it is revoked, and the limits of upgrades
- Integration: the IDs, references, commitments, and signatures at each boundary, inputs and outputs, why a call is rejected, the outbox, resending, and reconciliation
- Security and operations: personal data, who may see what, access, keys, audit, threats, and the legal and contractual assumptions; change, correction, failure, notification, recovery, retention, deletion, and who owns each
- Verification and delivery: acceptance criteria for conformance, storage, signatures, boundaries, failures, and a minimal end-to-end flow; build order, environments, validation of older versions, and rollback
- Open decisions: each assumption with who decides and the condition for deciding
- The design does not include contracts, schemas, ABIs, API definitions, tests, or scripts unless the user asked for them
