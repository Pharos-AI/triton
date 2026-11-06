---
description: Add Triton logging to a Salesforce Flow's metadata XML. Usage: /pharos:instrument-flows <path-to-flow-xml> [--area <Area>] [--level <Level>] [--deploy]
argument-hint: <path-to-flow-xml> [--area <Area>] [--level <Level>] [--deploy]
---

Read the canonical skill definition at `agent-skills/instrument-flows.md` (relative to the repo root) and follow it **exactly**, start to finish.

Treat the following as the skill's arguments (path and flags): $ARGUMENTS

The canonical file is the single source of truth — do not improvise beyond it. In particular: verify Triton is installed in the org, pass individual named inputs to the `TritonFlow` invocable (never a collection/SObject), instrument every fault connector at ERROR, and never write the file until the user approves the diff (yes / modify / skip).
