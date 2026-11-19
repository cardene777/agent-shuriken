# Example: Supplier invoice settlement with ISO 20022 payments

This design lets a buyer and its foreign suppliers share one record that each approved invoice was paid by cross-border bank transfer and that the supplier saw the credit, so both close the invoice against the same evidence. It covers the standard and its profile, the case flow, where each field lives, the ledger, the off-chain components, their boundaries, and operations. It leaves out invoice approval inside the buyer's systems, foreign exchange, tax reporting, and the banks' own systems.

Each section decides one part and points to the others instead of repeating them. Open decisions holds every decision, assumption, and open question; other sections link to it.

## Standard and business

ISO 20022 under the CBPR+ usage guidelines, release SR2025, which stays in force for cross-border payments because the payments changes of SR2026 were moved to SR2027 or later after Swift's notice of 27 August 2026 (item on the CBPR+ release, checked 2026-11-18; that item could not read Swift's own pages, D1). Messages: `pacs.008`, the interbank instruction the buyer's bank sends toward the supplier's bank, and `camt.054`, the report on the credit that the supplier receives from its bank; the message versions are read from the SR2025 guideline (D1). Buyer and suppliers are identified by LEIs under ISO 17442-1:2020 (item on the LEI, checked 2026-11-18).
Participants: the buyer (debtor), each supplier (creditor), and their banks, which are not on the ledger; the buyer and suppliers are in different jurisdictions (D2). Out of scope: domestic payments, returns, and disputes over goods.

| Event | Business meaning | State change | Evidence |
|---|---|---|---|
| Buyer's bank confirms it sent the `pacs.008` | The buyer instructed the payment | none to Instructed | Buyer-signed commitment |
| Supplier receives a `camt.054` credit | The supplier's bank reports the credit | Instructed to Credited | Supplier-signed commitment |
| Both parties' records agree | Both may close the invoice | Credited to Closed | Signatures of both |
A report is not settlement: Credited records what the supplier's bank reported, and Closed means the two records agree, not that a bank's settlement is final. Each case has an internal case ID, created when the payment is instructed so unpaid invoices never reach the ledger; the correlator links a `camt.054` to a case only when the payment identifiers, amount, currency, and supplier LEI all match, and records that reason.

## Application

- Open a case: the buyer's treasury system, once its bank confirms the `pacs.008` was sent and the supplier's LEI is active at that moment; input is the validated message; a lapsed LEI, a failed validation, or a reused case ID is rejected; a retry with the same case ID returns the existing case
- Record the credit: the supplier's system, on a `camt.054` that validates and correlates; a credit that matches no case waits in a review queue and reaches no ledger
- Close: either party proposes and both sign; a mismatch opens a correction case that refers to the first, which stays as it was
- Cancel: the buyer, before Credited, records a cancellation event; it does not recall the bank payment
- Disclose: an auditor receives one case's canonical record and salt, and every disclosure is logged
Each operation crosses the boundaries listed in Integration.

## Data and storage

