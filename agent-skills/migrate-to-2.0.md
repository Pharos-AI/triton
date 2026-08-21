---
name: migrate-to-2.0
summary: Convert Triton 1.x singleton code (Triton.instance) to the 2.0 static, builder-first API, surfacing the immediate-vs-buffered gotcha for human confirmation.
usage: migrate-to-2.0 <path> [--collapse-exceptions] [--collapse-dml] [--deploy]
---

# Migrate to 2.0

Mechanically convert Triton **1.x** singleton usage (`Triton.instance.*`) to the **2.0** static, builder-first API. This converts *existing* logging; it does not add new logging (that's [`instrument-apex`](instrument-apex.md)). Because one 1.x → 2.0 rename can silently change publishing behavior, this skill **stops and asks** on those calls rather than guessing.

> **Agent-agnostic skill.** Invoke it as your agent invokes skills (`/pharos:migrate-to-2.0 <path>`, an `@`-mentioned instruction, or a pasted prompt).

## Step 0 — Prerequisites

`sf`/`sfdx` and a default org only if you intend to `--deploy`; otherwise the rewrite is static. Confirm the target `<path>` exists (a `.cls`/`.trigger` file or a directory to sweep).

## Step 1 — Parse arguments

- **`<path>`** — required; a file or a directory (sweep every non-test `.cls`/`.trigger`).
- **`--collapse-exceptions`** — collapse hand-assembled error logs to `.exception(e)`. **On by default**; `--no-collapse-exceptions` keeps them verbatim.
- **`--collapse-dml`** — collapse hand-built bulk-DML failure logs to `.dmlResults(results)`.
- **`--deploy`** — deploy after the diff is accepted.

## Step 2 — Find 1.x usage

Scan for `Triton.instance` and any legacy patterns. For each file, list the calls to migrate. If a file has none, skip it and say so. (`@isTest` classes: migrate the logging calls too — 1.x usage in tests still won't compile against 2.0.)

## Step 3 — Apply the method mapping

Rewrite each call using this mapping (the `.instance` drops away; positional args move onto a builder):

| Triton 1.x | Triton 2.0 |
|------------|------------|
| `Triton.instance.error(area, e)` | `Triton.logNow(Triton.t.area(area).exception(e))` |
| `Triton.instance.addError(area, e)` | `Triton.error(Triton.t.area(area).exception(e))` |
| `Triton.instance.error(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).error())` |
| `Triton.instance.addError(type, area, summary, details)` | `Triton.error(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.addWarning(type, area, summary, details)` | `Triton.warning(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.addDebug(type, area, summary, details)` | `Triton.debug(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.addDebug(type, area, summary, details, duration)` | `Triton.debug(Triton.t.type(type).area(area).summary(summary).details(details).attribute(TritonBuilder.DURATION, duration))` |
| `Triton.instance.addEvent(level, type, area, summary, details)` | `Triton.log(Triton.t.category(TritonTypes.Category.Event).type(type).area(area).summary(summary).details(details).level(level))` |
| `Triton.instance.addDMLResult(area, results)` | `Triton.error(Triton.t.area(area).dmlResults(results))` |
| `Triton.instance.addIntegrationError(area, e, request, response)` | `Triton.error(Triton.t.area(area).exception(e).integrationPayload(request, response))` |
| `Triton.instance.addLog(builder)` | `Triton.log(builder)` |
| `Triton.instance.setTemplate(builder)` | `Triton.setTemplate(builder)` |
| `Triton.instance.fromTemplate()` | `Triton.fromTemplate()` (or `Triton.t`) |
| `Triton.instance.flush()` | `Triton.flush()` |
| `Triton.instance.startTransaction()` | `Triton.startTransaction()` |
| `Triton.instance.resumeTransaction(id)` | `Triton.resumeTransaction(id)` |
| `Triton.instance.stopTransaction()` | `Triton.stopTransaction()` |

> **Note on `addIntegrationError`:** the legacy call wrote `Category = 'Integration'`; the 2.0 form intentionally lands as `Apex` — the Integration category is deprecated, and post-processing payload preservation is triggered by the `integrationPayload` itself, not by category.

Transaction/template methods are safe renames. The **logging** methods change shape — and hide the one gotcha.

## Step 4 — The publishing gotcha (NEVER auto-decide)

In 1.x the **method name** decided publishing timing:
- **bare** methods (`error`, `warning`, `debug`) published **immediately**.
- **`add*`** methods **buffered** until `flush()`.

In 2.0 **all level methods buffer**; you opt into immediate publishing with **`Triton.logNow(...)`**. That's why bare → `logNow` and `add*` → level methods in the table.

For **every old bare-method call** (`Triton.instance.error/warning/debug(...)`), do **not** silently choose. Present both options and ask:

```
<file>:<line>  Triton.instance.error(area, e)
  This published IMMEDIATELY in 1.x.
  [A] Triton.logNow(...)  — keep immediate publishing  (recommended if a later
      exception/callout/limit could kill the transaction before a flush)
  [B] Triton.error(...) + ensure a flush() covers this path  — buffer it
  Choose A / B:
```

Getting this wrong is how a migrated log silently disappears when the transaction dies before flushing.

## Step 5 — Audit flush coverage & collapse

- **Flush coverage.** Now that level methods buffer, flag every path that logs but has no `Triton.flush()` at its boundary/`finally`. Report these alongside the diff (fixing them may require a boundary flush — propose it).
- **`--collapse-exceptions`.** Replace hand-set error fields (`.type(...).summary(e.getMessage()).details(e.getStackTraceString())`) with a single `.exception(e)` (which also sets ERROR level and issue creation). Put any custom `.summary(...)` **after** `.exception(e)`.
- **`--collapse-dml`.** Replace hand-built DML failure summaries with `.dmlResults(results)`.
- **Ad-hoc taxonomy.** Flag `.area('X')` / `.type('X')` string literals; suggest promoting them to `public static final String` constants (never edit the shipped `TritonTypes` enums — see the Custom Classifications guidance in the docs).

## Step 6 — Review, write, deploy

Present a summary — calls migrated, bare-method decisions (A/B) taken, collapses applied, flush gaps found — then the diff, with `yes` / `modify` / `skip`. On `yes`, write back to the original file. With `--deploy` (or on confirmation), run `sf project deploy start --source-dir <path> --json` (or the `sfdx` equivalent).

> After deploying 2.0, remind the user to re-assign the `Triton_Read` / `Triton_Write` permission sets so the new fields are visible.

## Constraints

- Never auto-convert a bare-method call — always present the immediate (`logNow`) vs. buffer (+flush) choice.
- Never change program behavior beyond the logging call itself; preserve control flow, throws, signatures.
- Do not edit the shipped `TritonTypes` enums; route org-specific values to `String` constants.
- Report (don't silently invent) flush gaps introduced by the buffering default.
- Idempotent: a file with no `Triton.instance` usage is left untouched.
