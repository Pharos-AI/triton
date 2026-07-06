---
name: audit-logging
summary: Read-only scan of a Salesforce project that reports Triton logging gaps and a prioritized instrumentation plan. Writes nothing.
usage: audit-logging [<path>] [--format md|json] [--fail-on error,debug,...] [--tech apex,lwc,flow]
---

# Audit Logging Coverage

Scan a Salesforce project **read-only** and report where Triton logging is missing or wrong, plus a prioritized plan you can hand to [`instrument-org`](instrument-org.md). This skill **never writes source files** — its only optional output is a report file.

> **Agent-agnostic skill.** Invoke it as your agent invokes skills (`/pharos:audit-logging <path>`, an `@`-mentioned instruction, or a pasted prompt).

## Step 0 — Prerequisites

No org connection is required (this is static analysis). Confirm you're at a Salesforce DX project root (or a subtree); if `<path>` is omitted, use the `packageDirectories` from `sfdx-project.json`.

## Step 1 — Parse arguments

- **`<path>`** — project root or subtree. Default: package directories.
- **`--format`** — `md` (default, human-readable) or `json` (structured findings for CI).
- **`--fail-on`** — comma-separated finding kinds that should make the skill exit non-zero (for CI gating), e.g. `error,debug` for catch-not-logged and `System.debug`.
- **`--tech`** — restrict to some technologies. Default: all three.

## Step 2 — Scan

Read (never modify) every non-test `*.cls`/`*.trigger`, every `lwc/**/<name>.js`, and every `*.flow-meta.xml`. Exclude `@isTest` classes and managed-package code from findings (but note their existence in totals).

### Hard findings (unambiguous — block-worthy)

| Finding key | Detect | Rule |
|-------------|--------|------|
| `system-debug` | `System.debug(` in non-test Apex | Should be `Triton.debug(...)`. |
| `triton-instance` | `Triton.instance` anywhere | Removed 1.x singleton → route to [`migrate-to-2.0`](migrate-to-2.0.md). |
| `catch-not-logged` | `catch (...)` block with no `Triton.` call | Errors going dark. |
| `missing-flush` | Method that calls `Triton.log/info/debug/...` (buffered) with no `Triton.flush()` at its boundary or a `finally` | Buffered logs dropped. |
| `entrypoint-unlogged` | `@AuraEnabled`, `@RestResource`/`@Http*`, `@InvocableMethod`, Queueable/Batch `start`/`finish` with no `Triton.` call | No visibility at the boundary. |
| `flow-fault-unlogged` | `<faultConnector>` with no `TritonFlow` action on its path | Unhandled Flow errors unseen. |

### Judgment findings (flagged, not failed)

- `adhoc-taxonomy` — `.area('...')` / `.type('...')` string literals where an enum value exists.
- `dishonest-level` — `ERROR` on non-failures, or loop chatter above `FINE`.
- `missing-context` — record-oriented logs with no `.relatedObject(s)`; callouts with no `.integrationPayload(...)`.
- `low-comfort` — old, untested, business-critical files a rollout should treat gently.

For each finding, record: file, line (where applicable), finding key, severity (`hard`/`judgment`), and a one-line note.

## Step 3 — Score and prioritize

Compute per-technology coverage (`instrumented / total`, excluding skips) and bucket the remaining work into the [`instrument-org`](instrument-org.md) phases:
- **Phase 1** — files containing entry points (`entrypoint-unlogged`, integration callouts, LWC/Flow that call them).
- **Phase 2** — trigger handlers and core services.
- **Phase 3** — the rest.
- **Deferred** — `low-comfort` + business-critical.

## Step 4 — Emit the report

**Markdown (`--format md`, default):** print a scoreboard, then the plan, then the detail:

```
Triton logging audit — force-app/main/default

Coverage
  Apex     62/141 instrumented (44%) · 79 gaps
  LWC       9/40  instrumented (23%) · 31 gaps
  Flows     4/22  instrumented (18%) · 18 gaps

Hard findings (block-worthy)
  system-debug ............ 213 in 47 classes
  triton-instance (1.x) ... 12 classes  → migrate-to-2.0
  catch-not-logged ........ 88 blocks
  missing-flush ........... 34 methods
  entrypoint-unlogged ..... 51
  flow-fault-unlogged ..... 15

Suggested order (by value/risk)
  Phase 1 — entry points .. 51 files  (start here)
  Phase 2 — internals ..... 63 files
  Phase 3 — sweep ......... 40 files
  Deferred (low-comfort) .. 8 files

Next: /pharos:instrument-org --phase 1
```

Optionally save it as `triton-logging-audit.md`.

**JSON (`--format json`):** emit `{ coverage, findings[], plan }` where each finding is `{ file, line, key, severity, note }`. This is the CI-friendly form.

## Step 5 — Exit status (CI gating)

If `--fail-on` was given, exit non-zero when any finding whose key matches is present (map friendly aliases: `debug` → `system-debug`, `error` → `catch-not-logged`). Otherwise always exit zero. Print which rule tripped the gate.

## Constraints

- **Read-only. Never modify source files.** The only permitted write is the report file.
- Exclude `@isTest` and managed-package code from findings; count them separately.
- Prefer precise structural detection over naive text matching where the agent can parse the code (e.g. a real `catch` block, not the word "catch" in a comment).
- Keep hard vs. judgment findings clearly separated — only hard findings should ever gate CI.
- The output plan must map cleanly onto [`instrument-org`](instrument-org.md) phases so it can be executed directly.
