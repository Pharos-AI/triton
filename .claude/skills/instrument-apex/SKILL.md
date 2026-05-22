---
description: Instrument an Apex class or trigger with Triton release/2.0 logging and deploy to the connected org. Usage:/pharos:instrument-apex <path-to-cls-or-trigger-file> [--area <Area>] [--type <Type>]
---

# pharos:instrument-apex

Add production-grade Triton logging to an Apex class or trigger, following
the canonical Pharos patterns: builder+template, transaction tracking,
buffered logs flushed at transaction boundaries, immediate flush on errors,
DML and integration-error coverage, and deploy to the connected org. This skill targets the **release/2.0 Triton API** (fully-static
`Triton`, no `Triton.instance`).

## Step 0 — Load shared context, then check prerequisites

**Always read `../_triton-context.md` first** (the shared Triton API
reference, one directory up from this skill). It defines the public
Triton API surface (`Triton`, `TritonBuilder`, `TritonTypes`), the valid
enum members, the cross-context transaction-propagation rules, and the
common pitfalls every skill must avoid. Treat anything in this file that
contradicts the shared context as an error in this file.

Then run the shared CLI guard (same as the other instrumentation skills):

```bash
sf --version >/dev/null 2>&1 || sfdx --version >/dev/null 2>&1
sf org display --json 2>&1 || sfdx force:org:display --json 2>&1
```

- No CLI → stop: "Install the Salesforce CLI from
  https://developer.salesforce.com/tools/salesforcecli, then re-run."
