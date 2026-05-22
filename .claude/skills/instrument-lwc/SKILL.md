---
description: Instrument a Lightning Web Component with Triton release/2.0 logging and deploy to the connected org. Usage:/pharos:instrument-lwc <path-to-component-dir-or-js-file> [--area <Area>] [--type <Type>]
---

# pharos:instrument-lwc

Add production-grade Triton logging to a Lightning Web Component, then
deploy to the connected Salesforce org. Targets the
**release/2.0 Triton API**, which adds a high-level performance / lifecycle
tracking surface (`timeBackendCall`, `timeUserInteraction`,
`trackComponentLifecycle`, `startPerformanceMark` / `endPerformanceMark`)
on top of the existing builder API. Prefer those helpers over hand-rolled
try/catch + log instrumentation — they reduce boilerplate and capture
duration consistently.

## Step 0 — Load shared context, then check prerequisites

**Always read `../_triton-context.md` first** (the shared Triton API
reference, one directory up from this skill). It is the source of truth
for the LWC `Triton` class (`bindToComponent`, `fromTemplate`, builder
API, `AREA`/`CATEGORY`/`LEVEL`/`TYPE` exports), the cross-context
transaction-propagation rules, and the common pitfalls. Treat anything
here that contradicts it as an error in this file.

Then run the shared CLI guard:

```bash
sf --version >/dev/null 2>&1 || sfdx --version >/dev/null 2>&1
sf org display --json 2>&1 || sfdx force:org:display --json 2>&1
```

- No CLI → stop: "Install the Salesforce CLI from
  https://developer.salesforce.com/tools/salesforcecli, then re-run."
- No default org → stop: "Run `sf org login web` and `sf config set
  target-org <alias>`, then re-run."

## Step 1 — Parse arguments

- **Path** (required) — the LWC bundle directory
  (`force-app/main/default/lwc/<name>/`) or the bundle's `.js` file
  directly. If a directory is given, locate `<name>.js` inside it. If
  missing, ask: "Which LWC component do you want to instrument?"
- **`--area`** — an `AREA` export value (`ACCOUNTS`, `COMMUNITY`,
  `LEAD_CONVERSION`, `OPPORTUNITY_MANAGEMENT`, `REST_API`) or any custom
  string (passed as a string literal to `.area(...)`). Default: infer
  from component name (see Step 2). The JS `AREA` is smaller than the
  Apex enum — don't assume `AREA.LWC` exists.
- **`--type`** — a `TYPE` export value (`BACKEND`, `FRONTEND`,
  `BACKEND_CALL`, `COMPONENT_LIFECYCLE`, `COMPONENT_RENDER`,
  `USER_INTERACTION`, `PERFORMANCE`) or any custom string. Default:
  `FRONTEND`. The performance helpers in Step 3 set type per call site
  automatically — `--type` only seeds the template default.

## Step 2 — Read and analyse the component

Read the bundle's `.js` file (and the `.html` template if helpful for
context — it shows which event handlers in the `.js` are wired to user
input). Catalogue:

1. **Existing Triton import** — search for `from 'c/triton'`. If one
   already exists, respect it; do not add a duplicate.
2. **Class shape** — is it `LightningElement`, `LightningModal`,
   `NavigationMixin(LightningElement)`, etc. Note any `@api` properties
   (record IDs especially — used for `.relatedObjects(...)`).
3. **`@wire` adapters** — list every `@wire(method, { ... })` and the
   wired property handler. `@wire`-heavy components must initialise the
   Triton template in the **constructor**, not `connectedCallback`,
   because `@wire` fires before lifecycle hooks.
4. **Lifecycle hooks** — `constructor`, `connectedCallback`,
   `renderedCallback`, `disconnectedCallback`, `errorCallback`. Note
   which exist so we extend them instead of adding new ones.
5. **Imperative Apex calls** — `import` statements from
   `@salesforce/apex/...` and the call sites in `async`/`then`-chained
   methods. These are prime targets for `timeBackendCall`.
6. **Event handlers** — `handle*` methods, `on*` properties dispatched
   from the template. Distinguish *measured* interactions (form submit,
   save, navigate) from *trivial* ones (focus, hover) — only the former
   warrant `timeUserInteraction`.
7. **`.catch(error => ...)` / `try { } catch { }`** — every error site
   not already covered by a `timeBackendCall` / `timeUserInteraction`
   wrap needs explicit `logNow` instrumentation.
8. **`console.*` calls** — `console.log`, `console.error`, `console.warn`
   in production code (not test code). Replace with Triton equivalents.
9. **PII / sensitive fields** — passwords, tokens, session IDs visible
   in component state. Add `// TODO: sanitize before logging` if any
   appear in a log site.

