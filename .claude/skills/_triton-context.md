# Triton — Shared Reference for `/pharos:instrument-*` Skills

> Read this file before running any of the three instrumentation skills:
> `/pharos:instrument-apex`, `/pharos:instrument-lwc`,
> `/pharos:instrument-flows`. It is the single source of truth for the
> public Triton API surface and the cross-cutting rules that span all
> three skills. The per-skill `SKILL.md` files describe **how** to
> instrument; this file describes **what** Triton exposes.
> Targets the **release/2.0** Triton API.

## What Triton is

Pharos Triton is the open-source Salesforce logging subproject of the
Pharos observability platform. One unified logging API across the three
Salesforce execution contexts:

- **Apex** — server-side classes, triggers, batches, queueables, REST resources.
- **Lightning Web Components** — client-side, also covers Aura.
- **Flows / Process Builder** — declarative automation via an invocable action.

Logs land on `pharos__Log__c` and feed the Pharos backend. Triton works
standalone even without the rest of Pharos installed.

## Core concepts

1. **Static (Apex) / module-singleton (LWC).** Apex `Triton` is fully
   static (`Triton.log(...)`, `Triton.startTransaction()` — no
   `Triton.instance`). LWC `new Triton()` returns the same module-scope
   instance every time; scope per component with `bindToComponent(id)`.
2. **Builder + template.** Set a template once with the stable
   attributes (category, type, area), then clone per log call via
   `Triton.fromTemplate()` (or `Triton.t` in Apex) /
   `this.triton.fromTemplate()` (LWC). Never construct a fresh
   `TritonBuilder` per call site.
3. **Buffered vs. immediate.** `Triton.log(builder)` buffers;
   `Triton.logNow(builder)` buffers + flushes the top entry. The level
   shortcuts (`Triton.error`, `Triton.warning`, `Triton.info`,
   `Triton.debug`, `Triton.fine`, `Triton.finer`, `Triton.finest`) also
   buffer and override the builder's level. Default rule: buffer the
   happy path, `logNow` errors so they survive a rolled-back
   transaction.
4. **Transaction IDs.** A UUID v4 from `Triton.startTransaction()`
   threads every log in one logical operation. Apex `Triton.withCache()`
   (void; not chainable) persists the ID in Session Cache so it survives
   `@future` / queueable / batch enqueue. LWC persists in
   `sessionStorage` automatically. Both sides accept a `transactionId`
   parameter on imperative calls / Flow invocations so work spanning
   all three contexts shares one ID. See **Cross-context transaction
   propagation** below.
5. **Auto-enrichment on `Triton.log()`.** `builder.prepareForLogging`
   runs inside `Triton.log` and stamps the transaction ID, captures the
   stack trace + operation if not set, calls `limitInfo()` for governor
   limits, and (Apex-category only) calls `apexExecutionContext()` —
   trigger op + sObject + batch size, or async context label.
6. **Log levels via Custom Metadata.** `Log_Level__mdt` records gate
   which logs persist. Triton walks Category × Type × Area permutations
   most-specific-first against `ERROR < WARNING < INFO < DEBUG < FINE
   < FINER < FINEST`.

## Apex API surface (`Triton`, `TritonBuilder`, `TritonTypes`)

### `Triton` (all static)

```apex
// template + transaction
void          setTemplate(TritonBuilder builder)
TritonBuilder fromTemplate()                  // clone of template + TRANSACTION_ID
TritonBuilder t {get;}                        // alias for fromTemplate()
TritonBuilder makeBuilder()                   // fresh builder, category defaults to Apex
void          withCache()                     // enable Session-cache propagation (void, not chainable)
String        startTransaction()
void          resumeTransaction(String transactionId)
void          stopTransaction()
String        TRANSACTION_ID                  // public field

// log entry points (all take a TritonBuilder)
void log(TritonBuilder builder)               // buffered, uses builder's level
void logNow(TritonBuilder builder)            // buffered + flushTop()
void error(TritonBuilder builder)             // buffered, overrides level to ERROR (+createIssue)
void warning(TritonBuilder builder)           // buffered, overrides level to WARNING
void info(TritonBuilder builder)              // buffered, overrides level to INFO
void debug(TritonBuilder builder)             // buffered, overrides level to DEBUG
void fine / finer / finest(TritonBuilder b)   // buffered, override level

// buffer management
void flush()                                  // persist all buffered logs
void flushTop()                               // persist last buffered log only
List<pharos__Log__c> drain()                  // return + clear buffer without publishing

// helpers
PostProcessingControlsBuilder makePostProcessingBuilder()
Boolean isLogAllowedForLogLevel(pharos__Log__c log)
```

