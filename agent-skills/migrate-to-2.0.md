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

**If the repo vendors Triton as source** (the `Triton*.cls` files live in the repo rather than arriving as a package), the library upgrade is part of this change: 2.0 removes `Triton.instance` entirely, so callers and library must land together or nothing compiles. Three things to settle before rewriting a single caller:

- **Diff the local `TritonTypes` against the incoming 2.0 one and re-add any org-local enum values.** A wholesale copy drops them and every reference fails to compile. This is the one shipped file expected to carry a local delta — see the note in Step 5. Org-local `Category` values are the exception: prefer retiring them per the severity-category note in Step 3 rather than preserving them.
- **Confirm the branch you are sweeping actually contains every caller.** The sweep is only as complete as its `<path>` and its branch. In a promotion-pipeline repo the integration branch can sit well ahead of the default branch; a sweep run against the wrong one removes `Triton.instance` from the library while live references survive elsewhere.
- **Add `**/__tests__/**` to `.forceignore` before any deploy.** 2.0 ships four LWC modules (`triton`, `tritonBuilder`, `tritonUtils`, `logLimits`), three of which carry Jest tests under `__tests__/`. Jest tests are not deployable metadata — they rely on Jest globals and test-only module mocks — so the Step 6 `sf project deploy` can reject the bundle unless the folder is ignored. Salesforce documents this entry alongside the `**/jsconfig.json` and `**/.eslintrc.json` ones many repos already have, so it is often the only line missing. The tests stay in version control; they are just never pushed to an org.

## Step 1 — Parse arguments

- **`<path>`** — required; a file or a directory (sweep every `.cls`/`.trigger`, **including `@isTest` classes**).
- **`--collapse-exceptions`** — collapse hand-assembled error logs to `.exception(e)`. **On by default**; `--no-collapse-exceptions` keeps them verbatim.
- **`--collapse-dml`** — collapse hand-built bulk-DML failure logs to `.dmlResults(results)`.
- **`--deploy`** — deploy after the diff is accepted.

## Step 2 — Find 1.x usage

