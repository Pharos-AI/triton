---
name: instrument-apex
summary: Instrument an Apex class or trigger with Triton logging, then optionally deploy.
usage: instrument-apex <path-to-cls-or-trigger> [--area <Area>] [--type <Type>] [--deploy]
---

# Instrument Apex

Add production-grade Triton logging to an Apex class or trigger, following Pharos best practices, then optionally deploy to the connected Salesforce org.

> **Agent-agnostic skill.** Run it however your agent invokes skills — a slash command (`/pharos:instrument-apex <path>`), an `@`-mentioned instruction, or a pasted prompt. The steps below are the same regardless. `$ARGUMENTS` / the command arguments carry the path and flags.

> **API note:** Create logs by passing a fluent `TritonBuilder` to `Triton.log(...)` (buffered) or `Triton.logNow(...)` (immediate). Build from the current template with `Triton.t` (a template-derived builder that auto-stamps the transaction id), or start a fresh builder with `Triton.makeBuilder()`.

## Step 0 — Prerequisites check

Before touching any code:

```bash
which sf || which sfdx
```

If neither is found → stop and tell the user:
> "This skill requires the Salesforce CLI (`sf` or `sfdx`). Install it from https://developer.salesforce.com/tools/salesforcecli, then re-run."

Check org connection:

```bash
sf org display --json 2>&1 || sfdx force:org:display --json 2>&1
```

If the output contains `"status": "error"` or no default org is set → stop and tell the user:
> "No default Salesforce org connected. Run `sf org login web` (or `sfdx force:auth:web:login`) and set a default org with `sf config set target-org <alias>`, then re-run."

## Step 1 — Parse arguments

From the skill arguments:
- **File path** — the `.cls` or `.trigger` file to instrument (required). If not provided, ask: "Which Apex class or trigger file do you want to instrument? (provide the path)"
- **`--area`** — the business/functional area for these logs. **Infer this from the code and keep it consistent with related code** (Step 2) — it is the primary key for grouping and searching in Pharos. `.area()` takes the `TritonTypes.Area` enum or a **String**; enum values like `OpportunityManagement`/`Accounts` are illustrative examples, not a required mapping. If `--area` is given, use it verbatim.
- **`--type`** — technical classification. Default: `Backend`. `.type()` takes the `TritonTypes.Type` enum or a **String**; values like `Backend`, `BackendCall`, `DMLResult` are examples — infer what fits the code rather than forcing a mapping. (For callouts, classify as `Category.Integration` + a call type such as `BackendCall`.)
- **`--deploy`** — flag; if present, deploy after instrumentation. Otherwise ask at the end.

## Step 2 — Read and analyze the target file (structure first)

Read the full file content. **Before instrumenting, classify the code structure** — the transaction and flush pattern differs per structure. Identify:

1. **Structure type** (drives the whole approach):
   - **Trigger / trigger handler** — fires before+after; may re-enter within one DB transaction
   - **LWC/Aura controller** — `@AuraEnabled` methods (entry points; may receive a `transactionId` from an instrumented LWC)
   - **REST resource** — `@RestResource` / `@HttpGet|Post|...` methods (entry points)
   - **Invocable** — `@InvocableMethod` (entry point; may be called from a Flow)
   - **Batchable** — `start` / `execute` / `finish`; **each `execute` chunk runs in its own transaction**
   - **Queueable** — `execute(QueueableContext)`
   - **Schedulable** — `execute(SchedulableContext)`
   - **@future** — static `@future` method; **primitives-only params**
   - **Service / helper class** — called by the above; uses the ambient transaction
   - **Test class** (`@isTest`) — do **not** instrument
2. **Async dispatch sites**: any `System.enqueueJob(...)`, `Database.executeBatch(...)`, `System.schedule(...)`, or `@future` call inside this class — each async hop needs the transaction id threaded through it (Step 3b).
3. **Existing logging**: `System.debug()` calls to replace; existing Triton usage to respect.
4. **Method inventory**: public/private methods, purposes, params, return types.
5. **Error handling**: existing try-catch blocks (instrument these first).
6. **DML operations**: insert/update/delete/upsert/merge (add `dmlResults` logging — Step 3d).
7. **Callouts**: HTTP requests/responses (add `integrationPayload` logging — Step 3e).
8. **Area — infer from the code and match related code (give this special attention).** Area is the primary grouping/search key in Pharos, so consistency matters far more than matching a standard enum value:
   - First, look for Area values already used by **related code** — same-object triggers, the service/controller layer for this feature, or the LWC/Flow that calls this class — and **reuse that exact Area** so the whole feature groups together. Search the codebase for existing `.area(` / `setTemplate(` usage in related files.
   - If no related code sets an Area, derive one from the code's business/functional domain (the feature or process it serves), not from generic class-name keywords. Use `.area(String)` freely — the `TritonTypes.Area` enum values are only examples.
   - Only ask the user when the domain is genuinely ambiguous and there's no related code to match.

