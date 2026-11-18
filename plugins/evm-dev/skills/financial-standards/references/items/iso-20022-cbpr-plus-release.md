---
standard: iso-20022
version: CBPR+ SR2025
checked: 2026-11-18
source: Swift, SR2026 timeline notice of 27 August 2026, read through the Bank of England notice of that date, J.P. Morgan's ISO 20022 migration client page, and Clearstream's SR2026 connectivity notice (updated 22 September 2026); BNY, Update on ISO 20022 end of co-existence; ISO 20022, Payments Clearing and Settlement Message Definition Report Part 2 (FIToFICustomerCreditTransfer scope)
---

# Cross-border payments run on CBPR+ SR2025; the payments changes of SR2026 moved to a later release

Cross-border payments between financial institutions on Swift use the CBPR+ usage guidelines of ISO 20022.
The coexistence of MT and ISO 20022 for these payment instructions ended on 22 November 2025: `pacs.008` replaced MT103 for customer credit transfers, and `pacs.009` replaced MT202 and MT205 for transfers between institutions.
ISO 20022 defines `pacs.008` as the message the debtor agent sends to the creditor agent, directly or through other agents or a clearing and settlement system, to move funds from the debtor's account to the creditor; it is the interbank instruction, not a report.
MT messages for exceptions, investigations, and cancellations follow a separate timeline into November 2027.

SR2026 was planned to go live on 14 November 2026 and to reject fully unstructured postal addresses.
On 27 August 2026 Swift announced that it would delay that release, accepting a community request for more time to move to structured addresses.
Notices from J.P. Morgan and Clearstream say all cross-border payments changes (MT category 1, CBPR+, SCORE+, and Swift Go) were taken out of SR2026 and postponed to SR2027 or later, so SR2025 stays in force for CBPR+, and unstructured addresses may still be used until at least November 2027.
The rest of SR2026 (other MT categories and ISO 20022 securities, funds, tracker, and exceptions and investigations messages) moves to a deferred release on 12 June 2027.
This item could not read Swift's own pages directly; confirm the scope on Swift's standards release page before relying on it.

For a design:

- Name the usage guideline and its release (CBPR+ SR2025 until the later release that takes over the changes moved out of SR2026), and the message versions that release fixes, read from the guideline itself
- Design addresses as structured or hybrid now, with town and country in their own fields, since unstructured addresses are on their way out
- A `pacs.002` status report and `camt.053` or `camt.054` statements report on a payment; they are not the settlement itself
