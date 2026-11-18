---
standard: fix
version: FIX Latest EP312
checked: 2026-11-18
source: FIX Trading Community, FIX Protocol extension packs list, the FIX Latest transition notice, and the FIX 4.2, FIX 4.4, and FIX Latest field and code set definitions
---

# FIX is published as FIX Latest with numbered extension packs

The FIX Trading Community no longer publishes numbered versions of the application layer.
FIX Latest is the protocol up to and including the newest extension pack, and the newest pack listed is EP312 (FIX Latest session layer corrections), after EP311 and EP310 (errors and omissions for FIX 4.4 and FIX 4.2, August 2026) and EP309 (equity issuance phase 1A).

Many counterparties still run FIX 4.2, FIX 4.4, or FIX 5.0 SP2, so a design names the version and the extension packs each counterparty sends, instead of assuming FIX Latest.

For a design:

- Treat an `ExecutionReport` (`35=8`) as the broker's report of a fill; corrections and cancellations arrive as later reports that refer to the earlier one (`ExecType` `G` trade correct and `H` trade cancel from FIX 4.3; `ExecTransType` `2` correct and `1` cancel in FIX 4.2), so evidence is appended, never overwritten
- Correlate with the identifiers the counterparty fixes (`ClOrdID`, `OrderID`, `ExecID`, `ExecRefID`) and keep your own case ID, since the specification requires `ClOrdID` to be unique only within one trading day for each sender
- Parties are best identified by LEI (`PartyIDSource` `N`, added in EP156; FIX 4.4 and FIX 4.2 have no such value, so agree with those counterparties how an LEI is sent)
