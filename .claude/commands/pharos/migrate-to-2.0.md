---
description: Convert Triton 1.x singleton code (Triton.instance) to the 2.0 static, builder-first API. Usage: /pharos:migrate-to-2.0 <path> [--collapse-exceptions] [--collapse-dml] [--deploy]
argument-hint: <path> [--collapse-exceptions] [--collapse-dml] [--deploy]
---

Read the canonical skill definition at `agent-skills/migrate-to-2.0.md` (relative to the repo root) and follow it **exactly**, start to finish.

Treat the following as the skill's arguments (path and flags): $ARGUMENTS

The canonical file is the single source of truth. Critically: **never auto-decide** the immediate-vs-buffered publishing change — every old bare-method call (`Triton.instance.error/warning/debug`) must be presented to the user as `logNow` (immediate) vs. buffer + ensure flush. Report flush gaps and never write until the diff is approved.