Infer **AREA** from the component name when `--area` is not provided
(case-insensitive substring):

- contains `opportunity` / `quote` / `order` → `OPPORTUNITY_MANAGEMENT`
- contains `lead` → `LEAD_CONVERSION`
- contains `account` / `contact` → `ACCOUNTS`
- contains `community` / `portal` → `COMMUNITY`
- contains `rest` / `api` / `callout` → `REST_API`
- otherwise → pass the component name as a string (Triton accepts a
  free-form `area(String)`).

Summarise (one short paragraph: class shape, lifecycle hooks present,
@wire count, imperative Apex call count, event-handler count, error
sites) before applying instrumentation.

## Step 3 — Apply Triton instrumentation

Always use `bindToComponent` — the unbound `Triton` instance does not
expose scoped `setTemplate`/`fromTemplate`, and the new performance /
lifecycle helpers short-circuit (logging a console warning) without a
binding.

### 3a — Import

At the top of the file, after the other imports, add:

```javascript
import Triton, { AREA, LEVEL, TYPE } from 'c/triton';
```

If the file already imports `Triton`, merge the named imports rather
than duplicating the import statement.

### 3b — Bound instance + template

Add a class-level `triton` property and initialise it in the
**constructor**:

```javascript
triton;

constructor() {
    super();
    this.triton = new Triton().bindToComponent('<componentName>');
    this.triton.setTemplate(
        this.triton.makeBuilder()
            .type(TYPE.<inferred-type>)        // or .type('<custom>')
            .area(AREA.<inferred-area>)         // or .area('<custom>')
    );
}
```

Use the literal component name (camelCase, matching the bundle
directory) — the binding ID surfaces in Pharos as the operation /
component label. The constructor is preferred over `connectedCallback`
because `@wire` adapters fire before `connectedCallback` runs.

If a constructor already exists, append the binding lines after
`super()` and after any existing initialisation.

### 3c — Lifecycle tracking

Extend `connectedCallback` and `disconnectedCallback` (creating them if
absent). Add `renderedCallback` only when the component already has one
or when render performance matters.

```javascript
connectedCallback() {
    this.triton.trackComponentLifecycle('connected');
    // existing body, if any
}

renderedCallback() {
    this.triton.trackComponentRender();      // only if render counts matter
    // existing body, if any
}

disconnectedCallback() {
    this.triton.trackComponentLifecycle('disconnected');
    this.triton.flush();                     // guarantee delivery before unmount
    // existing body, if any
}
```

`trackComponentLifecycle` writes a `TYPE.COMPONENT_LIFECYCLE` log with
the event name. `trackComponentRender` writes a `TYPE.COMPONENT_RENDER`
log carrying the cumulative render count for the bound instance. The
auto-flush monitor flushes idle buffers after 10 s, but the explicit
`flush()` in `disconnectedCallback` covers fast unmounts.

### 3d — Imperative Apex calls → `timeBackendCall`

Replace hand-rolled try/catch + log instrumentation around imperative
Apex calls with `timeBackendCall`. It logs a `TYPE.BACKEND_CALL` entry
on start, on success (with `duration` and `action`), and on failure
(with the exception attached). It rethrows by default; configure with
`.withoutRethrow()` or `.withCustomErrorHandler(fn)` when the call site
needs different behaviour.

Before:

