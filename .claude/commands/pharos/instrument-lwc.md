---
description: Instrument an LWC component with Triton logging. Usage: /pharos:instrument-lwc <path-to-component-dir-or-js-file> [--area <Area>] [--type <Type>] [--deploy]
argument-hint: <path-to-component-dir-or-js-file> [--area <Area>] [--type <Type>] [--deploy]
---

Read the canonical skill definition at `agent-skills/instrument-lwc.md` (relative to the repo root) and follow it **exactly**, start to finish.

Treat the following as the skill's arguments (path and flags): $ARGUMENTS

The canonical file is the single source of truth — do not improvise beyond it. In particular: run the Step 0 prerequisite checks first, always `bindToComponent`, prefer `timeBackendCall`, and never write the file until the user approves the diff (yes / modify / skip).
