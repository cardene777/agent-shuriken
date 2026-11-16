---
status: specified
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7723, EIP-7773 (the Glamsterdam meta EIP), and EIP-8081 (the Hegotá meta EIP) documents
---

# EIP-7723 (The stages an EIP passes through to enter a network upgrade)

A standard that defines the stages an EIP passes through in planning a network upgrade.
Each upgrade's meta EIP lists EIPs under these stage names.

| Stage | What the document says |
|---|---|
| `Proposed for Inclusion` | Someone submits a change that adds the EIP to this section of the meta EIP. It is submitted again for each upgrade and does not carry over to the next upgrade |
| `Considered for Inclusion` | Client developers have read the content and show that they intend to test it on a devnet. It is not a guarantee that it ships to mainnet |
| `Scheduled for Inclusion` | The stage at which developers agree on a strong intent to include it in the next upgrade and that the spec and implementations are mature. One guide is going at least one week without major bugs on a stable devnet |
| `Declined for Inclusion` | The stage at which client developers decide to leave it out of that upgrade |
| `Included` | After the upgrade activates, the EIPs that went in move here. The lists for the other stages are removed from the meta EIP |

## Current status

The document's status is `Last Call`, with a deadline given as 2025-04-01, and it was created on 2024-06-12.
The deadline has passed, but as of 2026-11-11 the document's status was still `Last Call`.
The Glamsterdam meta EIP (EIP-7773) and the Hegotá meta EIP (EIP-8081) list EIPs by referring to these stage definitions.

## Not yet shipped

It has not become `Final`.