```javascript
async handleSave() {
    try {
        const result = await updateOpportunity({ recordId: this.recordId });
        this.refresh();
    } catch (error) {
        this.dispatchEvent(new ShowToastEvent({ variant: 'error', message: error.body.message }));
        throw error;
    }
}
```

After:

```javascript
async handleSave() {
    const result = await this.triton
        .timeBackendCall('updateOpportunity', () =>
            updateOpportunity({
                recordId: this.recordId,
                transactionId: this.triton.transactionId,        // propagate to Apex side
            }))
        .execute();
    this.refresh();
}
```

Pass `transactionId: this.triton.transactionId` to every Apex method
that participates in cross-context tracing. The Apex side must call
`Triton.resumeTransaction(transactionId)` — `_triton-context.md`'s
cross-context propagation table covers this end.

For sites that need to **swallow** the error (e.g. soft fallbacks):

```javascript
await this.triton
    .timeBackendCall('refreshOpportunity', () => refreshOpportunity({ recordId: this.recordId }))
    .withoutRethrow()
    .execute();
```

For sites that need bespoke user feedback (toast, inline error UI),
keep the rethrow behaviour and add the side-effect in a surrounding
`try/catch` — or use `.withCustomErrorHandler(fn)`:

```javascript
await this.triton
    .timeBackendCall('submitForm', () => submitForm({ payload }))
    .withCustomErrorHandler((error) => {
        this.errorMessage = error.body?.message ?? error.message;
        this.triton.logNow(this.triton.fromTemplate().exception(error));
    })
    .execute();
```

`withCustomErrorHandler` disables only the **built-in failure log** —
the start and success logs still fire normally. Call `logNow` (or
similar) inside the handler when explicit failure logging is still
wanted. `.withoutRethrow()` is orthogonal: it controls whether the
error propagates after the handler runs, not whether logs fire.

### 3e — `@wire` error logging

`@wire` adapters cannot use `timeBackendCall`. Add an error log to the
wired property handler:

```javascript
@wire(getOpportunity, { recordId: '$recordId' })
wiredOpportunity({ data, error }) {
    if (error) {
        this.triton.logNow(
            this.triton.fromTemplate()
                .exception(error)
                .summary('Wire error: getOpportunity')
                .relatedObjects([this.recordId]),
        );
        return;
    }
    if (data) {
        // existing body
    }
}
```

`logNow` returns a Promise; if the wired handler is sync, leaving the
Promise unawaited is fine — Triton owns delivery.

### 3f — User interactions → `timeUserInteraction` (selectively)

For interactions where duration matters (form submit, big rendering
operation, navigation), wrap the handler body in `timeUserInteraction`:

```javascript
async handleSubmit() {
    await this.triton
        .timeUserInteraction('handleSubmit', async () => {
            this.validate();
            await this.persist();
            this.dispatchEvent(new CustomEvent('saved'));
        })
        .execute();
}
```

For trivial interactions (focus, hover, simple toggles), don't reach for
`timeUserInteraction`. Either skip instrumentation entirely (low value,
high noise) or add a single DEBUG-level entry:

```javascript
handleToggle() {
    this.triton.log(
        this.triton.fromTemplate()
            .debug('User toggled section')
            .action('toggleSection')
            .relatedObjects([this.recordId]),
    );
    this.expanded = !this.expanded;
}
```

`.debug('User toggled section')` is the new builder shortcut — equivalent
to `.summary('User toggled section').level(LEVEL.DEBUG)`.

### 3g — Manual performance marks

Use `startPerformanceMark` / `endPerformanceMark` for ad-hoc timing
that doesn't map cleanly to `timeBackendCall` or `timeUserInteraction`
— e.g. timing a synchronous block, comparing two code paths, measuring
a render-to-interactive gap inside a single method:

```javascript
this.triton.startPerformanceMark('hydrateGrid');
this.gridRows = this.buildRows(data);
this.triton.endPerformanceMark('hydrateGrid');
```

Each pair emits one `TYPE.PERFORMANCE` log with the mark name in
`action` and the duration. Marks are scoped per component instance.

### 3h — Remaining error handlers

