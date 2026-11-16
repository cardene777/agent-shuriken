---
standard: iso-20022
version: CBPR+ SR2025
checked: 2026-11-16
source: Swift, ISO 20022 standards release pages and the SR2026 timeline notice of 27 August 2026
---

# Cross-border payments run on CBPR+ SR2025; the payments part of SR2026 was deferred

Cross-border payments between financial institutions on Swift use the CBPR+ usage guidelines of ISO 20022.
The coexistence of MT and ISO 20022 for these payment instructions ended on 22 November 2025: `pacs.008` replaced MT103 for customer credit transfers, and `pacs.009` replaced MT202 and MT205 for transfers between institutions.
MT messages for exceptions, investigations, and cancellations follow a separate timeline into November 2027.

SR2026 was planned to go live on 14 November 2026 and to reject fully unstructured postal addresses.
On 27 August 2026 Swift announced a change to the SR2026 timeline and accepted a community request to extend the move to structured addresses.
Reports of that notice say the payments part of SR2026 did not go live on 14 November 2026, that SR2025 stays in force until a later release replaces it, and that Swift would give a new date by December 2026.
This item could not read Swift's own page directly; confirm the date and scope on Swift's standards release page before relying on it.

For a design:

- Name the usage guideline and its release (CBPR+ SR2025 until Swift sets the SR2026 date), and the message versions that release fixes, read from the guideline itself
- Design addresses as structured or hybrid now, with town and country in their own fields, since unstructured addresses are on their way out
- A `pacs.002` status report and `camt.053` or `camt.054` statements report on a payment; they are not the settlement itself
