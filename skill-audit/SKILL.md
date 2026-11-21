---
name: token-audit
description: Audit this project's token and usage cost: fixed overhead, last session, big files, guard log, unused connectors. Use for /token-audit, "audit usage", or after an expensive session.
---

Run `sh ../token-optimisation/scripts/audit.sh` from the project root. Summarise in short Roman Urdu: top 3 drivers, each mapped to a tip id (`sh ../token-optimisation/scripts/tips.sh <id>`). Ask `/context` for the connector overhead and ask the owner which connectors this project needs. Propose the smallest changes; apply only after the owner says yes, with a backup (`rules/session-review.md`).