Summarize findings — including the **structure classification** and any async dispatch sites — to the user (1 short paragraph), then proceed.

## Step 3 — Apply Triton instrumentation

Use the builder + template pattern throughout. Pass builders to `Triton.log(...)` / `Triton.logNow(...)`.

> **Triton auto-enriches every log at `Triton.log()` time** — it captures the stack trace, operation name, governor **limit info**, and (for Apex-category logs) the execution context via `apexExecutionContext()`. Do **not** add these manually.

### 3a — Template initialization

At the **start of the entry-point method** (not in a shared `static {}` block — the template is a shared static and the last writer wins), set the template:

```apex
Triton.setTemplate(
    Triton.makeBuilder()                          // makeBuilder() defaults Category = Apex
        .type(TritonTypes.Type.<inferred-or-specified-type>)
        .area(TritonTypes.Area.<inferred-or-specified-area>)
);
```

Then create each log from the template with `Triton.t` — it clones the template and stamps the current transaction id automatically. For values outside the enums, use the String overloads: `.type('<CustomType>')` / `.area('<CustomArea>')` (there is **no** `category(String)` overload).

### 3b — Transaction management (resume-first, per structure)

The goal is **one correlated transaction** across the whole call chain. Always **resume-first**: only start a new transaction if none was supplied.

**Synchronous entry points** (`@AuraEnabled`, REST, `@InvocableMethod`):

```apex
// If this method is called from an instrumented LWC, accept the caller's id.
// Adding an optional `transactionId` param to an entry point is a SANCTIONED
// exception to the "never change signatures" rule — call it out in the diff.
if (String.isNotBlank(transactionId)) {
    Triton.resumeTransaction(transactionId);
} else {
    Triton.startTransaction();
}
```

Or, to correlate with zero param changes, use platform cache at entry: `Triton.withCache();` (resumes the cached transaction id if present, else starts one; gracefully falls back to a new transaction if cache is unavailable). Pick **one** mechanism per call chain and keep the LWC side consistent (the instrument-lwc skill passes a param named `transactionId`).

> ⚠️ **Do not use `withCache()` on `@AuraEnabled(Cacheable=true)` methods.** Salesforce treats cacheable Apex (which is what `@wire` calls) as **read-only** for Platform Cache, so `withCache()` cannot store or resume the id there — stitching silently breaks. For a cacheable method, take the explicit-param path: declare a `transactionId` param and call `Triton.resumeTransaction(transactionId)` (the instrument-lwc skill passes it). Cacheable Apex / `@wire` can't use Platform Cache for stitching — pass `transactionId` explicitly. See https://resources.pharos.ai/wire-cache-antipattern

**Trigger handlers** — guard the start so before/after and recursive re-entry don't reset the id mid-transaction:

```apex
if (Triton.TRANSACTION_ID == null) {
    Triton.startTransaction();
}
```

Log the affected record ids at INFO: `.relatedObjects(Trigger.newMap != null ? Trigger.newMap.keySet() : Trigger.oldMap.keySet())`.

**Batchable** — statics do **not** survive between `execute` chunks, so:
- Implement `Database.Stateful`.
- In the **constructor** (or `start`), capture the id in an instance field: `this.txId = Triton.startTransaction();`
- At the **top of each `execute`**, re-establish it: `Triton.resumeTransaction(this.txId);`
- **`Triton.flush()` at the end of each `execute`** (each chunk is its own transaction; flushing per chunk is governor-safe and prevents buffered logs from being dropped).
- In **`finish`**: `Triton.resumeTransaction(this.txId);` … final log … `Triton.flush(); Triton.stopTransaction();`