- No default org → stop: "Run `sf org login web` and `sf config set
  target-org <alias>`, then re-run."

## Step 1 — Parse arguments

- **File path** (required) — the `.cls` or `.trigger` file. If missing,
  ask: "Which Apex class or trigger do you want to instrument?"
- **`--area`** — a `TritonTypes.Area` enum name (`OpportunityManagement`,
  `LeadConversion`, `Accounts`, `Community`, `RestAPI`, `LWC`, `Flow`) or
  any custom string (passed to the `String` overload of `area(...)`).
  Default: infer from class name (see Step 2). Only ask when ambiguous.
- **`--type`** — a `TritonTypes.Type` enum name (`Backend`, `Frontend`,
  `DMLResult`, `LongRunningRequest`, `ConcurrentRequestsLimit`,
  `AccountTrigger`, `BackendCall`, `ComponentLifecycle`, `ComponentRender`,
  `UserInteraction`, `Performance`) or any custom string. Default:
  `Backend`.

## Step 2 — Read and classify the file

Read the entire file. Decide which **artifact archetype** it is, because
the instrumentation differs:

| Archetype | Signals |
| --- | --- |
| **Trigger** | `trigger <Name> on <SObject>(...)` |
| **Batch** | `implements Database.Batchable<...>` (note whether `Database.Stateful`, `Database.AllowsCallouts`, `Schedulable` are also present) |
| **Queueable** | `implements Queueable` (and maybe `Database.AllowsCallouts`, `Finalizer`) |
| **Schedulable** | `implements Schedulable` |
| **REST resource** | `@RestResource(urlMapping=...)` |
| **AuraEnabled controller** | any `@AuraEnabled` method |
| **InvocableMethod** | any `@InvocableMethod` |
| **Service / utility class** | none of the above; just public/static methods |
| **Test class** | `@isTest` at class level → **do not instrument** |

Also catalogue:

- All `@AuraEnabled` / `@InvocableMethod` / REST endpoints (these are entry
  points that own transactions).
- Every `try { ... } catch { ... }` (instrument the catch).
- Every `Http().send(...)` and `RestRequest` consumer (integration logging).
- Every `Database.insert/update/upsert/delete/undelete/merge` returning a
  result collection (use `builder.dmlResults(...)`).
- Every `System.debug(...)` call (replace with a Triton equivalent).
- Trigger handler / framework hooks if a handler pattern is in use.

Infer the **Area** from the class name when `--area` was not provided:

- contains `Opportunity` / `Quote` / `Order` → `OpportunityManagement`
- contains `Lead` → `LeadConversion`
- contains `Account` / `Contact` → `Accounts`
- contains `Community` / `Portal` → `Community`
- contains `Rest` / `Api` / `Callout` → `RestAPI`
- otherwise → pass the class name to `area(String)`

Summarise the file (one short paragraph: archetype, method count, error
sites, DML sites, callout sites, debug calls) before applying
instrumentation.

## Step 3 — Apply Triton instrumentation

Apply each sub-step that matches the archetype. **Never construct a fresh
`TritonBuilder` per call site — always go through `Triton.t` (or
`Triton.fromTemplate()`) after setting the class template.**

### 3a — Class-level template

Add a `static {}` initializer immediately after the opening brace of the
class. Use enum members when they exist; pass `String` literals otherwise.
`Triton.makeBuilder()` already defaults `category(TritonTypes.Category.Apex)`,
so only set category when overriding.

```apex
static {
    Triton.setTemplate(
        Triton.makeBuilder()
            .type(TritonTypes.Type.<inferred-Type>)        // or .type('<custom>')
            .area(TritonTypes.Area.<inferred-Area>)         // or .area('<custom>')
    );
}
```

For triggers, put the same call as the **first line of the trigger body**
(triggers cannot have static initializers).

### 3b — Transaction lifecycle

The transaction lifecycle is anchored at **entry-point methods only**.
Inner helpers inherit the ambient transaction and must not start or stop
their own.

| Entry point | Pattern |
| --- | --- |
| Trigger | `Triton.startTransaction();` first thing; `Triton.flush(); Triton.stopTransaction();` at the very end of the trigger body (after all handlers). |
| `@AuraEnabled` method | Accept an optional `String transactionId` parameter. If provided, call `Triton.resumeTransaction(transactionId);` else `Triton.startTransaction();`. `Triton.flush(); Triton.stopTransaction();` before each `return` / inside a `finally`. |
| `@InvocableMethod` | Accept `transactionId` on the input wrapper; same resume-or-start pattern; `Triton.flush();` at the end of the `for` loop, not inside it. |
| REST resource (`@HttpGet`/`@HttpPost`/...) | Read `transactionId` from a header (`RestContext.request.headers.get('X-Pharos-Transaction-Id')`) or from the request body; resume-or-start; `Triton.flush(); Triton.stopTransaction();` before returning. |
| Batch / Queueable / Schedulable | See **Step 3f**. |
| Service / utility class | Do not touch the transaction lifecycle. Caller owns it. |

When the caller is an LWC, transaction IDs come in as a method parameter
(see LWC skill). When the caller is a Flow, the Flow passes `transactionId`
on the `TritonFlow.log` action; for invocable-from-flow methods, expose
`transactionId` on the wrapper.

### 3c — Try-catch instrumentation

For every existing `catch (Exception e)`:

```apex
} catch (Exception e) {
    Triton.logNow(
        Triton.t
            .exception(e)                          // sets summary from e.getMessage()
            .summary('<ClassName>.<method> failed') // override AFTER exception(); see note below
            .relatedObjects(<idCollection>)        // optional, when IDs are in scope
    );
    throw e;                                       // preserve original behaviour
}
```

- `Triton.logNow(builder)` is the **immediate** path — buffers and then
  `flushTop()`s. Use it at trigger / controller / REST / @InvocableMethod
  boundaries, where the surrounding transaction may roll back before a
  final `flush()`.
- Inside a method that is **guaranteed** to be followed by a final
  `flush()` (e.g. inside a batch `execute()` whose `finish()` flushes),
  prefer the buffered form: `Triton.error(Triton.t.summary(...).exception(e))`.
  This conserves platform-event allocations across the chunk.
- `builder.exception(e)` sets `type` from the exception class, `level`
  ERROR, `summary` from `e.getMessage()`, `stackTrace` from
  `e.getStackTraceString()`, `details` from `String.valueOf(e)` + stack,
  and `createIssue()`. It deliberately does **not** set category — the
  template provides it.
- **Order matters with `summary` and `exception` in Apex:** Apex's
  `.exception(e)` *unconditionally* overwrites any previously set
  summary with `e.getMessage()`. If you want a custom summary (e.g.
  `'<ClassName>.<method> failed'`), call `.summary(...)` **after**
  `.exception(e)`, not before. (LWC's `.exception(error)` preserves an
  existing summary — only Apex overwrites.)
- If the catch currently swallows the exception (no rethrow), keep that
  behaviour; do **not** add a `throw`.
- If the catch handles a callout failure (`HttpRequest`/`HttpResponse` in
  scope), use the integration variant from **Step 3e** instead.

For methods with no try-catch but meaningful business logic (DML,
callouts, heavy computation), wrap the body:

```apex
Long t0 = System.now().getTime();
try {
    // existing body
    Triton.info(
        Triton.t
            .summary('<methodName> completed')
            .duration(System.now().getTime() - t0)
    );
} catch (Exception e) {
    Triton.logNow(Triton.t.exception(e));
    throw e;
}
```

### 3d — DML result logging

DML logging is now on the builder. `builder.dmlResults(results)` returns
the same builder unchanged if every result succeeded, or — on partial
failure — configures it as a `Type.DMLResult` ERROR log with the failed
record IDs as related objects and per-error messages in details. You
still need to hand it to `Triton.log(...)` to persist:

```apex
List<Database.SaveResult> results = Database.insert(records, false);
Triton.log(Triton.t.dmlResults(results));
```

Wire it after every `Database.<op>(..., false)` (partial-success) call.
For `insert records;` (all-or-nothing), the surrounding `try/catch`
already captures the `DmlException` via **Step 3c** — do not double-log.

### 3e — Integration / callout logging

HTTP callouts have two failure modes; each gets a distinct shape.

**Mode 1 — the callout itself throws** (`CalloutException`, timeouts, etc.).
The response may be `null`:

```apex
HttpRequest req = buildRequest();
HttpResponse res;
try {
    res = new Http().send(req);
} catch (Exception e) {
    Triton.logNow(
        Triton.t
            .category(TritonTypes.Category.Integration)
            .exception(e)                           // sets type/level/summary/stack/details/createIssue
            .integrationPayload(req, res)           // attaches Postman-replay payload (res may be null)
            .relatedObjects(parentRecordIds)        // optional
    );
    throw e;
}
```

- For inbound REST endpoints, swap `HttpRequest`/`HttpResponse` for
  `RestRequest`/`RestResponse` — `integrationPayload` has both overloads.
- Use `Triton.logNow(...)` at controller boundaries; use `Triton.error(...)`
  inside a batch `execute()` so `finish()` can flush in bulk.

**Mode 2 — the request completed but returned a non-2xx response.** No
exception is thrown, but the operation has failed:

```apex
HttpResponse res = new Http().send(req);
if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
    Triton.logNow(
        Triton.t
            .category(TritonTypes.Category.Integration)
            .type(TritonTypes.Type.BackendCall)
            .summary('Callout failed: ' + res.getStatus())
            .details('statusCode=' + res.getStatusCode() + '\nbody=' + res.getBody())
            .integrationPayload(req, res)
            .error()                                // sets ERROR level + createIssue()
            .relatedObjects(parentRecordIds)
    );
    return;
}
```

If the callout returns 2xx, do **not** add an integration log — Triton is
for diagnostics, not request auditing. Use a low-level INFO/DEBUG
`Triton.log(...)` if business context warrants it.

### 3f — Batch / asynchronous class logging

Batches need extra care because each `execute()` chunk runs in its own
Salesforce transaction. Pattern:

```apex
public with sharing class LeadsBatch implements
        Database.Batchable<sObject>,
        Database.Stateful {                            // <-- required to preserve buffer & template

    public String query;

    public LeadsBatch(String query) {
        this.query = query;

        // template captures Type/Area for every log in this batch.
        // makeBuilder() already defaults category to Apex.
        Triton.setTemplate(
            Triton.makeBuilder()
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.LeadConversion)
        );

        // single transaction covers start + every execute() + finish(),
        // persisted across chunks via Session Cache.
        Triton.withCache();                            // void — call before startTransaction()
        Triton.startTransaction();

        Triton.debug(
            Triton.t
                .summary('LeadsBatch initialized')
                .details('query=' + query)
        );
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Triton.info(
            Triton.t
                .summary('LeadsBatch.start')
                .details('jobId=' + bc.getJobId())
        );
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        Set<Id> ids = new Map<Id, Lead>(scope).keySet();
        try {
            // ... business logic ...

            List<Database.SaveResult> results = Database.update(scope, false);
            Triton.log(Triton.t.dmlResults(results));   // no-op if all succeeded

            Triton.fine(
                Triton.t
                    .summary('LeadsBatch.execute chunk processed')
                    .details('jobId=' + bc.getJobId() + ' size=' + scope.size())
                    .relatedObjects(ids)
            );
        } catch (Exception e) {
            // buffered — finish() will flush. Keeps platform-event allocations low.
            Triton.error(Triton.t.exception(e).relatedObjects(ids));
            throw e;
        }
    }

    public void finish(Database.BatchableContext bc) {
        Triton.info(
            Triton.t
                .summary('LeadsBatch.finish')
                .details('jobId=' + bc.getJobId())
        );

        // flush + stop, even if a prior execute() threw — finish() always runs.
        Triton.flush();
        Triton.stopTransaction();
    }
}
```

Rules:
- The class **must** declare `Database.Stateful`, otherwise the in-memory
  buffer and template are discarded between `execute()` chunks.
- Call `Triton.withCache();` **on its own line** (it returns `void`) before
  `Triton.startTransaction();` so the transaction ID survives the chunk
  boundary via Session Cache. If Session Cache is unavailable,
  `withCache()` silently degrades — code stays correct.
- Inside `execute()`, buffer everything (`Triton.log`, `Triton.error`,
  `Triton.info`, `Triton.t.dmlResults(...)`,
  `Triton.t.integrationPayload(...).error()`). Do **not** call `flush()`
  inside `execute()` — the platform-event allocation is shared across the
  whole job and per-chunk flushing wastes it.
- `finish()` **always** runs, even if `execute()` threw. Put `flush()` and
  `stopTransaction()` there. Wrap them in a `try/finally` if `finish()` has
  any logic that could throw, so the flush still happens.
- For **Queueable** (no chunking, one `execute(QueueableContext)`): same
  shape — `Triton.withCache(); Triton.startTransaction();` in the
  constructor (so re-enqueued work reuses it), buffer through the body,
  `Triton.flush(); Triton.stopTransaction();` at the end of `execute()`.
  If the queueable chains via `System.enqueueJob(new NextJob())`, the next
  instance's constructor will resume the same transaction automatically
  thanks to `withCache()`.
- For **Schedulable** (`execute(SchedulableContext sc)`): same pattern as
  Queueable. If the schedulable enqueues a batch, the batch constructor's
  `withCache()` picks up the same transaction.
- For **`@future` methods**: call `Triton.withCache();` first thing, do the
  work, then `Triton.flush(); Triton.stopTransaction();` — but
  `withCache()` only resumes an existing transaction if the caller also
  opted in via `Triton.withCache()`.

### 3g — Replace `System.debug`

For every `System.debug(LoggingLevel level, message)` or
`System.debug(message)` in non-test code, replace with:

```apex
Triton.<info|debug|fine|finer|finest|warning>(
    Triton.t
        .summary('<short label>')
        .details(<the existing message expression>)
);
```

Map `LoggingLevel` → Triton entry point as `INFO→info`, `DEBUG→debug`,
`FINE→fine`, `FINER→finer`, `FINEST→finest`, `WARN→warning`, `ERROR→error`.
Leave `System.debug` calls in `@isTest` classes alone.

### 3h — Related object correlation

Whenever a record `Id` (or a `Set<Id>` / `List<Id>`) is in scope at a log
site, add it via `.relatedObject(id)` or `.relatedObjects(idCollection)`.
Pharos uses this to surface the log on the record's related list.

Good places to attach related IDs:
- DML scopes: `.relatedObjects(new Map<Id, SObject>(records).keySet())`
- Single-record entry points: `.relatedObject(input.recordId)`
- Batch `execute(scope)`: `.relatedObjects(...)` with the scope keyset.
- Integration logs: pass the parent record ID(s) that triggered the
  callout.

Note: `builder.dmlResults(...)` already calls `.relatedObjects(failedIds)`
internally — do not double-set on the same builder.

## Step 4 — Review diff with the user

Present a summary then the most representative changes. Keep it short —
the user does not need to see every modified line, just enough to verify
intent.

```
## Instrumentation changes for <ClassName>