Scan for `Triton.instance` and any legacy patterns. For each file, list the calls to migrate. If a file has none, skip it and say so. (`@isTest` classes: migrate the logging calls too — 1.x usage in tests still won't compile against 2.0.)

**Completeness gate.** Enumerate every distinct `Triton.instance.<member>` in scope — including property reads such as `TRANSACTION_ID` and `logs`, which are not call-shaped and are missed by a regex expecting `(` — then match each against the Step 3 table **by member name *and* argument shape**. Matching on the name alone is not enough: most 1.x logging methods are overloaded, and the overloads map differently (`addError(area, e)` and `addError(area, e, relatedObjectIds)` produce different builders). **If a call's exact overload is absent from the table, stop and report it. Do not infer a mapping.**

1.x exposes roughly two dozen logging overloads, and an immediate twin of every `add*` method (`error`, `warning`, `debug`, `event`, `dmlResult`, `integrationError`, `log`) plus `flushTop` and `withCache`. `makeBuilder`, `makePostProcessingBuilder` and `isLogAllowedForLogLevel` are already `static` in 1.x, so they are never written as `Triton.instance.*` and need no migration.

## Step 3 — Apply the method mapping

Rewrite each call using this mapping. The `.instance` drops away and positional args move onto a builder — but **the table shows the call shape, not the full field set.** The 1.x convenience methods inject fields you cannot see at the call site (`category`, `postProcessing`, `stackTrace`, `level`, `createIssue`). Open each 1.x method body in the version you are migrating *from* and carry across every field it set. Where 2.0 sets a field automatically — it captures stacktraces in `prepareForLogging` and defaults `category` to `Apex` — note that in the summary instead of restating it at the call site.

| Triton 1.x | Triton 2.0 |
|------------|------------|
| `Triton.instance.error(area, e)` | `Triton.logNow(Triton.t.area(area).exception(e))` |
| `Triton.instance.addError(area, e)` | `Triton.error(Triton.t.area(area).exception(e))` |
| `Triton.instance.error(area, e, relatedObjectIds)` | `Triton.logNow(Triton.t.area(area).exception(e).relatedObjects(relatedObjectIds))` |
| `Triton.instance.addError(area, e, relatedObjectIds)` | `Triton.error(Triton.t.area(area).exception(e).relatedObjects(relatedObjectIds))` |
| `Triton.instance.error(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).error())` |
| `Triton.instance.addError(type, area, summary, details)` | `Triton.error(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.warning(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).warning())` † |
| `Triton.instance.addWarning(type, area, summary, details)` | `Triton.warning(Triton.t.type(type).area(area).summary(summary).details(details))` † |
| `Triton.instance.debug(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).debug())` |
| `Triton.instance.addDebug(type, area, summary, details)` | `Triton.debug(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.debug(type, area, summary, details, duration)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).duration(duration).debug())` |
| `Triton.instance.addDebug(type, area, summary, details, duration)` | `Triton.debug(Triton.t.type(type).area(area).summary(summary).details(details).attribute(TritonBuilder.DURATION, duration))` |
| `Triton.instance.addEvent(level, type, area, summary, details)` | `Triton.log(Triton.t.type(type).area(area).summary(summary).details(details).level(level))` † |
| `Triton.instance.addEvent(type, area, summary, details)` | `Triton.info(Triton.t.type(type).area(area).summary(summary).details(details))` † |
| `Triton.instance.event(level, type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).level(level))` † |
| `Triton.instance.event(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).info())` † |
| `Triton.instance.addDMLResult(area, results)` | `Triton.error(Triton.t.area(area).dmlResults(results))` — **see Step 4b** |
| `Triton.instance.dmlResult(area, results)` | `Triton.logNow(Triton.t.area(area).dmlResults(results))` — **see Step 4b** |
| `Triton.instance.addIntegrationError(area, e, request, response)` | `Triton.error(Triton.t.area(area).exception(e).integrationPayload(request, response))` § |
| `Triton.instance.integrationError(area, e, request, response)` | `Triton.logNow(Triton.t.area(area).exception(e).integrationPayload(request, response))` § |
| `Triton.instance.addIntegrationError(type, area, summary, details, request, response)` | `Triton.error(Triton.t.type(type).area(area).summary(summary).details(details).integrationPayload(request, response))` § |
| `Triton.instance.integrationError(type, area, summary, details, request, response)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).integrationPayload(request, response))` § |
| `Triton.instance.addLog(builder)` | `Triton.log(builder)` |
| `Triton.instance.log(builder)` | `Triton.logNow(builder)` — 1.x `log` was `addLog` + `flushTop`, i.e. immediate |
| `Triton.instance.setTemplate(builder)` | `Triton.setTemplate(builder)` |
| `Triton.instance.fromTemplate()` | `Triton.fromTemplate()` (or `Triton.t`) |
| `Triton.instance.flush()` | `Triton.flush()` |
| `Triton.instance.flushTop()` | `Triton.flushTop()` |
| `Triton.instance.withCache()` | `Triton.withCache()` — **returns `void` in 2.0** (1.x returned `Triton`), so any chained call off it must be split |
| `Triton.instance.TRANSACTION_ID` | `Triton.TRANSACTION_ID` |
| `Triton.instance.logs` | `Triton.logs` (`@TestVisible`; test assertions only) |
| `Triton.instance.startTransaction()` | `Triton.startTransaction()` |
| `Triton.instance.resumeTransaction(id)` | `Triton.resumeTransaction(id)` |
| `Triton.instance.stopTransaction()` | `Triton.stopTransaction()` |

> **Note on `addIntegrationError`:** the legacy call wrote `Category = 'Integration'`; the 2.0 form intentionally lands as `Apex` — the Integration category is deprecated, and post-processing payload preservation is triggered by the `integrationPayload` itself, not by category.

> **Note on severity-shaped categories:** 1.x `addWarning` / `addDebug` / `addEvent` stamped `Category = Warning / Debug / Event`. Those Category values are removed in 2.0 — severity is expressed through the log **Level** (`.warning()`, `.debug()`, `.level(...)`; the mapped 2.0 forms above already do this). Category identifies the producing technology: categorize by where the call is made from. These are Apex APIs, so the default is `Apex` — omit `.category(...)` and the builder defaults to it; set `.category(...)` explicitly only when the call site is a bridge for another technology (Flow, LWC, Aura).

† **Carry the post-processing controls.** Separately from category, 1.x `addEvent`, `event`, `addWarning` and `warning` all set `.postProcessing(makePostProcessingBuilder().stackTrace(true).userInfo(true).relatedObjects(true))`. 2.0's `prepareForLogging` does not set post-processing, so omitting it silently disables Pharos-side enrichment on every migrated log — and no test will catch that. Append `.postProcessing(Triton.makePostProcessingBuilder().stackTrace(true).userInfo(true).relatedObjects(true))` to those rewrites, or state explicitly in the summary that the org has chosen to drop it.

§ **Http and Rest payloads share one mapping.** Each 1.x integration-error overload exists twice, once taking `HttpRequest`/`HttpResponse` and once taking `RestRequest`/`RestResponse`. 2.0's `integrationPayload(...)` is overloaded for both pairs, so the rewrite is identical either way — pass the request/response through unchanged.

Transaction/template methods are safe renames. The **logging** methods change shape — and hide the two gotchas below.

## Step 4 — The publishing gotcha (NEVER auto-decide)

In 1.x the **method name** decided publishing timing:
- **bare** methods (`error`, `warning`, `debug`, `event`, `dmlResult`, `integrationError`, `log`) published **immediately**.
- **`add*`** methods **buffered** until `flush()`.

In 2.0 **all level methods buffer**; you opt into immediate publishing with **`Triton.logNow(...)`**. That's why bare → `logNow` and `add*` → level methods in the table.

For **every old bare-method call**, do **not** silently choose. Present both options and ask:

```
<file>:<line>  Triton.instance.error(area, e)
  This published IMMEDIATELY in 1.x.
  [A] Triton.logNow(...)  — keep immediate publishing  (recommended if a later
      exception/callout/limit could kill the transaction before a flush)
  [B] Triton.error(...) + ensure a flush() covers this path  — buffer it
  Choose A / B:
```

Getting this wrong is how a migrated log silently disappears when the transaction dies before flushing.

## Step 4b — The conditional-logging gotcha (ALSO never auto-decide)

Timing is one axis of behavior change; **whether a log is emitted at all** is the other, and it is easier to miss because the rewrite looks correct.

Some 1.x methods only emit under a condition: `addDMLResult` and `dmlResult` wrap their `addLog` in `if(!errorMessages.isEmpty())`, so an all-success DML produced nothing. The 2.0 equivalents are unconditional — `builder.dmlResults(results)` populates no fields when nothing failed, but it still returns the builder, so `Triton.error(...)` buffers a **blank ERROR record and creates an issue on every successful DML**.

For every such call, inspect the call site and classify it:

```
<file>:<line>  Triton.instance.addDMLResult(area, results)
  1.x logged ONLY when a row failed. The 2.0 rewrite logs unconditionally.
  [guarded]   call site is already behind a failure check (if (!sr.isSuccess()),
              an early return/continue on success, or !failures.isEmpty()) — rewrite as-is
  [unguarded] propose a guard and show it in the diff
```

Report the guarded/unguarded split in the Step 6 summary. A log that fires on success is as wrong as one that never fires, and it is worse in volume: one spurious issue per successful batch row.

## Step 5 — Audit flush coverage & collapse

- **Flush coverage.** Now that level methods buffer, flag every path that logs but has no `Triton.flush()` at its boundary/`finally`. Report these alongside the diff (fixing them may require a boundary flush — propose it).
- **`--collapse-exceptions`.** Replace hand-set error fields (`.type(...).summary(e.getMessage()).details(e.getStackTraceString())`) with a single `.exception(e)` (which also sets ERROR level and issue creation). Put any custom `.summary(...)` **after** `.exception(e)`.
- **`--collapse-dml`.** Replace hand-built DML failure summaries with `.dmlResults(results)`.
- **Ad-hoc taxonomy.** Flag `.area('X')` / `.type('X')` string literals; suggest promoting them to `public static final String` constants rather than adding new values to the shipped `TritonTypes` enums — see the Custom Classifications guidance in the docs. This is about *adding* classifications; it does not mean an existing org-local `Area` or `Type` value may be dropped when re-vendoring the library (Step 0).

## Step 6 — Verify, review, write, deploy

**Verify before presenting.** Both checks are greppable and catch the failure modes a human reviewer reading a diff will not:

1. **No 1.x member survives.** Zero matches for `Triton.instance` in scope, and zero static calls to methods 2.0 does not have (`Triton.addError(`, `Triton.addEvent(`, `Triton.dmlResult(` and friends — a half-migrated call that merely dropped `.instance` compiles under neither version).
2. **Every enum reference resolves.** Each `TritonTypes.<enum>.<value>` in scope must exist in the post-migration `TritonTypes`. This is the check that catches both a vendored-library overwrite dropping org-local values and a mapping that emits a retired value such as `Category.Event`.

**Re-run check 1 immediately before merge, not just before presenting the diff.** Because 2.0 removes `Triton.instance`, the library and every caller have to land together — so on an active integration branch a caller that merges *after* your sweep but *before* yours lands leaves the branch with the 2.0 library and live 1.x references, which does not compile. The window is the review period, and it is easy to lose: verifying at sweep time proves nothing about merge time.

For anything beyond a one-off, make it a CI check rather than a habit: fail the build when `Triton.instance` appears in the source tree while `Triton.cls` has no `instance` member. That is a two-line grep, it runs on every pull request, and it converts a post-merge breakage into a pre-merge one. A deprecated `instance` facade delegating to the 2.0 statics is the stronger variant — it turns the same situation into a deprecation warning instead of a broken build, and lets stragglers migrate incrementally.

Then present a summary — calls migrated, bare-method decisions (A/B) taken, conditional-logging classifications, collapses applied, flush gaps found, fields carried across per the † note, and any `Category` reporting change implied by the severity-category note — then the diff, with `yes` / `modify` / `skip`. On `yes`, write back to the original file. With `--deploy` (or on confirmation), run `sf project deploy start --source-dir <path> --json` (or the `sfdx` equivalent).

> After deploying 2.0, remind the user to re-assign the `Triton_Read` / `Triton_Write` permission sets so the new fields are visible.

## Constraints

- Never auto-convert a bare-method call — always present the immediate (`logNow`) vs. buffer (+flush) choice.
- Never auto-convert a conditional 1.x method (`addDMLResult`, `dmlResult`) without classifying the call site as guarded or unguarded.
- Stop and report any `Triton.instance` member *or overload* that is not in the Step 3 table rather than inferring a mapping.
- Never change program behavior beyond the logging call itself; preserve control flow, throws, signatures. A failure guard added under Step 4b is a behavior *preservation*, not a change — show it explicitly in the diff.
- Do not add new values to the shipped `TritonTypes` enums; route org-specific values to `String` constants. Do, however, preserve org-local `Area` and `Type` values when re-vendoring the library (Step 0).
- Report (don't silently invent) flush gaps introduced by the buffering default.
- Idempotent: a file with no `Triton.instance` usage is left untouched.
