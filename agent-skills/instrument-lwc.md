---
name: instrument-lwc
summary: Instrument a Lightning Web Component with Triton logging, then optionally deploy.
usage: instrument-lwc <path-to-component-dir-or-js-file> [--area <Area>] [--type <Type>] [--deploy]
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

For `@wire` adapters, log errors from the callback:

```javascript
@wire(myApexMethod, { recordId: '$recordId' })
wiredResult({ data, error }) {
    if (error) {
        this.triton.logNow(
            this.triton.fromTemplate().summary('Wire adapter error').exception(error)
        );
    }
}
```

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

### 3i — disconnectedCallback flush (optional safety)

Flushing is already automatic (an idle auto-flush monitor runs, and `stopTransaction()` flushes). A `disconnectedCallback` flush is optional belt-and-suspenders:

```javascript
disconnectedCallback() {
    // existing body if any...
    this.triton.flush();   // optional — logs also auto-flush
}
```

## Step 4 — Review diff with user

```
## Instrumentation changes for <ComponentName>

### Summary
- Triton imported; bound with bindToComponent('<name>'), template TYPE=<type>, AREA=<area>
- Transaction stitching: <param `transactionId` | withCache (no param)>
- N Apex calls instrumented (timeBackendCall / manual)
- N error handlers instrumented with logNow
- N event handlers instrumented at DEBUG
- disconnectedCallback flush: <added (optional) | none>

### Key changes
[Show import, constructor bind+template, one timeBackendCall example, one error handler]

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
- Prefer `timeBackendCall(name, fn).execute()` for imperative Apex calls.
- Use `logNow` for errors (immediate), `log` for debug/info (buffered).
- Never change the component's `@api` properties, event dispatching, or public interface.
- Never add `await` to a non-async method — if `logNow` is needed in a sync context, make the method `async` and note it in the diff.
- Never flush inside loops or reactive property setters.
- Never log password fields, token values, or session data visible in component state.
