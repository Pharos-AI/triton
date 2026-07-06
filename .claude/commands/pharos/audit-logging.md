---
description: Read-only scan reporting Triton logging gaps and a prioritized instrumentation plan (writes nothing). Usage: /pharos:audit-logging [<path>] [--format md|json] [--fail-on error,debug] [--tech apex,lwc,flow]
argument-hint: [<path>] [--format md|json] [--fail-on error,debug]
---

Read the canonical skill definition at `agent-skills/audit-logging.md` (relative to the repo root) and follow it **exactly**, start to finish.

Treat the following as the skill's arguments (path and flags): $ARGUMENTS

The canonical file is the single source of truth. This skill is **read-only** — never modify source files; the only permitted write is the report. Separate hard findings from judgment findings, and output a plan that maps onto `instrument-org` phases.