**Removed in 2.0 (do not use):** `Triton.instance`, `Triton.addLog`,
`Triton.addError`, `Triton.addWarning`, `Triton.addDebug`,
`Triton.addEvent`, `Triton.addIntegrationError`, `Triton.addDMLResult`.
The fluent builder + uniform `Triton.log(builder)` entry point replaces
all of them.

### `TritonBuilder` (fluent; every setter returns `this`)

```
// classification
category(TritonTypes.Category)            type(TritonTypes.Type | String)
area(TritonTypes.Area | String)
level(TritonTypes.Level)

// level shortcuts (each optionally takes a summary; .error() also calls createIssue())
error() / error(String summary)
warning() / warning(String summary)
info() / info(String summary)
debug() / debug(String summary)
fine() / finer() / finest()  (and …(String summary) variants)

// content
summary(String)         // auto-truncates to 255 chars; overflow appended to details on build()
details(String)
stackTrace(String)
operation(String)       // pharos__Apex_Name__c
duration(Decimal)
action(String)          // Action__c — performance marks, named operations
createdTimestamp([Double])
createIssue()
attribute(String, Object)

// IDs + correlation
userId(Id)
relatedObject(Id | String)
relatedObjects(List<Id> | List<String> | Set<Id> | Set<String>)
transactionId(String)
interviewGuid(String)
flowApiName(String)

// integrations
integrationPayload(HttpRequest, HttpResponse)
integrationPayload(RestRequest, RestResponse)
exception(Exception)    // sets type, ERROR level, summary, stack, details, createIssue.
                        // OVERWRITES any previously set .summary(...) — call
                        // .summary('custom label') AFTER .exception(e) to keep a
                        // custom summary. Does NOT set category — let the template
                        // provide it. (Note: the LWC builder's .exception(error)
                        // preserves an existing summary; only Apex overwrites.)

// DML
dmlResults(List<Object> saveResults)
    // SaveResult/DeleteResult/UpsertResult/UndeleteResult/MergeResult.
    // All succeeded: returns `this` unchanged. Any failed: sets type=DMLResult,
    // summary "DML Operation (Save) Failed: 3 of 100 records failed.",
    // details = per-error messages, relatedObjects = failed IDs, level = ERROR.

// limits
limitInfo()             // essential limits (default); no-op if withoutLimitInfo() was called
limitInfoLite()         // same as limitInfo() without full
withFullLimitInfo()     // extends limitInfo() with aggregates, SOSL, future, queueable, email, push, batch
withoutLimitInfo()      // disables limit capture (used by LWC; skip for Apex)

// post-processing + trace
postProcessing(TritonHelper.PostProcessingControlsBuilder)
tracePoint()                  // only emits if traceable() was called
traceable(Boolean)            // enables tracePoints; also calls createIssue

// execution context
apexExecutionContext()  // trigger op/sObject/batch size or async context label
                        // called automatically by Triton.log() for Apex-category logs

cloneBuilder()
build() -> pharos__Log__c
```

### `TritonTypes` enums — the only valid enum members

```
Category : Apex, Flow, LWC, Aura, Warning, Event, Debug, Integration
Level    : ERROR, WARNING, INFO, DEBUG, FINE, FINER, FINEST   // most→least severe
Type     : Backend, Frontend, DMLResult, LongRunningRequest, ConcurrentRequestsLimit,
           AccountTrigger, BackendCall, ComponentLifecycle, ComponentRender,
           UserInteraction, Performance
Area     : OpportunityManagement, LeadConversion, Community, RestAPI, Accounts, LWC, Flow
```

For values outside an enum, use the `String` overloads on `area(String)`
/ `type(String)`. Do **not** invent new enum members.

