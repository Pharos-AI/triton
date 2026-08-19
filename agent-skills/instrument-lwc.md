---
name: instrument-lwc
summary: Instrument a Lightning Web Component with Triton logging, then optionally deploy.
usage: instrument-lwc <path-to-component-dir-or-js-file> [--area <Area>] [--type <Type>] [--perf <essential|standard|deep>] [--deploy]
---

# Instrument LWC

Add production-grade Triton logging to a Lightning Web Component, following Pharos best practices, then optionally deploy to the connected Salesforce org.

> **Agent-agnostic skill.** Run it however your agent invokes skills — a slash command (`/pharos:instrument-lwc <path>`), an `@`-mentioned instruction, or a pasted prompt. The steps are identical regardless.

> **API note:** `import Triton, { TYPE, AREA, LEVEL } from 'c/triton';`. `new Triton()` returns a **module-scoped singleton** that already initializes/resumes a transaction (from `sessionStorage`) on construction — so a transaction is always active. `.bindToComponent(name)` scopes it to your component. Every log builder is **auto-stamped with the current `transactionId`**, so LWC-originated logs are correlated automatically.

## Step 0 — Prerequisites check

```bash
which sf || which sfdx
```

If neither is found → stop:
> "This skill requires the Salesforce CLI (`sf` or `sfdx`). Install it from https://developer.salesforce.com/tools/salesforcecli, then re-run."

```bash
sf org display --json 2>&1 || sfdx force:org:display --json 2>&1
```

If no default org → stop:
> "No default Salesforce org connected. Run `sf org login web` and set a default with `sf config set target-org <alias>`, then re-run."

## Step 1 — Parse arguments

From the skill arguments:
- **Path** — the LWC component directory (e.g. `force-app/main/default/lwc/myComponent/`) or the `.js` file directly (required). If not provided, ask.
- **`--area`** — the feature's functional area, given as one of the `AREA` constants (`ACCOUNTS`, `COMMUNITY`, `LEAD_CONVERSION`, `OPPORTUNITY_MANAGEMENT`, `REST_API`). **Infer it from the code and match the area used by the paired Apex controller / related components** so the whole feature groups together (Step 2). The server records any area outside this set as `LWC`, so pick the closest matching constant; if none fits, omit `.area(...)` and logs record under `LWC`.
- **`--type`** — Triton `TYPE` constant. Real values: `BACKEND`, `FRONTEND`, `BACKEND_CALL`, `COMPONENT_LIFECYCLE`, `COMPONENT_RENDER`, `USER_INTERACTION`, `PERFORMANCE`. Default: `FRONTEND`.
- **`--perf`** — depth of performance/profiling instrumentation (§3k), as one of three verbosity tiers. Default: **`essential`**.
  - `essential` — backend-call + user-interaction timing only (Category 1).
  - `standard` — adds component-lifecycle timing and custom performance marks (Category 2).
  - `deep` — adds render-cycle tracking (Category 3); noisy, requires a prod filter (see §3k).
- **`--deploy`** — deploy after instrumentation.

If a directory is given, find the main JS file: `<componentName>.js` within it.

## Step 2 — Read and analyze the component

Read the `.js` file (and the `.html` template if present for context). Identify:

1. **Existing Triton import** — if `import Triton` already present, respect it; do not add a duplicate.
2. **Lifecycle hooks** — `constructor`, `connectedCallback`, `disconnectedCallback`.
3. **`@wire` adapters** — wired properties/methods (log errors from the wire callback).
4. **Imperative Apex calls** — `import x from '@salesforce/apex/...'` and their call sites (these are the transaction-stitching points).
5. **Event handlers** — `handle*` methods (user interactions to log at DEBUG).
6. **Error handling** — existing `.catch()` / `try...catch` (instrument these first).
7. **Area — match related code (give this special attention).** Determine the feature's functional area from the code and, above all, **reuse the area the paired Apex controller and related components already use** so the feature's logs group together. Pick the matching `AREA` constant. (The server coerces any value outside the `AREA` set to `LWC`, so if the feature's area isn't one of the constants, omit `.area(...)` and logs record under `LWC`.)

8. **Performance-instrumentation targets (drives §3k, scoped by `--perf`).** Note the sites each tier will touch: imperative Apex calls and `handle*` interaction handlers (Category 1); `connectedCallback`/`disconnectedCallback` and any notable client-side stretch — data shaping, debounce window, animation — worth a custom mark (Category 2); and whether the component re-renders enough to warrant render tracking (Category 3). You only instrument the tiers included by the resolved `--perf` level.

