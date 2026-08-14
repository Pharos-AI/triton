---
title: Developing Triton itself
---

This covers building, testing, and Apex/LWC conventions for **this repo's own source** — as distinct from `agent-skills/`, which are customer-facing instrumentation skills documented in `AGENTS.md`/`CLAUDE.md` (do not confuse the two; `agent-skills/` contributes nothing to developing Triton).

## Build & Test

No namespace (`sfdx-project.json` → `"namespace": ""`), single package directory `force-app`, depends on the managed package `Pharos@2.275.0.3`.

```bash
# LWC unit tests (Jest) — colocated in __tests__/ next to each component
npm test
npm run test:watch
npm run test:coverage

# Apex — resolve <org-alias> via `sf org list`; zero scratch orgs provisioned as of 2026-08-13
sf project deploy start --target-org <org-alias>
sf apex run test --synchronous --result-format human --target-org <org-alias>
```

## Apex & LWC conventions

See `.claude/rules/salesforce-apex.md` and `.claude/rules/salesforce-lwc.md` (symlinked from `agent1`, the shared standards source — edit them there). Both are derived in part from this repo's own practice; see the provenance note at the top of `salesforce-apex.md` for where Triton's actual conventions diverge from Logger's written rubric.

## Instrumentation philosophy (governs new logging code added to *other* repos via the skills, and any Triton code that emits its own logs)

From `AGENTS.md`: never change program behavior while adding logging (the one exception — an optional `transactionId` param on an entry point — must be flagged); Area is the primary grouping key, reused from related code rather than invented per-feature; never instrument `@isTest` or managed-package code; never log PII; keep a human in the loop at batch boundaries on a large rollout, and defer risky/low-comfort code rather than rewriting it.