For every `.catch(...)` / `catch (error) { ... }` block not covered by
`timeBackendCall` or `timeUserInteraction`:

```javascript
} catch (error) {
    await this.triton.logNow(
        this.triton.fromTemplate()
            .exception(error)
            .relatedObjects([this.recordId]),
    );
    throw error;                                  // preserve original behaviour
}
```

- `logNow` is async and resolves when the log POSTs. Awaiting it in the
  catch is safe; ignoring the Promise is also safe.
- `builder.exception(error)` handles both standard JS errors and
  AuraEnabled error envelopes (`error.body.message` / `error.body.stackTrace`).
- If the original catch swallows the error (no rethrow), keep that
  behaviour — do not introduce a `throw`.

### 3i — Replace `console.*` calls

In production code (not Jest tests):

```javascript
console.error('Failed to load data', err);
// →
this.triton.logNow(
    this.triton.fromTemplate()
        .error('Failed to load data')
        .exception(err),
);

console.log('Refreshing list');
// →
this.triton.log(
    this.triton.fromTemplate()
        .debug('Refreshing list'),
);
```

Leave `console.*` calls in `__tests__/` / `*.test.js` files alone.

### 3j — Related object correlation

Whenever `this.recordId`, an `@api` property, or a wired record ID is
in scope at a log site, chain `.relatedObjects([id])` (or
`.relatedObjects([id1, id2])`). This is what powers the "Logs" related
list in Pharos.

Good places to attach related IDs:
- Every `timeBackendCall` error log (via `.withCustomErrorHandler`).
- Every imperative `logNow(builder)` call inside an event handler.
- Every wired-error log.

`timeBackendCall` and `timeUserInteraction` do not auto-attach record
IDs — wire them in via the bound template if every log in the
component should carry the record ID:

```javascript
constructor() {
    super();
    this.triton = new Triton().bindToComponent('opportunityCard');
}

connectedCallback() {
    this.triton.setTemplate(
        this.triton.makeBuilder()
            .type(TYPE.FRONTEND)
            .area(AREA.OPPORTUNITY_MANAGEMENT)
            .relatedObjects([this.recordId]),         // available now that connectedCallback ran
    );
    this.triton.trackComponentLifecycle('connected');
}
```

If `recordId` is only available after a `@wire` resolves, set the
template again from the wired handler — `setTemplate` overwrites the
previous binding.

### 3k — Transaction ID propagation to Apex

Every imperative Apex call that participates in cross-context tracing
needs to pass `this.triton.transactionId` as a parameter. The Apex side
(see `instrument-apex`) reads it and calls
`Triton.resumeTransaction(transactionId)` as the first line of the
method body. Without this, the LWC and Apex logs end up on different
transactions in Pharos and the trace breaks.

For `@wire` calls, transaction propagation requires the Apex method to
accept the ID as a wire parameter and the LWC to expose a tracked
property bound to `this.triton.transactionId` — usually more friction
than it's worth. Wire calls are read-only and idempotent; skip
propagation unless the wired method has side effects.

## Step 4 — Review diff with the user

Present a compact summary and a few representative snippets.

```
## Instrumentation changes for <ComponentName>

### Summary
- Class shape: <LightningElement | LightningModal | Mixin>
- Template: TYPE=<type>, AREA=<area>   (bound via 'componentName')
- Lifecycle tracking: connectedCallback / disconnectedCallback / renderedCallback
- timeBackendCall wraps: N imperative Apex calls
- timeUserInteraction wraps: N event handlers
- Manual performance marks: N pairs
- Wire error logs: N
- Catch blocks instrumented (logNow): N
- console.* replacements: N
- Related-object correlation: <template-wide | per-call-site>
- Transaction ID propagation: <yes / partial / n/a>

### Key changes
[show: import block; constructor with bindToComponent + setTemplate;
 one timeBackendCall example; one lifecycle hook; one wire error handler]

Apply? (yes / modify / skip)
```

On "modify": accept the correction and re-apply before asking again.
On "skip": stop without writing.

