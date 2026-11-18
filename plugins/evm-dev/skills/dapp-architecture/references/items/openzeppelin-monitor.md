---
topic: monitoring
subject: OpenZeppelin Monitor
checked: 2026-11-18
source: OpenZeppelin, Defender sunset FAQ and the openzeppelin-monitor repository README
---

# Defender's monitors became the self-hosted OpenZeppelin Monitor

Defender's hosted monitoring (Sentinels and Monitors) ended with Defender on 1 July 2026. OpenZeppelin Monitor is the open-source successor that the team hosts itself, released under the AGPL v3 and supporting EVM-compatible networks, Stellar, and Solana.

For a design:

- Do not plan alerts on Defender Monitor
- When choosing OpenZeppelin Monitor or another tool, name who runs it, which events and functions it watches (admin roles, pause, upgrades, large transfers), and where alerts go
- Watch the monitor itself: an alert that a monitor stopped matters as much as the alerts it raises