**Queueable / Schedulable** — thread the id through the job:
- Add a `String txId` constructor arg; store it.
- At the top of `execute`: `Triton.resumeTransaction(this.txId);`
- `Triton.flush();` before `execute` returns.

**@future** — only primitives cross the boundary:
- Add a `String transactionId` param; at entry `Triton.resumeTransaction(transactionId);`
- `Triton.flush();` before returning.

**Async dispatch sites** — when this class enqueues async work, capture and pass the current id so the hop stays correlated:

```apex
System.enqueueJob(new MyQueueable(payload, Triton.TRANSACTION_ID));
// or: myFutureMethod(recordId, Triton.TRANSACTION_ID);
```

**Private / service methods** — do **not** start, resume, or stop transactions. Use the ambient transaction set by the entry point.

**Stopping** — call `Triton.stopTransaction()` only at a true end-of-chain boundary (batch `finish`, top-level entry point completion). Do **not** stop in every method — it clears the id (and cached id) and severs correlation with downstream async work.

### 3c — Try-catch instrumentation (log and rethrow)

`.exception(e)` sets the type (from the exception), **ERROR** level, summary (from `e.getMessage()`), stack trace, details, and `createIssue()` — so don't add a redundant `.level(...)`. If you want a custom summary, chain `.summary(...)` **after** `.exception(e)` (otherwise `.exception()` overwrites it). Use `Triton.logNow(...)` so the error persists even if the transaction later dies:

```apex
} catch (Exception e) {
    Triton.logNow(
        Triton.t
            .exception(e)
            .summary('<ClassName>.<methodName> failed')  // optional; MUST come after .exception()
    );
    throw e;  // preserve original throw behavior
}
```

If the catch currently swallows the exception (no throw/return), add the log and leave the flow as-is. Do not change exception-handling behavior — only add logging.

For methods **without** try-catch that contain meaningful business logic (DML, callouts, complex conditions), wrap the body, buffering the success log and flushing at the boundary (Step 3f):

```apex
Long startTime = System.now().getTime();
try {
    // existing body here
    Triton.info(
        Triton.t
            .summary('<methodName> completed')
            .duration(System.now().getTime() - startTime)
    );
} catch (Exception e) {
    Triton.logNow(
        Triton.t
            .exception(e)
            .duration(System.now().getTime() - startTime)
    );
    throw e;
}
```

#### Performance marks — the timed-span API

For a stretch of work you want to see as a **span** rather than as one timed log, use a mark. `Triton.startMark()` derives the span name from the stack trace, times it, and emits a paired `Performance started: <name>` / `Performance: <name>` record; every log emitted in between is automatically parented to the mark, so an Apex trace nests instead of flattening into siblings. Close in a `finally` so a throw cannot leave a dangling mark:

```apex
Triton.startMark();          // named '<ClassName>.<methodName>' from the stack trace
try {
    // the measured work
} finally {
    Triton.endMark();        // no name to retype, and nothing to mistype
}
```

- `Triton.startMark('nightly-reconcile')` — for a span whose meaningful name is **not** a method name, or a method measured in several labelled segments. Not a performance shortcut: the stack trace is captured either way.
- `Triton.endMark(markName)` — closes a specific mark when it legitimately closes out of order (`startMark` returns the name). The newest mark with that name is the one that closes, so loops and recursion are safe.
- `Triton.startTriggerMark()` — in a trigger handler. Names the span `<Handler>.<BEFORE_UPDATE>`; the trigger context is the one thing a stack trace cannot carry.
- `Triton.clearMarks()` — deliberate recovery to a known-good state. Not needed in a batch chunk, a queueable or a future: a fresh execution context already starts clean.
- **A request boundary is just `Triton.startMark()` at the top of the entry point** — the outermost mark attaches to the transaction, so everything opened later nests under it. There is no boundary-specific method.
- **A batch phase is two existing calls**: `Triton.resumeTransaction(carriedId)` (when a transaction id is carried) then `Triton.startMark()`, which derives `MyBatch.execute` for free.
- Marks are **buffered like any other log and never flush** — keep your existing flush points (Step 3f).
- Marks emit at **FINE**. Dial a class up or down with a `Log_Level__mdt` rule, not with a call-site argument. A mark filtered out by a rule stays transparent: logs inside it nest under the nearest surviving ancestor.

