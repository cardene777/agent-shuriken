---
standard: lei
version: ISO 17442-1:2020
checked: 2026-11-18
source: ISO, ISO 17442 parts 1 to 3; GLEIF, the verifiable LEI (vLEI) pages and The LEI in Numbers for the third quarter of 2026
---

# The LEI is ISO 17442; the verifiable LEI is ISO 17442-3:2024

The Legal Entity Identifier is a 20-character code defined in ISO 17442-1:2020, issued and kept current by LEI issuers under GLEIF.
ISO 17442-2:2020 puts an LEI into X.509 certificates.
ISO 17442-3:2024 (October 2024) defines the verifiable LEI (vLEI): credentials in the ACDC format that let a person prove they act for a legal entity.
About 3.19 million LEIs were active at the end of September 2026.

For a design:

- An LEI identifies a legal entity, never a person, so it can sit in public evidence; people's names and identifiers cannot
- An LEI can lapse when it is not renewed; the design checks the registration status at the moment it relies on it, and records which status it saw
- A vLEI proves who signed for an entity; it does not replace the signing key of the contract's authorized signer
