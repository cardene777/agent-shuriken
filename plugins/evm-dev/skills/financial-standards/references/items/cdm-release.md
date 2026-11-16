---
standard: cdm
version: 7.10.0
checked: 2026-11-16
source: FINOS, Common Domain Model releases and the CDM 7 production release notes
---

# The CDM 7 line is in production; 8.0.0 is in development

FINOS released CDM 7.0.0, a production release, on 17 July 2026, consolidating more than 130 upgrades made over the year before.
The newest release in that line is 7.10.0 (13 November 2026).
CDM 8.0.0 is published as development releases (`8.0.0-dev.N`) and is not a production version, and the 6.x line still gets releases (6.32.0 on 6 November 2026).

CDM 7 extends ingestion of FpML confirmations across rates, FX, credit, equity, and commodity products, and adds content for collateral agreements (CSAs, CTAs, GMSLAs) and securities lending events.

For a design:

- Pin the CDM version the design uses; types and functions change between major versions
- The CDM models trades, events, and their lifecycle; it is not a message format to send to a counterparty, so the design says which message carries the data across each boundary
