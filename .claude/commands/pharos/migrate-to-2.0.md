---
description: Migrate a project from Triton 1.x to 2.0 — Apex (Triton.instance, removed log-level APIs, test mocks), LWC, Flow XML and Log_Level__mdt records. Usage: /pharos:migrate-to-2.0 <path> [--tech apex,lwc,flow,mdt] [--install source|package] [--collapse-exceptions] [--collapse-dml] [--deploy]
argument-hint: <path> [--tech apex,lwc,flow,mdt] [--install source|package] [--collapse-exceptions] [--collapse-dml] [--deploy]
---

Read the canonical skill definition at `agent-skills/migrate-to-2.0.md` (relative to the repo root) and follow it **exactly**, start to finish.

Treat the following as the skill's arguments (path and flags): $ARGUMENTS

The canonical file is the single source of truth. Critically: **never auto-decide** the immediate-vs-buffered publishing change — every old bare-method call (`Triton.instance.error/warning/debug`) must be presented to the user as `logNow` (immediate) vs. buffer + ensure flush. Never auto-edit any `Log_Level__mdt` rule or LWC `AREA` comparison — flag them with a recommended option. Report flush gaps and never write until the diff is approved.