Manual timing as shown above remains correct for a **one-off** duration on a single log — a mark is what you want when the stretch should appear as a span with everything inside it attached.

### 3d — DML result logging

`dmlResults(...)` inspects `SaveResult`/`DeleteResult`/`UpsertResult`/`MergeResult`/`UndeleteResult` and **only emits a log when there are failures** (it sets Type=DMLResult, ERROR level, and the failed ids as related objects). Use it after partial-success DML (`allOrNone = false`):

```apex
List<Database.SaveResult> results = Database.insert(records, false);
Triton.log(
    Triton.makeBuilder()
        .area(TritonTypes.Area.<area>)   // Area must be set on the builder (or via template)
        .dmlResults(results)
);
```

### 3e — Callout / integration logging

Attach the HTTP payload with `integrationPayload(req, res)` and classify as `Category.Integration` + `Type.BackendCall`:

```apex
HttpResponse res;
try {
    res = new Http().send(req);
    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
        Triton.logNow(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Integration)
                .type(TritonTypes.Type.BackendCall)
                .area(TritonTypes.Area.<area>)
                .summary('Callout failed: ' + res.getStatus())
                .details('statusCode=' + res.getStatusCode())
                .integrationPayload(req, res)
                .error()
        );
    }
} catch (Exception e) {
    Triton.logNow(
        Triton.makeBuilder()
            .category(TritonTypes.Category.Integration)
            .area(TritonTypes.Area.<area>)
            .exception(e)
            .integrationPayload(req, res)
    );
}
```

### 3f — Flush at transaction boundaries

Add `Triton.flush()` at:
- End of trigger execution (after all trigger logic)
- End of each Batchable `execute` chunk **and** `finish`
- End of `Queueable.execute()` / `Schedulable.execute()`
- End of `@future` methods (before return)
- End of `@AuraEnabled` methods (before return)
- End of REST resource / invocable methods

Do **not** flush inside for/while loops — buffer with `Triton.log(...)` in the loop, then flush once after the loop.

### 3g — Replace System.debug calls

Replace every `System.debug(...)` in non-test code with a buffered DEBUG log. Verbosity is controlled by Log Level custom metadata, so DEBUG lines are safe to leave in production:

```apex
// Before:
System.debug('Processing record: ' + record.Id);

// After:
Triton.debug(
    Triton.t
        .summary('Processing record')
        .details('recordId=' + record.Id)
);
```

Leave `System.debug` calls in `@isTest` classes unchanged.

### 3h — Related objects

When a method receives or produces record ids, add `.relatedObject(id)` (single) or `.relatedObjects(idSet)` (Set/List of Id or String) to the relevant builders. This drives correlation in the Pharos dashboard — prioritize it on error and DML logs.

### 3i — Data richness by level (attach more the more severe it is)

**Per-log payload richness scales inverse to severity.** The rarer and more serious the event, the more forensic context it carries — this is independent of how *often* a level fires. Match the data you attach to the level:

| Level | Per-log data |
|-------|--------------|
| **ERROR / WARNING / INFO** | **Maximum.** Serialize the relevant inputs and in-scope state into `.details()` with `JSON.serialize(...)` (method params, the record/DTO in hand, key locals, computed values), attach `.relatedObjects(...)` for every involved id, and include `.duration(...)` where the block is timed. On ERROR, `.exception(e)` already carries stack + context — add the serialized state *on top* of it. |
| **DEBUG** | **Reduced.** Named variables only — the branch taken, a query's shape/size, a count — as short `details` strings. No full serialization. |
| **FINE / FINER / FINEST** | **Progressively terse.** Short markers only (loop index, step name, a single value). Never serialize objects here. |

```apex
// ERROR — pack in serialized state on top of the auto-captured exception context
Triton.logNow(
    Triton.t
        .exception(e)
        .details('input=' + JSON.serialize(request) + '; stage=' + stage + '; matched=' + matched.size())
        .relatedObjects(new Map<Id, Account>(accounts).keySet())
);

// INFO — serialize the business-event payload
Triton.info(
    Triton.t
        .summary('Order batch completed')
        .details('result=' + JSON.serialize(new Map<String, Object>{ 'processed' => scope.size(), 'skipped' => skipped }))
        .duration(System.now().getTime() - startTime)
);

// FINEST — terse marker, no serialization
Triton.finest(Triton.t.summary('loop').details('i=' + i));
```