## LWC API surface (`c/triton`, `c/tritonBuilder`)

```javascript
import Triton, { AREA, CATEGORY, LEVEL, TYPE } from 'c/triton';
```

### `Triton` (module-scope singleton)

```
bindToComponent(componentId) -> Proxy   // scopes setTemplate/fromTemplate per component;
                                        // also issues a per-binding componentInstanceId and
                                        // binds methods to the receiver so `this` works.

setTemplate(builder)                    // only scoped when called through bindToComponent
fromTemplate() -> TritonBuilder         // clones the bound component's template, or makeBuilder() if none
makeBuilder() -> TritonBuilder

startTransaction()  -> string           // generates UUID, persists to sessionStorage
resumeTransaction(transactionId)
stopTransaction()                       // flushes + clears sessionStorage

log(builder)        -> TritonBuilder    // buffer
async logNow(builder) -> Promise        // buffer + flush()
async flush()       -> Promise          // POST buffered logs via @AuraEnabled saveComponentLogs

// builder shortcuts (return a configured builder; do not log on their own)
exception(error) error(type, area) warning(type, area) info(type, area) debug(type, area)

// performance / lifecycle tracking (require bindToComponent)
timeBackendCall(methodName, () => apexCall)
        -> PerformanceCallBuilder       // .withoutRethrow() .withCustomErrorHandler(fn) .execute()
timeUserInteraction(name, () => fn)
        -> PerformanceCallBuilder
startPerformanceMark(markName) / endPerformanceMark(markName)
trackComponentLifecycle('connected' | 'disconnected' | 'rendered')
trackComponentRender()
```

The auto-flush monitor inside `TransactionManager` flushes the buffer
after 10 s of inactivity (checked every 5 s), so most page lifetimes
don't need an explicit `flush()` call — `disconnectedCallback` should
still call `this.triton.flush()` for fast unmounts. (The inline
comments next to those constants in `triton.js` say "10 seconds" /
"1 minute" but the actual numeric values are 5 s / 10 s — trust the
numbers, not the comments.)

### `c/tritonBuilder` (fluent; chainable)

```
level(LEVEL.*)        category(CATEGORY.*)   type(TYPE.* | string)   area(AREA.* | string)
summary(string)       details(string)        action(string)          transactionId(string)
duration(ms)          timestamp(ms)
exception(error)      componentDetails(stack)
userId(id)            relatedObjects(id | id[])
runtimeInfo(obj)      clone() -> TritonBuilder    build() -> plain object
```

### LWC enum exports — smaller than Apex; do not assume parity

```
AREA     : ACCOUNTS, COMMUNITY, LEAD_CONVERSION, OPPORTUNITY_MANAGEMENT, REST_API
CATEGORY : LWC, AURA, WARNING, DEBUG, EVENT
LEVEL    : ERROR, WARNING, INFO, DEBUG, FINE, FINER, FINEST
TYPE     : BACKEND, FRONTEND, BACKEND_CALL, COMPONENT_LIFECYCLE, COMPONENT_RENDER,
           USER_INTERACTION, PERFORMANCE
```

There is no `AREA.LWC`, no `CATEGORY.APEX`, no DML type on the JS side.
For values outside these, pass a plain string —
`TritonLwc.saveComponentLogs` validates against the Apex enums and
falls back to `LWC` defaults with a note appended to `details`.

## Flow API surface (`TritonFlow.log` invocable action)

Wire a Flow `Action` element to:

- **Apex class** (`actionName`): `TritonFlow`
- **Label**: `Log` (category `TritonLogging`)
- **Action type**: `apex`

The action builds a log per `FlowLog` input then **drains the buffer
into `TritonFlowFlushBatch`** for deferred publish. The batch is
scheduled with a 1-minute delay; a singleton-check via `AsyncApexJob`
prevents duplicates; Org Cache holds logs across concurrent Flow
transactions. The invocable is fire-and-forget — no manual flush.

### `FlowLog` input parameters