Entities: Case (case ID, state, parties' LEIs, profile), OriginalMessage (raw XML as received), CanonicalRecord, ValidationResult (guideline version, result, time), Evidence (type, commitment, signer key ID, nonce, expiry, signature), and Disclosure (who, when, case).
The canonical record is UTF-8 JSON with sorted keys and no extra whitespace; IDs are random 128-bit values, times are UTC in ISO 8601, digests are SHA-256, each salt is 32 random bytes, and keys are referenced only by their key ID.
On chain: case ID, state, evidence type, commitment, signer key ID, nonce, and time. Committed only: amount, currency, LEIs, invoice number, and payment identifiers. Protected off-chain: the original messages, names, postal addresses, account numbers, and remittance information. Conditional: a case's canonical record, given to an auditor on request.
The application database indexes cases by case ID, invoice number, and commitment, and points to protected storage by object ID; protected storage is encrypted at rest with each participant's own key.

## On-chain

`ParticipantRegistry` keeps each participant's LEI commitment, signing addresses, key IDs, and revocations; `ProfileRegistry` keeps the active standard and profile versions; `CaseLedger` keeps each case's state and evidence and emits `CaseOpened`, `EvidenceRecorded`, `CaseClosed`, `CaseCancelled`, and `CorrectionLinked`.
The consortium's admin multisig adds and revokes participants, keys, and profiles. `CaseLedger` accepts only EIP-712 evidence whose domain holds the chain ID and the `CaseLedger` address, signed by a registered, unrevoked key of the party allowed for that transition, with an unused nonce, an unexpired deadline, and an active profile; it keeps one piece of evidence of each type per case, and Closed and Cancelled are terminal. A correction is a new case that names the case it corrects. The contracts are not upgradeable; a pause by the consortium's guardian stops new evidence only (D3).

## Off-chain

Each participant runs its own receiver for bank messages, validator against the SR2025 guideline, normalizer and correlator, protected store for originals and personal data, key service that signs without exposing keys, signer that signs only validated evidence, and disclosure service for auditors. The consortium operator runs the ledger nodes and sees only on-chain data.

## Integration

```
bank channel -> receiver -> validator -> correlator -> protected store
                                            |-> signer (key service) -> outbox -> CaseLedger
auditor <- disclosure service <- protected store
```
Trust boundaries sit between each bank and its customer, between each participant's systems and the ledger, and between participants. The receiver passes the original and its message ID; the correlator passes the case ID, the commitment, and the reason for the link; the outbox passes the evidence, signature, nonce, and expiry of one hour. The ledger rejects a bad signature, a revoked key, a used nonce, an expired deadline, an inactive profile, or a transition the state does not allow. The outbox resends the same signed evidence until it is final on the ledger, and after its expiry the signer signs it again with a new nonce; since the ledger keeps one piece of evidence of each type per case, a resend records nothing twice. A daily job reconciles the database with the ledger (D3).
A commitment binds the domain tag of its use, the chain ID, the ledger contract address, the case ID, the profile version, the canonical record's digest, and the random salt; the two parties and an auditor given the salt may recompute it.

## Security and operations

Names and postal addresses are personal data, account numbers are financial secrets, and amounts and invoice numbers are business-confidential; only the two parties of a case see its originals. Keys stay in each participant's key service and are revoked in the registry. Threats covered: replayed or forged evidence, a leaked salt, which exposes one case only, and an insider reading the ledger. Legal finality sits with the banks; ledger state is a shared record, and disputes follow the contract between buyer and supplier.
Profile changes add a new profile version and leave old cases on theirs. Addresses are stored structured or hybrid, with town and country in their own fields. Cases instructed more than five business days without a credit alert the buyer's treasury, and outbox failures alert the operator. Originals and salts are kept for the legal retention period, then deleted unless on legal hold (D4); each participant owns its own store.

## Verification and delivery

Acceptance: every message validates against the SR2025 guideline; the same message always yields the same digest; no event or state holds a protected field; evidence is rejected when revoked, expired, reused, or signed for another chain or contract; an outbox resend records once; and one invoice runs from Instructed to Closed on a test ledger.
Build order: registries, then the ledger, then the validators and correlator, then the signer and outbox. Environments are local, a test consortium network, and production. Paid invoices from before launch are not migrated; messages under an earlier release are validated against that release's guideline; rollback pauses the ledger and restores the previous off-chain release.

## Open decisions

| ID | Decision or assumption | Candidates | Affects | Who decides | By when |
|---|---|---|---|---|---|
| D1 | Confirm on Swift's standards release page that SR2025 stays in force for CBPR+, and read the message versions it fixes | SR2025; the later release that takes over the payments changes | Standard and business | Buyer's payments lead | Before building the validator |
| D2 | Assumed: one buyer and suppliers in two other jurisdictions, on a permissioned EVM network the consortium runs | A public chain with commitments only | Standard and business, Integration | Buyer and suppliers | Before onboarding |
| D3 | Assumed: the network is final once a block is produced, so there are no reorganizations; confirm and set the guardian multisig | Wait a confirmation depth; finality on production | On-chain, Integration | Consortium operator | Before the test network |
| D4 | Retention periods and legal hold for originals and salts in each jurisdiction | The longest period among them; per participant | Security and operations | Each participant's counsel | Before production |
