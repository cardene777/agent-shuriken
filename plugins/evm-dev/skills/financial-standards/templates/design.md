# Fill in: the name of the design

Fill in: one paragraph on what this design lets the team build, what it covers, and what it leaves out.

Each section decides one part of the implementation and points to the others instead of repeating them. Open decisions holds every decision, assumption, and open question; other sections link to it.

## Standard and business

Fill in: the standard, its version, the profile or usage guideline (for example CBPR+ and its release), the messages or data model used, and the date each was checked against the official source, written as YYYY-MM-DD.
Fill in: the jurisdictions, the participants and their roles, and what is out of scope.
Fill in: the business flow as events and states, and how each message or element maps to a business meaning, a state change, and a piece of evidence.
Fill in: how messages that belong to one case are correlated, with the internal case ID and the reason two messages are linked.

## Application

Fill in: each operation a user or an external system performs: who starts it, what must already be true, the input, how it is validated or rejected, the result on success, failure, retry, and cancellation, the business state after it, and what is audited or disclosed. Point to Integration for the boundary each operation crosses.

## Data and storage

Fill in: the logical entities and a data dictionary.
Fill in: the formats and versions of the original message, the canonical record, the validation result, and the evidence, with how each is serialized deterministically, and how IDs, times, digests, salts, and key references are written.
Fill in: what goes in the application database, in protected storage, in contract storage, and in events, with the reason for each placement. Classify every field as on-chain, committed only, protected off-chain, or conditional.
Fill in: indexes, references between stores, and how data at rest is encrypted.

## On-chain

Fill in: the contracts and what each is responsible for (for example participant authority, profile registry, evidence ledger, case state machine), their states and events and what each means, who may call what, and the rules for accepting evidence, including signature checks.
Fill in: how a correction or cancellation is linked to what it corrects, and the limits of upgrades and pauses.

## Off-chain

Fill in: each off-chain component (receiving, validating, normalizing and correlating, keeping the original, managing personal data and keys, signing, audit disclosure): who runs it, what it does, its inputs and outputs, and which boundaries it calls.

## Integration

Fill in: a context diagram and a data flow showing the applications, services, stores, and ledger, and the trust boundaries between them.
Fill in: for each boundary, the IDs, references, commitment, and signature that cross it, the required inputs and outputs, who calls it, why a call is rejected, the nonce and expiry, the outbox, resending, chain reorganizations, and reconciliation.
Fill in: what a commitment binds (domain, chain ID, ledger ID, case ID, standard and profile version, content digest, random salt) and who may recompute it.

## Security and operations

Fill in: how personal data and financial secrets are classified, who may see what, access control, keys, audit, threats, and the regulatory, contractual, and legal-finality assumptions and what is out of scope.
Fill in: change management, key revocation, disputes, corrections, cancellations, expiry, monitoring, notifications, recovery from failures, retention periods, deletion and legal hold, and who is responsible for each.

## Verification and delivery

Fill in: the acceptance criteria for conformance to the standard and profile, data formats, storage in the database, protected storage, and contracts, signatures and permissions, each boundary, recovery from failures, and a minimal end-to-end flow.
Fill in: the build order and dependencies, environments, release, migration of existing data and messages, validation of older versions, and rollback.

## Open decisions

Fill in: each open question and assumption, the candidates, what it affects, who decides, and by when or under what condition.