**Be more granular.** Verbosity is runtime-tunable via `Log_Level__mdt`, so instrument *more* DEBUG/FINE tracing points than you otherwise would — but keep each of those logs lean. Runtime filtering, not sparse payloads, is what keeps production quiet.

**PII carve-out.** "Everything available" **never** includes secrets or PII — passwords, tokens, session ids, SSNs, card numbers. Serialize a redacted copy of any object that may hold them; when in doubt, omit the field and add `// TODO: sanitize before logging`. This overrides the "attach maximum data" rule every time.

## Step 4 — Review diff with user

Present the full diff (old vs new) in a collapsed format:

```
## Instrumentation changes for <ClassName>

### Summary
- Structure classified as: <trigger | @AuraEnabled controller | batch | queueable | ...>
- Template initialized with: Category=Apex, Type=<type>, Area=<area>
- Transaction handling: <resume-first param | withCache | batch Stateful | async id threaded>
- N try-catch blocks instrumented (logNow + rethrow)
- N DML result logs added
- N callout/integration logs added
- N System.debug calls replaced
- Flush added at N transaction boundaries
- Signature changes: <none | added optional `transactionId` to <method> (sanctioned)>

### Key changes
[Show template init, transaction handling for this structure, one example try-catch, one DML/integration log]

Apply? (yes / modify / skip)
```

On "modify": accept free-form correction and re-apply before asking again.
On "skip": stop without writing.

## Step 5 — Write the instrumented file

Write the modified content back to the original file path. Do not create a new file.

## Step 6 — Deploy (if --deploy flag or user confirms)

If `--deploy` was not passed, ask: "Deploy to org now? (yes / no)"

On yes:

```bash
sf project deploy start --source-dir <path-to-file> --json
```

Or, if only `sfdx` is available:
```bash
sfdx force:source:deploy -p <path-to-file> --json
```

Parse the JSON output:
- If `"status": "Succeeded"` → report: "Deployed successfully. Component: `<ClassName>`."
- If errors present → show the component failures table and stop. Do not revert the file.

## Constraints

- Create logs via `Triton.log` / `Triton.logNow`, building from `Triton.t` (template) or `Triton.makeBuilder()`.
- Never change method signatures, access modifiers, or return types — **except** adding an optional `transactionId`/`txId` param to an entry-point method for transaction stitching, which is sanctioned and must be flagged in the diff.
- Always **resume-first**: `resumeTransaction(id)` if an id is supplied, else `startTransaction()` (or `withCache()`). Never blindly `startTransaction()` on an entry point that may be mid-chain.
- **Never use `withCache()` on `@AuraEnabled(Cacheable=true)` methods** — cacheable Apex (what `@wire` calls) is read-only for Platform Cache, so it can't stitch. Use the explicit `transactionId` param + `resumeTransaction` there. See https://resources.pharos.ai/wire-cache-antipattern
- **Scale per-log data to level (§3i):** ERROR/WARNING/INFO get maximum context — serialize inputs/state into `.details()` + `.relatedObjects(...)`; DEBUG gets named variables only; FINE/FINER/FINEST stay terse markers. The PII carve-out always wins over "attach maximum data."
- Batchable classes must be `Database.Stateful`, capture the id in an instance field, resume per `execute`, and flush per `execute` and in `finish`.
- Thread the transaction id through every async dispatch (`enqueueJob`, `executeBatch`, `@future`, `System.schedule`).
- Call `Triton.stopTransaction()` only at a true end-of-chain boundary — never in every method.
- Never change exception-handling behavior — only add logging before existing throws. Use `Triton.logNow(...)` for errors; put custom `.summary()` after `.exception()`.
- Never add logging inside test methods or `@isTest` classes.
- Never flush inside for/while loops.
- Do not manually add stack trace, operation, or limit info — `Triton.log()` adds them automatically.
- **Area gets special attention**: infer it from the code and reuse the Area already used by related code so a feature's logs group together. Area/Type enum values are examples, not a required mapping — use `.area(String)`/`.type(String)` when they fit better. Category should stay standard (`Apex`, or `Integration` for callouts).
- Never log PII (SSN, password, card numbers) — if detected, add `// TODO: sanitize before logging` and use a placeholder summary.
