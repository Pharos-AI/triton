---
description: Instrument a whole Salesforce project with Triton — inventory, prioritize, and instrument in feature batches with review checkpoints. Usage: /pharos:instrument-org [<path>] [--area-map <file>] [--phase <n>] [--tech apex,lwc,flow] [--batch-size <n>] [--deploy] [--dry-run]
argument-hint: [<path>] [--phase <n>] [--tech apex,lwc,flow] [--deploy] [--dry-run]
---

Read the canonical skill definition at `agent-skills/instrument-org.md` (relative to the repo root) and follow it **exactly**, start to finish. It orchestrates the `instrument-apex`, `instrument-lwc`, and `instrument-flows` skills — apply their conventions verbatim.

Treat the following as the skill's arguments (path and flags): $ARGUMENTS

The canonical file is the single source of truth. In particular: run `audit-logging` first (or Step 1), group files into features with one Area each, approve every batch before writing (yes / modify / skip file / pause), defer low-comfort code, and produce a coverage report.