| Name | Required | Notes |
| --- | --- | --- |
| `area` | yes | String — accepted as `TritonTypes.Area` enum name if it matches, else free-form |
| `summary` | yes | One-line summary (auto-truncated to 255 chars) |
| `interviewGUID` | yes | Always set to `{!$Flow.InterviewGuid}` — required for correlation |
| `category` | no | Defaults to `Flow`; invalid values fall back with a note |
| `type` | no | Free-form string |
| `level` | no | Defaults to `INFO`. `ERROR` also fires `createIssue()` automatically |
| `operation` | no | Maps to `Apex_Name__c` |
| `details` | no | Multiline details |
| `flowApiName` | no | Set to the Flow's API name for cross-referencing |
| `transactionId` | no | Pass through from caller (LWC/Apex) for cross-context tracing |
| `additionalFields` | no | JSON object string — keys become attributes on the log |
| `stacktrace` | no | Last-element stacktrace from a previous Triton Flow action |
| `fullStacktrace` | no | Accumulated stacktrace from prior Triton Flow actions |

### `FlowLogOutput` output parameters

- `stacktrace` — assign to a `Triton_StackTrace` String variable.
- `fullStacktrace` — assign to a `Triton_FullStackTrace` String variable
  and feed back into the next Triton action's `fullStacktrace` input to
  build a cumulative trace through the flow.

## Cross-context transaction propagation

The transaction ID lets one logical operation be traced from a button
click in an LWC, through an `@AuraEnabled` Apex method, into a Flow it
launches. The propagation rules:

| Boundary | Caller does | Callee does |
| --- | --- | --- |
| LWC → Apex | `apexCall({ ..., transactionId: this.triton.transactionId })` (or rely on `timeBackendCall` to thread it through) | Apex method accepts `String transactionId`, calls `Triton.resumeTransaction(transactionId)` first thing |
| Apex → Flow | Pass an input variable (e.g. `TritonTransactionId = Triton.TRANSACTION_ID`) when starting the flow | Flow forwards it into every `TritonFlow.log` action's `transactionId` input |
| Flow → Apex (invocable) | Pass `transactionId` as one of the invocable input params | Invocable Apex calls `Triton.resumeTransaction(transactionId)` |
| Apex → Apex (async) | Call `Triton.withCache();` once at the entry; the cache survives `@future`, queueable, batch enqueue | The async entry calls `Triton.withCache();`, which auto-resumes from Session Cache |

Platform Cache fallback: if Session Cache is unavailable,
`Triton.withCache()` silently degrades to in-memory transaction
tracking — never crashes.

## Common mistakes (framework-wide; do not repeat in skill output)

| Mistake | Reality |
| --- | --- |
| `Triton.instance.X(...)` | The release/2.0 `Triton` class is fully static. Use `Triton.X(...)`. |
| `Triton.addLog / addError / addWarning / addDebug / addEvent / addIntegrationError / addDMLResult` | Removed. Use `Triton.log(builder)` / `Triton.error(builder)` / `Triton.warning(builder)` etc. with a builder configured via `Triton.t` or `Triton.fromTemplate()`. For DML and integration payloads, use the builder-side `dmlResults(...)` and `integrationPayload(req, res)` methods. |
| `Triton.withCache().startTransaction()` chaining | `Triton.withCache()` returns `void`. Two separate statements. |
| Using `AREA.LWC` from `c/triton` | The JS `AREA` export only has `ACCOUNTS, COMMUNITY, LEAD_CONVERSION, OPPORTUNITY_MANAGEMENT, REST_API`. Use a string literal for anything else. |
| Calling `setTemplate` on the global `Triton` LWC instance without `bindToComponent` | The unbound `setTemplate` is not exposed by the proxy; templates are stored per-component-id. |
| Adding a custom `flush()` step after a `TritonFlow.log` action | The invocable defers to `TritonFlowFlushBatch` (1-minute delayed singleton batch); an extra flush adds nothing. |
| Inferring enum names beyond what `TritonTypes` defines | Always use the `String` overloads on `area(...)` / `type(...)` for custom values rather than adding enum members. |
| Setting `.category(...)` on a builder returned by `.exception(e)` | `exception(e)` deliberately does not touch category — it expects the template to provide it. Configure category via `Triton.setTemplate(...)` once. |