Summarize findings to the user (1 paragraph), then proceed.

## Step 3 — Apply Triton instrumentation

### 3a — Import

At the top of the file, after other imports, add:

```javascript
import Triton, { TYPE, AREA, LEVEL } from 'c/triton';
```

If already imported, skip. (`CATEGORY` is also exported but not needed for typical instrumentation.)

### 3b — Triton instance and template

Add a class-level `triton` property and bind it once. **`constructor` is preferred** (covers `@wire`, which fires early); `connectedCallback` is acceptable for purely imperative components. **Always call `bindToComponent`.**

```javascript
triton;

constructor() {
    super();
    this.triton = new Triton().bindToComponent('<componentName>');
    this.triton.setTemplate(
        this.triton.makeBuilder()
            .type(TYPE.<inferred-type>)
            .area(AREA.<inferred-area>)   // match the paired Apex controller's area; omit if none fits
    );
}
```

`new Triton()` returns the shared singleton and binds it to this component (it does not create an isolated instance). It **already starts/resumes a transaction on construction** — do **not** call `startTransaction()` here as well. Create logs with `this.triton.fromTemplate()`, which clones the template and stamps the current `transactionId`.

### 3c — Transaction stitching to Apex (do NOT invent a param)

LWC-originated logs are auto-correlated. To extend the **same** transaction into your Apex controller, use **one** of:

**Option A — pass the id (only when the Apex method declares the param).** The Apex side (see the instrument-apex skill) resumes a param named `transactionId`. Never add a key the Apex signature doesn't declare — that fails at runtime.

```javascript
const result = await loadOpps({
    accountId: this.recordId,
    transactionId: this.triton.transactionId
});
```

**Option B — platform cache (no param).** Leave the Apex call unchanged and have the Apex method call `Triton.withCache()`; the id rides Salesforce platform cache.

> ⚠️ **Never use Option B for `@wire` or any cacheable Apex.** `@wire` calls `@AuraEnabled(Cacheable=true)` methods, and cacheable Apex is **read-only** for Platform Cache — `withCache()` can't store or resume the id, so stitching silently breaks. For `@wire` / cacheable calls, **always** use Option A: pass `transactionId` explicitly (see §3d for the reactive-property wire pattern). Cacheable Apex / `@wire` can't use Platform Cache for stitching — pass `transactionId` explicitly. See https://resources.pharos.ai/wire-cache-antipattern

Do **not** start or stop a transaction inside individual handlers. The constructor already established one; per-handler `startTransaction()`/`stopTransaction()` splits a component's logs across multiple transactions and `stopTransaction()` clears the shared id (severing downstream correlation). For a genuine multi-step wizard, use `this.triton.enterStep()` to mark logical steps within the single transaction.

### 3d — Instrument imperative Apex calls

**Preferred — `timeBackendCall`** auto-logs start / success / failure with duration and span context (only rethrow needs handling):

```javascript
async handleSomeAction() {
    try {
        const result = await this.triton.timeBackendCall('myApexMethod', () =>
            myApexMethod({
                recordId: this.recordId,
                transactionId: this.triton.transactionId   // Option A stitching; omit if using withCache
            })
        ).execute();
        // ...use result
    } catch (error) {
        // timeBackendCall already logged the failure; handle UI state here
    }
}
```

Use `.withoutRethrow()` to swallow, or `.withCustomErrorHandler(fn)` for custom handling.

**Manual alternative** (when not using `timeBackendCall`):

```javascript
try {
    const result = await myApexMethod({ recordId: this.recordId, transactionId: this.triton.transactionId });
    this.triton.log(this.triton.fromTemplate().summary('myApexMethod succeeded'));
} catch (error) {
    await this.triton.logNow(this.triton.exception(error));
}
```

**For `@wire` adapters, stitch with an explicit `transactionId` — never `withCache()`.** Because `@wire` calls cacheable Apex (read-only for Platform Cache), the only reliable stitch is passing the id as a wire parameter. Expose the id as a **reactive property** set in the constructor, and reference it with the `'$prop'` syntax so the wire re-runs once it's assigned. The paired Apex method declares the `transactionId` param and calls `Triton.resumeTransaction(transactionId)`.