## Step 5 — Write the instrumented file

Write the modified `.js` back to its original path. Do **not** create a
new file or split into multiple bundles.

## Step 6 — Deploy (mandatory; doubles as compile-check)

Deployment is **not optional** — it validates that the modified bundle
parses, that every imported symbol (`Triton`, `AREA`, `TYPE`, `LEVEL`,
the wrapped Apex methods) resolves, and that no syntactic mistakes
slipped into the instrumentation. Always run it after the user accepts
the diff in Step 4. Do not ask for permission.

LWC deploys must target the **bundle directory** (so the `.js`, `.html`,
and `.js-meta.xml` all deploy together):

```bash
sf project deploy start --source-dir <path-to-bundle-directory> --json
# or
sfdx force:source:deploy -p <path-to-bundle-directory> --json
```

Parse the JSON result:

- `"status": "Succeeded"` → "Deployed `<ComponentName>` successfully."
- Any component failure → enter the **repair loop** below.

### Repair loop

The deploy failure messages are your validation feedback. Common roots:

- Importing a non-existent enum member (e.g. `AREA.LWC`,
  `CATEGORY.APEX`) — only the values listed in `../_triton-context.md`'s
  *LWC enum exports* section exist; everything else must be a string
  literal.
- Calling a performance / lifecycle helper without first running
  `bindToComponent` (the deploy itself won't catch this, but a related
  console warning shows up in the deployed component).
- A missing `async` qualifier on a method that now `await`s `logNow` /
  `flush` / `timeBackendCall.execute()`.
- Stale wiring in `disconnectedCallback` (e.g. calling
  `this.triton.flush()` before `this.triton` is initialised because the
  binding was inside `connectedCallback` but the method runs anyway).

Steps:

1. Print the component failure table (file, line, error message).
2. Analyse each error against `../_triton-context.md`. If an error
   references a symbol that does not exist, replace it with a valid one
   — do not retry the same call.
3. Make a focused edit to the instrumented file(s). Do not revert
   unrelated lines.
4. Redeploy once.

If the second deploy still fails, **stop**. Print the remaining
failures and tell the user: "Deploy is still failing after one repair
pass. Review the errors above; the bundle is left in place so you can
hand-edit before re-running the deploy command."

## Constraints

- Always call `bindToComponent('<componentName>')` before any
  `setTemplate` / `fromTemplate` / `timeBackendCall` /
  `timeUserInteraction` / `trackComponentLifecycle` /
  `startPerformanceMark` call. Unbound calls warn to `console` and emit
  nothing.
- Never invent `AREA` enum members beyond `ACCOUNTS`, `COMMUNITY`,
  `LEAD_CONVERSION`, `OPPORTUNITY_MANAGEMENT`, `REST_API`. Pass a
  string literal to `.area(...)` for anything else.
- Never change `@api` properties, dispatched events, or the component's
  public interface. Logging is additive only.
- Never add `await` to a non-async method without converting the
  method's signature. If `timeBackendCall` / `logNow` need awaiting,
  the host method must already be `async` — note any signature change
  explicitly in the diff summary.
- Never call `flush()` inside a `for` / `while` loop or reactive
  property setter. Buffer through the loop; flush in
  `disconnectedCallback` and let the 10 s auto-flush monitor cover
  in-page idle.
- Never log password fields, token values, session IDs, or full PII in
  `details`, `summary`, or via `exception()`. If detected in scope,
  leave a `// TODO: sanitize before logging` comment.
- For errors, prefer `logNow` over `log` so the entry persists before
  any subsequent state change unmounts the component. `timeBackendCall`
  / `timeUserInteraction` handle this automatically.
- Never use the removed `Triton.instance.*` accessor (Apex side
  concept) — the LWC `Triton` is a module-scope singleton accessed via
  `new Triton().bindToComponent(...)`.
- Do not duplicate an existing `Triton` import or re-bind a component
  that already has a `this.triton` property from a prior run.
- Test files (`__tests__/`, `*.test.js`) are off-limits — do not add
  Triton calls or replace `console.*` calls inside them.