### Summary
- Archetype: <Batch | Queueable | Trigger | AuraEnabled controller | ...>
- Template: Type=<type>, Area=<area>   (category=Apex inherited from makeBuilder())
- Transaction lifecycle: <constructor/withCache | trigger start/end | resume-from-param | n/a>
- Error logging: N catch blocks instrumented (<immediate|buffered>)
- DML logging: N `builder.dmlResults(...)` calls added
- Integration logging: N callouts wrapped (M non-2xx checks + K exception paths)
- Batch finish flush + stopTransaction: <yes | n/a>
- System.debug replacements: N
- Related objects attached: N log sites

### Key changes
[show: the static initializer; one catch block; one DML log; one integration log;
 if batch: the constructor + finish() additions]

Apply? (yes / modify / skip)
```

On "modify": accept the correction and re-apply before asking again.
On "skip": stop without writing.

## Step 5 — Write the instrumented file

Write the modified content back to the original `.cls` / `.trigger` path.
Do **not** create a new file or duplicate code paths.

## Step 6 — Deploy (mandatory; doubles as compile-check)

Deployment is **not optional** — it validates the instrumentation
compiles against the target org and surfaces any mistakes (typos in
`Triton.*` calls, unknown enum members, missing semicolons, misplaced
`static {}` blocks) immediately. Always run it after the user accepts
the diff in Step 4. Do not ask for permission; do not skip on success
of Step 5.

```bash
sf project deploy start --source-dir <path-to-file> --json
# or
sfdx force:source:deploy -p <path-to-file> --json
```

Parse the JSON result:

- `"status": "Succeeded"` → report "Deployed `<ClassName>` successfully."
- Any component failure → enter the **repair loop** below.

### Repair loop

The deploy failure messages are your compile-check feedback. Treat them
as authoritative — Apex deploys do not surface false positives.

1. Print the component failure table (problemType, file, line, error
   message) so the user sees what went wrong.
2. Analyse each error against `../_triton-context.md`. If an error says
   a method or enum member does not exist, that symbol is not in the
   release/2.0 API and must be replaced — do not retry with the same
   call. Common roots: chained `Triton.withCache().startTransaction()`
   (returns `void`), invented `TritonTypes.Type` / `Area` members,
   leftover `Triton.instance.*` accessor, `Triton.addError(...)` /
   `Triton.addDMLResult(...)` / `Triton.addIntegrationError(...)` calls
   from older Triton, missing imports for downstream types.
3. Make a focused edit to the instrumented file that addresses every
   reported error. Do not revert unrelated lines; do not roll back to
   the pre-instrumentation state.
4. Redeploy once.

If the second deploy still fails, **stop**. Print the remaining
failures and tell the user: "Deploy is still failing after one repair
pass. Review the errors above; the instrumented file is left in place
so you can hand-edit before re-running the deploy command."

For trigger files, after the trigger itself deploys cleanly, offer (but
do not require) to deploy the matching test class if one exists
(`<TriggerName>Test.cls` or `<HandlerName>Test.cls`) — useful before a
later prod deploy that needs code coverage.

## Constraints

- Never change method signatures, access modifiers, return types, or
  trigger event coverage. Logging is additive only. **One exception:**
  adding an optional `String transactionId` parameter to entry-point
  methods (per Step 3b) is permitted — it's backwards-compatible
  (existing callers passing nothing receive `null`) and required for
  cross-context tracing from LWC / Flow.
- Never change exception-handling behaviour. Add the log call before the
  existing `throw` / before the existing recovery code.
- Never add Triton calls inside `@isTest` classes, test data factories,
  or test setup methods.
- Never call `flush()` inside a `for` / `while` loop — buffer through the
  loop and flush once after.
- Never construct a fresh `TritonBuilder` per call site outside the static
  initializer / constructor. Use `Triton.t` (or `Triton.fromTemplate()`).
- Never use the removed `Triton.instance.*` accessor or the removed
  `add*` / `addError` / `addDMLResult` / `addIntegrationError` convenience
  methods. They do not exist in release/2.0.
- Never chain `Triton.withCache().startTransaction()` — `withCache()`
  returns `void`. Two separate statements.
- Never invent new `TritonTypes` enum members. Use the `String` overloads
  on `area(...)` / `type(...)` for custom values.
- Never log PII (passwords, tokens, session IDs, full SSNs, credit-card
  numbers). If detected in a payload, leave a `// TODO: sanitize before
  logging` comment and replace the value with a placeholder.
- For batch classes, do **not** call `flush()` inside `execute()` — let
  `finish()` own the flush so platform-event allocations are conserved.
- Prefer letting the template provide `.category(...)`. Only override
  on the builder when the log is genuinely a different kind (e.g.
  `Category.Integration` in Step 3e). `.exception(e)` does **not**
  touch category, so the order of `.category(...)` and `.exception(e)`
  is interchangeable — both before and after work the same way.