```javascript
_transactionId;

constructor() {
    super();
    this.triton = new Triton().bindToComponent('<componentName>');
    this._transactionId = this.triton.transactionId;   // reactive; drives the wire below
    // ...setTemplate(...) as in 3b
}

// transactionId flows to Apex so the wire's logs join this component's transaction
@wire(myApexMethod, { recordId: '$recordId', transactionId: '$_transactionId' })
wiredResult({ data, error }) {
    if (error) {
        this.triton.logNow(
            this.triton.fromTemplate().summary('Wire adapter error').exception(error)
        );
    }
}
```

> ⚠️ Cacheable Apex / `@wire` can't use Platform Cache for stitching — pass `transactionId` explicitly. See https://resources.pharos.ai/wire-cache-antipattern

### 3e — Event handler logging

For user-interaction handlers (`handle*`), add DEBUG-level logging at entry (reserve INFO for business milestones):

```javascript
handleButtonClick(event) {
    this.triton.log(
        this.triton.debug(TYPE.FRONTEND, AREA.<area>)
            .summary('User clicked <buttonName>')
            .details('recordId=' + this.recordId)
    );
    // existing handler body...
}
```

(`this.triton.debug(type, area)` / `.info(...)` / `.warning(...)` / `.error(...)` return a pre-leveled builder; `.exception(error)` returns an ERROR builder from a JS Error.)

### 3f — Error instrumentation

For every existing `.catch(error => ...)` / `catch (error)` not already instrumented, use **`logNow`** so the error persists immediately (before UI state changes):

```javascript
} catch (error) {
    await this.triton.logNow(this.triton.exception(error));
    // preserve original error handling below
}
```

`log` buffers; `logNow` flushes immediately. Use `logNow` for errors, `log` for debug/info.

### 3g — Business milestone logging

In methods representing significant business events (save, submit, approve, calculate), add INFO logging at completion:

```javascript
this.triton.log(
    this.triton.info(TYPE.FRONTEND, AREA.<area>)
        .summary('<ActionName> completed')
        .details('resultCount=' + result.length)
        .relatedObjects([this.recordId])
);
```

### 3h — Related objects

Whenever `this.recordId` or a result record id is available, chain `.relatedObjects([this.recordId])` — critical for dashboard correlation.

### 3i — Data richness by level (attach more the more severe it is)

**Per-log payload richness scales inverse to severity** — independent of how *often* a level fires. Match the data you attach to the level:

| Level | Per-log data |
|-------|--------------|
| **ERROR / WARNING / INFO** | **Maximum.** Serialize the relevant component state and call inputs into `.details()` with `JSON.stringify(...)` (the args passed to Apex, key `@api`/tracked values, the result summary), and attach `.relatedObjects([...])` for every involved id. |
| **DEBUG** | **Reduced.** Named values only — which handler ran, the record id, a count — as short `details` strings. No full serialization. |
| **FINE / FINER / FINEST** | **Progressively terse.** Short markers only (event name, step). Never serialize state here. |

```javascript
// ERROR — serialize the inputs/state alongside the exception
await this.triton.logNow(
    this.triton.exception(error)
        .details('args=' + JSON.stringify({ recordId: this.recordId, qty: this.quantity }))
        .relatedObjects([this.recordId])
);

// INFO — serialize the business-event result
this.triton.log(
    this.triton.info(TYPE.FRONTEND, AREA.<area>)
        .summary('Order submitted')
        .details('result=' + JSON.stringify({ orderId: result.id, lineCount: result.lines.length }))
        .relatedObjects([this.recordId])
);

// DEBUG — named values only, terse
this.triton.log(
    this.triton.debug(TYPE.FRONTEND, AREA.<area>)
        .summary('User clicked Save').details('recordId=' + this.recordId)
);
```

**Be more granular.** Verbosity is runtime-tunable via `Log_Level__mdt`, so add *more* DEBUG/FINE tracing points than you otherwise would — but keep each of those logs lean. Runtime filtering, not sparse payloads, keeps production quiet.

**PII carve-out.** "Everything available" **never** includes secrets or PII — passwords, tokens, session data, SSNs, card numbers. Serialize a redacted copy; when in doubt omit the field and add `// TODO: sanitize before logging`. This overrides the "attach maximum data" rule every time.

### 3j — disconnectedCallback flush (optional safety)

Flushing is already automatic (an idle auto-flush monitor runs, and `stopTransaction()` flushes). A `disconnectedCallback` flush is optional belt-and-suspenders:

```javascript
disconnectedCallback() {
    // existing body if any...
    this.triton.flush();   // optional — logs also auto-flush
}
```

