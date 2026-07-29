---
name: instrument-org
summary: Orchestrate instrument-apex/lwc/flows across a whole Salesforce project — inventory, prioritize, instrument in feature batches with review checkpoints, and report coverage.
usage: instrument-org [<path>] [--area-map <file>] [--phase <n>] [--tech apex,lwc,flow] [--batch-size <n>] [--deploy] [--dry-run]
---

# Instrument the Org

Instrument an entire Salesforce project (or a subtree of it) by orchestrating the three per-technology skills across it — with consistent Areas per feature, transaction stitching across LWC → Apex → Flow, and a human review checkpoint at every batch. This is **not** a new instrumentation engine: every file is instrumented by [`instrument-apex`](instrument-apex.md), [`instrument-lwc`](instrument-lwc.md), or [`instrument-flows`](instrument-flows.md), following those exact conventions.

> **Agent-agnostic skill.** Invoke it as your agent invokes skills (`/pharos:instrument-org <path>`, an `@`-mentioned instruction, or a pasted prompt). It drives the other skills; if your agent can't call skills programmatically, follow each per-file skill inline in the order this one dictates.

> **Run [`audit-logging`](audit-logging.md) first (or let Step 1 run it).** The read-only audit gives you the map before anything is written.

## Step 0 — Prerequisites check

Same as the per-file skills: confirm `sf`/`sfdx` is installed and a default org is connected (see [`instrument-apex`](instrument-apex.md) Step 0). If the project contains Flows you intend to instrument, also confirm Triton is installed in the org (see [`instrument-flows`](instrument-flows.md) Step 0). Confirm you are in a Salesforce DX project (an `sfdx-project.json` exists); if not, ask for the project root.

## Step 1 — Inventory

Walk `<path>` (default: the project's `packageDirectories` from `sfdx-project.json`) and catalog every instrumentable artifact:

- **Apex** — `*.cls` and `*.trigger`, **excluding** `@isTest` classes and managed-package namespaced code.
- **LWC** — each component directory under `lwc/` (locate `<name>.js`).
- **Flows** — `*.flow-meta.xml`, recording `<processType>`.

For each item, record its current instrumentation state so a re-run only fills gaps and never double-instruments:
- **instrumented** — already uses `Triton.` / `c/triton` / `TritonFlow` at the expected density.
- **partial** — some logging present, gaps remain.
- **none** — no Triton usage.
- **skip** — test class, managed, or explicitly excluded.

This is the same signal [`audit-logging`](audit-logging.md) produces; if an audit report exists, read it instead of re-scanning.

## Step 2 — Group into features

Files are not the unit of work — **features** are. Cluster related code so a whole feature shares one Area and one correlated transaction:

- A trigger + its handler class + the service classes it calls.
- An LWC + the `@AuraEnabled` controller it calls + any Flow that controller invokes.
- A screen Flow + its subflows + the record operations beneath it.

Resolve the **Area for each cluster once** — from `--area-map`, from an Area already used by related code, or by inference (see the Area guidance in [`instrument-apex`](instrument-apex.md) Step 2) — and reuse it across every file in the cluster. Record the mapping so it's applied consistently and shown in the final report.

## Step 3 — Prioritize (rollout phases)

Order the backlog by value and risk, not alphabetically:

1. **Phase 1 — edge entry points.** `@AuraEnabled` controllers, `@RestResource`, `@InvocableMethod`, Queueable/Batch `start`/`finish`, global callouts, and the LWCs/Flows that call them. Establish cross-boundary transaction correlation here first.
2. **Phase 2 — high-value internals.** Trigger handlers and core service classes.
3. **Phase 3 — broad sweep.** Low-risk utilities and everything remaining; retire the last `System.debug`.

Respect **comfort tiers**: for business-critical, low-comfort code (old, untested, no author), propose *minimal* instrumentation or **defer** it for a human rather than aggressively rewriting code nobody understands. When `--phase <n>` is given, run only that phase.

## Step 4 — Instrument, batch by batch

For each batch (a feature cluster, or `--batch-size` files):

1. For each file in the batch, run the matching per-technology skill through **its Step 3** (Apply), passing the cluster's shared `--area` and threading transaction ids across the LWC → Apex → Flow legs. Use **one** stitching mechanism per cluster (param `transactionId` *or* `withCache`) and keep it consistent.
2. Present a **batch summary** and pause:

```
Batch 3/17 — Opportunity Management (Area: OpportunityManagement)
  ✎ OpportunityController.cls        @AuraEnabled  · txn resume + 2 catches + flush
  ✎ opportunityCard (LWC)            timeBackendCall · stitches via transactionId
  ✎ Recalc_Opportunity.flow-meta.xml 1 fault path + flow entry
Review: [yes] apply & continue · [modify] · [skip file <name>] · [pause]
```

3. Handle the response:
   - **yes** — write every file in the batch (each skill's Step 5), then continue.
   - **modify** — take free-form corrections, re-apply, re-present.
   - **skip <file>** — drop that file from the batch, keep the rest.
   - **pause** — write nothing further, jump to Step 6 (report), and record where to resume.

Never write a batch before it is accepted. Never write hundreds of files unattended.

## Step 5 — Deploy (optional, per batch)

With `--deploy` (or on per-batch confirmation), deploy each accepted batch before starting the next, using each skill's Step 6 command for the touched paths. A failed deploy stops the run and shows the failures **without reverting files** — fix and re-run from the paused point.

## Step 6 — Coverage report

At the end (or on `pause`), write `triton-instrumentation-report.md` (and print a summary):

```
Triton instrumentation coverage — force-app/main/default
  Apex     124/141 instrumented · 9 tests skipped · 8 deferred (low-comfort)
  LWC       38/40  instrumented · 2 deferred
  Flows     19/22  instrumented · 3 deferred (managed)
  Areas assigned: 11 · Transactions correlated across 27 LWC→Apex chains
  Deferred items and reasons: (list)
  Resume from: Phase 3, batch 14
```

A re-run reads this and picks up where it left off.

## --dry-run

With `--dry-run`, perform Steps 1–3 and write the report and proposed order **only** — no per-file Apply, no writes, no deploy. Use it to review Area assignments and batch order before committing.

## Constraints

- Do not re-implement instrumentation logic — always delegate to the per-technology skills so conventions stay identical.
- One Area per feature cluster; reuse existing Areas from related code before inferring.
- One transaction-stitching mechanism per cluster; keep the LWC/Apex/Flow legs consistent.
- Never instrument test classes or managed-package code.
- Approve at batch boundaries; never write or deploy an unreviewed batch.
- Defer low-comfort, business-critical code for a human instead of rewriting it blindly.
- Idempotent: re-running only fills gaps; never double-instrument an already-instrumented element.
- Never let a partial/failed deploy revert already-written files.