### 3k — Performance instrumentation (scoped by `--perf`)

Triton ships profiling helpers that piggy-back on the bound `triton` instance and emit `pharos__Log__c` records with a `duration` and a typed `TYPE.*` marker. Instrument them in **verbosity tiers** set by `--perf` (default `essential`). Each tier maps to one of three log-level categories:

| Category | `--perf` from | Method(s) | Emitted `TYPE` | Instrument at |
|----------|---------------|-----------|----------------|---------------|
| **1 — Essential** (production baseline) | `essential`+ | `timeBackendCall(name, fn)` (§3d), `timeUserInteraction(name, fn)` | `BackendCall`, `UserInteraction` | imperative Apex calls; `handle*` interaction handlers |
| **2 — Standard/diagnostic** | `standard`+ | `trackComponentLifecycle('connected'\|'disconnected')`, `startPerformanceMark`/`endPerformanceMark` | `ComponentLifecycle`, `Performance` | connected/disconnectedCallback; notable client-side stretches |
| **3 — Deep trace** | `deep` only | `trackComponentRender()` | `ComponentRender` | `renderedCallback` |

> **These helpers require `bindToComponent()`** (already done in §3b) — without it they no-op with a console warning. All profiling helpers require the component to be bound.

> ⚠️ **All profiling logs emit at `INFO`** — the helpers don't set (or accept) a level, and the server defaults an un-leveled LWC log to INFO. You therefore **cannot** dial a perf log down to DEBUG/FINE. Control production noise at runtime with a **`Type`-scoped `Log_Level__mdt` rule** instead (each tier has its own `TYPE`), not by level. This is why the noisier tiers are opt-in.

#### Category 1 — Essential (`--perf essential`, the default)

`timeBackendCall` is already the preferred wrapper for imperative Apex calls (§3d) — it emits `BackendCall` start/complete timing for free. Additionally, wrap **user-driven handlers** whose responsiveness matters (`handle*` doing non-trivial work) with `timeUserInteraction`:

```javascript
async handleSearch(event) {
    await this.triton.timeUserInteraction('product-search', async () => {
        // existing handler body — the user-perceived latency of this block is timed
        this.results = await this.triton.timeBackendCall('searchProducts', () =>
            searchProducts({ term: this.term, transactionId: this.triton.transactionId })
        ).execute();
    }).execute();
}
```

(`timeUserInteraction` returns the same builder as `timeBackendCall`: `.execute()`, `.withoutRethrow()`, `.withCustomErrorHandler(fn)`.) Reserve it for interactions that do real work — don't wrap trivial toggles.

#### Category 2 — Standard (`--perf standard`)

**Lifecycle timing** — mount/unmount, one call each:

```javascript
connectedCallback() {
    this.triton.trackComponentLifecycle('connected');
    // existing body...
}
disconnectedCallback() {
    this.triton.trackComponentLifecycle('disconnected');
    // existing body...
}
```

**Custom marks** — for a notable client-side stretch the higher-level helpers don't model (data shaping, debounce window, animation). **Always pair start/end, and end in `finally`** so an exception can't leave a dangling mark. This is the same concept as Apex's `Triton.startMark()` / `Triton.endMark()` (see `instrument-apex.md`, §3c) — one span idiom across both tiers, differing today only in the method names:

```javascript
this.triton.startPerformanceMark('shape-results');
try {
    this.rows = this.transform(raw);   // the timed stretch
} finally {
    this.triton.endPerformanceMark('shape-results');   // emits a TYPE.PERFORMANCE log carrying the duration
}
```

Don't stack a mark on top of a `timeBackendCall`/`timeUserInteraction` that already covers the same span.

> **Cross-tier note.** On the Apex side a mark emits a **pair** of records — `Performance started: <name>` when it opens and `Performance: <name>` with the duration when it closes — so a span exists in the trace while it is still running and everything logged inside it can be parented to it. The LWC marks gain the same pairing with the paired-record change; the summary prefixes are identical on both tiers.

#### Category 3 — Deep (`--perf deep`)

**Render tracking** — one call in `renderedCallback`:

```javascript
renderedCallback() {
    this.triton.trackComponentRender();
    // existing body...
}
```

`renderedCallback` can fire many times, so this is the noisiest tier. Because the log is pinned to INFO, it **must** be filtered at runtime in production. When you add this, surface the note in the Step 4 diff (below) telling the user to add a `Log_Level__mdt` rule scoped to `Type = ComponentRender` at threshold `WARNING`, so the INFO render logs drop in prod but can be switched back on mid-investigation.

## Step 4 — Review diff with user

```
## Instrumentation changes for <ComponentName>

### Summary
- Triton imported; bound with bindToComponent('<name>'), template TYPE=<type>, AREA=<area>
- Transaction stitching: <param `transactionId` | withCache (no param)>
- N Apex calls instrumented (timeBackendCall / manual)
- N error handlers instrumented with logNow
- N event handlers instrumented at DEBUG
- Performance (--perf=<essential|standard|deep>): N backend-call + N user-interaction timers <; N lifecycle + N marks (standard)> <; render tracking (deep)>
- disconnectedCallback flush: <added (optional) | none>

### Key changes
[Show import, constructor bind+template, one timeBackendCall example, one error handler; one perf example matching the resolved tier]

<Include ONLY when --perf=deep added render tracking:>
⚠️ **Render tracking emits at INFO and can flood production.** Add a `Log_Level__mdt` rule scoped to `Type = ComponentRender` at threshold `WARNING` so these logs drop in prod (switch back to `FINE`/lower to capture them mid-investigation).

Apply? (yes / modify / skip)
```

## Step 5 — Write the instrumented file

Write the modified `.js` content back to the original file path.

## Step 6 — Deploy

If `--deploy` not passed, ask: "Deploy to org now? (yes / no)"

On yes, deploy the entire LWC component directory (HTML + metadata must go together):

```bash
sf project deploy start --source-dir <component-directory> --json
```

Or:
```bash
sfdx force:source:deploy -p <component-directory> --json
```

Parse result:
- `"status": "Succeeded"` → "Deployed `<ComponentName>` successfully."
- Errors → show the component failures table. Do not revert the file.

## Constraints

- Import is `import Triton, { TYPE, AREA, LEVEL } from 'c/triton';`. Pick the `AREA` constant matching the feature (consistent with the paired Apex); omit `.area(...)` when none fits (the server then records it as `LWC`). Keep `CATEGORY` standard.
- Always `bindToComponent(name)`. Do not call `startTransaction()` in the constructor — construction already starts/resumes one.
- Never start/stop a transaction per handler. Reserve `stopTransaction()` for true teardown; use `enterStep()` to segment a multi-step flow within one transaction.
- Only pass `transactionId` to an Apex method that declares the param; otherwise use `withCache()` on the Apex side. Never inject an undeclared key into an Apex call.
- **For `@wire` / cacheable Apex, always stitch with an explicit `transactionId`** (reactive property, §3d) — never rely on `withCache()`, which can't write to Platform Cache from cacheable Apex. See https://resources.pharos.ai/wire-cache-antipattern
- **Scale per-log data to level (§3i):** ERROR/WARNING/INFO serialize state/inputs into `.details()` + `.relatedObjects([...])`; DEBUG uses named values only; FINE/FINER/FINEST stay terse. The PII carve-out always wins over "attach maximum data."
- **Performance instrumentation is tiered by `--perf` (§3k), default `essential`:** Category 1 (`timeBackendCall`/`timeUserInteraction`) always; Category 2 (`trackComponentLifecycle`/custom marks) at `standard`+; Category 3 (`trackComponentRender`) at `deep` only. All profiling helpers require `bindToComponent()` and emit at **INFO** (level not settable) — control prod noise with `Type`-scoped `Log_Level__mdt` rules, not level.
- **Never leave `--perf deep` render tracking unguarded in prod:** it emits at INFO and is high-frequency — always surface the `Type=ComponentRender → WARNING` `Log_Level__mdt` note in the diff.
- Pair every `startPerformanceMark` with an `endPerformanceMark` in a `finally`; never wrap a span already covered by `timeBackendCall`/`timeUserInteraction`. The Apex equivalent is `Triton.startMark()` / `Triton.endMark()` — reuse the same span boundaries when instrumenting both tiers of one feature.
- Prefer `timeBackendCall(name, fn).execute()` for imperative Apex calls.
- Use `logNow` for errors (immediate), `log` for debug/info (buffered).
- Never change the component's `@api` properties, event dispatching, or public interface.
- Never add `await` to a non-async method — if `logNow` is needed in a sync context, make the method `async` and note it in the diff.
- Never flush inside loops or reactive property setters.
- Never log password fields, token values, or session data visible in component state.
