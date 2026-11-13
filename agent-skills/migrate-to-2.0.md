---
name: migrate-to-2.0
summary: Convert Triton 1.x singleton code (Triton.instance) to the 2.0 static, builder-first API, surfacing the immediate-vs-buffered gotcha for human confirmation.
usage: migrate-to-2.0 <path> [--collapse-exceptions] [--collapse-dml] [--deploy]
---

# Migrate to 2.0

Mechanically convert Triton **1.x** singleton usage (`Triton.instance.*`) to the **2.0** static, builder-first API. This converts *existing* logging; it does not add new logging (that's [`instrument-apex`](instrument-apex.md)). Because one 1.x → 2.0 rename can silently change publishing behavior, this skill **stops and asks** on those calls rather than guessing.

> **Agent-agnostic skill.** Invoke it as your agent invokes skills (`/pharos:migrate-to-2.0 <path>`, an `@`-mentioned instruction, or a pasted prompt).

## Step 0 — Prerequisites

`sf`/`sfdx` and a default org only if you intend to `--deploy`; otherwise the rewrite is static. Confirm the target `<path>` exists (a single file or a directory to sweep).

### 0a — Determine the install path

How Triton reaches the org decides how org-local taxonomy is handled and in what order things deploy, so settle it first and state it in the summary:

- **Source** — Triton's own `Triton*.cls` files (`Triton.cls`, `TritonBuilder.cls`, `TritonHelper.cls`, `TritonTypes.cls`, …) are vendored into the repo.
- **Package** — they are not; Triton is installed as the `Pharos Triton` package.
- **Both signals** — Triton is vendored *and* `sfdx-project.json` lists a `Pharos Triton` package dependency: ask the user which one the org actually runs.

`--install source|package` overrides the detection.

### 0b — Both install paths

- **Confirm the branch you are sweeping actually contains every caller.** The sweep is only as complete as its `<path>` and its branch. In a promotion-pipeline repo the integration branch can sit well ahead of the default branch; a sweep run against the wrong one removes `Triton.instance` from the library while live references survive elsewhere.
- **Add `**/__tests__/**` to `.forceignore` before any deploy.** This applies to every source install, and to any repo that keeps its own LWC Jest tests. 2.0 ships four LWC modules (`triton`, `tritonBuilder`, `tritonUtils`, `logLimits`), three of which carry Jest tests under `__tests__/`. Jest tests are not deployable metadata — they rely on Jest globals and test-only module mocks — so the Step 9 `sf project deploy` can reject the bundle unless the folder is ignored. Salesforce documents this entry alongside the `**/jsconfig.json` and `**/.eslintrc.json` ones many repos already have, so it is often the only line missing. The tests stay in version control; they are just never pushed to an org. Triton's own repository already ignores them — its `.forceignore` excludes `**/__tests__/**` and `**/__mocks__/**` from 2.0.0 — but a `.forceignore` only governs the project it sits in: once `force-app` is vendored into your repo, your project's `.forceignore` is the one that applies.

### 0c — Source install

The library upgrade is part of this change: 2.0 removes `Triton.instance` entirely, so callers and library must land together or nothing compiles. Before rewriting a single caller:

- **Diff the local `TritonTypes` against the incoming 2.0 one and re-add any org-local `Area` and `Type` values.** A wholesale copy drops them and every reference fails to compile. This is the one shipped file expected to carry a local delta — see the note in Step 8. Org-local `Category` values are the exception: prefer retiring them per the severity-category note in Step 3 rather than preserving them.

### 0d — Package install

Triton installed as the `Pharos Triton` package (2.0.0-1 is version `04tg5000000GnHhAAK`):

- **Org-local `Area` and `Type` values cannot be kept.** The package replaces `TritonTypes` with its own, so any value a customer added fails the install with `Variable does not exist: <value>`. Move each one to a `public static final String` in the customer's own class (for example `AppAreas.BILLING = 'Billing'`) and rewrite `TritonTypes.Area.Billing` → `AppAreas.BILLING`. `.area(String)` and `.type(String)` accept any String on every tier, and keeping the same string keeps existing `Log_Level__mdt` rules and dashboards matching. Org-local `Category` values: retire them, as for a source install.
- **Migrate first, then install.** Only Apex classes and triggers that use removed 1.x members block the package install; a 1.x LWC or an active 1.x Flow does not. The supported path is one combined deployment of the 2.0 source plus the migrated callers, then the package install. Point the user to [Upgrading an Org from 1.x](https://triton.pharos.ai/migration/upgrading-an-org) for the full procedure rather than restating it.
- **`--deploy` against an org still on 1.x fails** — the migrated callers reference 2.0 members that org does not have. With a package install, `--deploy` first asks whether the target org already runs Triton 2.0; if it does not, skip the deploy and print the upgrade-page pointer instead.
- **A failed install lists at most six classes.** The error is capped; it is not the full set of blocking callers. This skill's sweep is the full set — trust it over the install error.

## Step 1 — Parse arguments

- **`<path>`** — required; a file or a directory. A directory sweeps four artifact types:
  - **Apex** — every `*.cls` and `*.trigger`, **including `@isTest` classes** (Steps 2–4b);
  - **LWC** — every `lwc/**/*.js`, including the project's own `__tests__/` (Step 5);
  - **Flow** — every `*.flow-meta.xml` (Step 6);
  - **`Log_Level__mdt`** — every `customMetadata/Log_Level.*.md-meta.xml` (Step 7).

  **Exclude Triton's own shipped files**: `Triton*.cls` and their tests, the `triton`, `tritonBuilder`, `tritonUtils` and `logLimits` LWC modules, and any sample `Log_Level` records Triton shipped. They are replaced wholesale by the 2.0 library (Step 0c) or the package (Step 0d), not migrated; sweeping a vendored 1.x copy produces hundreds of false hits.
- **`--tech apex,lwc,flow,mdt`** — limit the sweep to these artifact types (default: all four). Use it to stage a large migration into reviewable passes; the Step 9 checks then cover only the types swept, and the summary says which were left.
- **`--install source|package`** — override the install-path detection (Step 0a).
- **`--collapse-exceptions`** — collapse hand-assembled error logs to `.exception(e)`. **On by default**; `--no-collapse-exceptions` keeps them verbatim.
- **`--collapse-dml`** — collapse hand-built bulk-DML failure logs to `.dmlResults(results)`.
- **`--deploy`** — deploy after the diff is accepted.

## Step 2 — Find 1.x usage

Scan the Apex in scope for `Triton.instance` and any legacy patterns. For each file, list the calls to migrate. If a file has none, skip it and say so. (`@isTest` classes: migrate the logging calls too — 1.x usage in tests still won't compile against 2.0.)

**Completeness gate.** Enumerate every distinct member accessed through **any expression that holds the 1.x instance** — including property reads such as `TRANSACTION_ID` and `logs`, which are not call-shaped and are missed by a regex expecting `(`. That means:

- `Triton.instance.<member>`;
- a local variable, field or property assigned from `Triton.instance` — `Triton logger = Triton.instance;`, `private static final Triton LOG = Triton.instance;`, then `logger.<member>`, `LOG.<member>`, `this.logger.<member>` (Step 3a);
- a getter or method that returns the instance, and any parameter or return value typed `Triton` (Step 3a).

Match each against the Step 3 table **by member name *and* argument shape**. Matching on the name alone is not enough: most 1.x logging methods are overloaded, and the overloads map differently (`addError(area, e)` and `addError(area, e, relatedObjectIds)` produce different builders). **If a call's exact overload is absent from the table, stop and report it. Do not infer a mapping.**

The gate also covers 1.x members that never appear behind the instance:

- **removed static members** — `Triton.isLogAllowedForLogLevel(`, `TritonHelper.buildLogLevelKey(`, `Triton.LOG_LEVELS`, `Triton.LOG_LEVELS_MDT` (Step 3b);
- **removed category values** — `TritonTypes.Category.Warning`, `.Event`, `.Debug`, `.Integration` (compile errors in 2.0), and `TritonTypes.Category.valueOf(...)` fed a removed value. The `valueOf` form is the dangerous one: it still compiles and throws `NoSuchElementException` at runtime. Rewrite both per the severity-category note in Step 3; if the `valueOf` argument is computed rather than a literal, flag it and say which values are gone.

1.x exposes roughly two dozen logging overloads, and an immediate twin of every `add*` method (`error`, `warning`, `debug`, `event`, `dmlResult`, `integrationError`, `log`) plus `flushTop` and `withCache`. `makeBuilder` and `makePostProcessingBuilder` are already `static` in 1.x and unchanged in 2.0, so they need no migration. `isLogAllowedForLogLevel` is also `static` in 1.x, but 2.0 **removes** it — see Step 3b.

## Step 3 — Apply the method mapping

Rewrite each call using this mapping. The `.instance` drops away and positional args move onto a builder — but **the table shows the call shape, not the full field set.** The 1.x convenience methods inject fields you cannot see at the call site (`category`, `stackTrace`, `level`, `createIssue`). Open each 1.x method body in the version you are migrating *from* and carry across every field it set. Where 2.0 sets a field automatically — it captures stacktraces in `prepareForLogging` and defaults `category` to `Apex` — note that in the summary instead of restating it at the call site. Do not carry `postProcessing` across by default. Triton 2.0 sets no post-processing controls on Apex or LWC logs, so they get whatever the installed Pharos package applies by default; only the Flow invocable sets controls, and it sets the same ones at every level. The 1.x warning, debug and event methods (`addWarning`, `warning`, `addDebug`, `debug`, `addEvent`, `event`) asked for a narrower set — stack trace, user info and related objects. If the user wants exactly that back, append `.postProcessing(Triton.makePostProcessingBuilder().stackTrace(true).userInfo(true).relatedObjects(true))` to those rewritten calls and flag each one in the summary.

When a field has a dedicated builder method, use it — `.duration(d)`, `.userId(id)`, `.action(a)`, `.relatedObjects(ids)`, `.createdTimestamp(ts)`, `.spanId(id)` — never `.attribute(TritonBuilder.<FIELD>, value)`. Fall back to `.attribute(...)` only for a field with no dedicated method, and flag each one in the summary.

| Triton 1.x | Triton 2.0 |
|------------|------------|
| `Triton.instance.error(area, e)` | `Triton.logNow(Triton.t.area(area).exception(e))` |
| `Triton.instance.addError(area, e)` | `Triton.error(Triton.t.area(area).exception(e))` |
| `Triton.instance.error(area, e, relatedObjectIds)` | `Triton.logNow(Triton.t.area(area).exception(e).relatedObjects(relatedObjectIds))` |
| `Triton.instance.addError(area, e, relatedObjectIds)` | `Triton.error(Triton.t.area(area).exception(e).relatedObjects(relatedObjectIds))` |
| `Triton.instance.error(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).error())` |
| `Triton.instance.addError(type, area, summary, details)` | `Triton.error(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.warning(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).warning())` |
| `Triton.instance.addWarning(type, area, summary, details)` | `Triton.warning(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.debug(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).debug())` |
| `Triton.instance.addDebug(type, area, summary, details)` | `Triton.debug(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.debug(type, area, summary, details, duration)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).duration(duration).debug())` |
| `Triton.instance.addDebug(type, area, summary, details, duration)` | `Triton.debug(Triton.t.type(type).area(area).summary(summary).details(details).duration(duration))` |
| `Triton.instance.addEvent(level, type, area, summary, details)` | `Triton.log(Triton.t.type(type).area(area).summary(summary).details(details).level(level))` |
| `Triton.instance.addEvent(type, area, summary, details)` | `Triton.info(Triton.t.type(type).area(area).summary(summary).details(details))` |
| `Triton.instance.event(level, type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).level(level))` |
| `Triton.instance.event(type, area, summary, details)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).info())` |
| `Triton.instance.addDMLResult(area, results)` | `Triton.error(Triton.t.area(area).dmlResults(results))` — **see Step 4b** |
| `Triton.instance.dmlResult(area, results)` | `Triton.logNow(Triton.t.area(area).dmlResults(results))` — **see Step 4b** |
| `Triton.instance.addIntegrationError(area, e, request, response)` | `Triton.error(Triton.t.area(area).exception(e).integrationPayload(request, response))` § |
| `Triton.instance.integrationError(area, e, request, response)` | `Triton.logNow(Triton.t.area(area).exception(e).integrationPayload(request, response))` § |
| `Triton.instance.addIntegrationError(type, area, summary, details, request, response)` | `Triton.error(Triton.t.type(type).area(area).summary(summary).details(details).integrationPayload(request, response))` § |
| `Triton.instance.integrationError(type, area, summary, details, request, response)` | `Triton.logNow(Triton.t.type(type).area(area).summary(summary).details(details).integrationPayload(request, response).error())` § |
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

§ **Http and Rest payloads share one mapping.** Each 1.x integration-error overload exists twice, once taking `HttpRequest`/`HttpResponse` and once taking `RestRequest`/`RestResponse`. 2.0's `integrationPayload(...)` is overloaded for both pairs, so the rewrite is identical either way — pass the request/response through unchanged.

Transaction/template methods are safe renames. The **logging** methods change shape — and hide one gotcha (Step 4), plus a second that Triton 2.0.0 handles for you once the library is current (Step 4b).

## Step 3a — The instance held in a variable

1.x code often keeps the singleton in a variable rather than writing `Triton.instance` at every call:

```apex
private static final Triton LOG = Triton.instance;   // field
Triton logger = Triton.instance;                      // local
logger.addError(TritonTypes.Area.Accounts, e);
```

Every access through such a variable is a 1.x call.

- **Rewrite `<var>.<member>(…)` exactly as if it were `Triton.instance.<member>(…)`** — the same Step 3 row, the same overload matching, the same Step 4 A/B decision for bare methods, the same Step 4b rule. Then delete the declaration and assignment, which are now unused: 2.0 has no instance to hold.
- **Local variables and `private` fields or properties:** rewrite as above, in the reviewed diff.
- **The instance escapes** — it is passed as an argument, returned, stored in a non-`private` member, or a `public`/`global` method declares a `Triton` parameter or return type: **stop and report the site.** Rewriting it changes a signature, which this skill never does (Constraints). Recommend the user drop the parameter or return value in a follow-up change; 2.0 needs no instance, so every caller can log through the static API directly.
- **`withCache()` chained off a variable** (`logger.withCache().addError(...)`): split it, as the `withCache` row of the Step 3 table says.

## Step 3b — Removed log-level members

1.x exposed its `Log_Level__mdt` evaluation as static members. 2.0 moves it behind `TritonHelper.Config` and removes the old names:

| Triton 1.x | Triton 2.0 |
|------------|------------|
| `Triton.isLogAllowedForLogLevel(log)` | `TritonHelper.Config.isLogAllowed(log)` — rewrite. **Resolution changed; say so in the summary:** 1.x allowed a log if *any* matching rule permitted it, checking keys in a fixed order with case-sensitive matching; 2.0 lets the *most specific* matching rule decide (User > Component > Area > Type > Category; equally specific rules resolve to the most restrictive level), and matching is case-insensitive. With overlapping rules, 2.0 can drop a log 1.x kept. |
| `TritonHelper.buildLogLevelKey(category, type, area)` | **No public replacement** — classify each caller by purpose (below). |
| `Triton.LOG_LEVELS_MDT = x` (tests) | `TritonHelper.Config.logLevelsMdt = x` |
| `Triton.LOG_LEVELS = null` (tests) | `TritonHelper.Config.logLevels = null` — always emit the pair, `logLevelsMdt` first, then `logLevels = null`. Setting only `logLevelsMdt` after the rules were parsed has no effect. |
| `Triton.LOG_LEVELS.size()` / `.isEmpty()` | `TritonHelper.Config.logLevels.size()` / `.isEmpty()` |
| `Triton.LOG_LEVELS.get(key)` / `.containsKey(key)` / `.keySet()` / `.values()` | **No equivalent** — 2.0 holds a `List` of parsed rules, not a key map. Flag it and propose a behavioral assertion through `TritonHelper.Config.isLogAllowed(...)` instead. |

`TritonHelper.Config` is `public static`, `isLogAllowed` is `public`, and `logLevelsMdt` / `logLevels` are `@TestVisible`. Triton has no namespace, so the customer's own test classes reach them in both source and package installs.

**`buildLogLevelKey` callers.** Read each call site, decide what the key is for, and act:

- **(a) It builds a key to look up `Triton.LOG_LEVELS`** — the caller is re-implementing the level check. Replace the lookup with `TritonHelper.Config.isLogAllowed(<probe>)`, where `<probe>` is a `pharos__Log__c` carrying the same category, type and area (`pharos__Category__c`, `pharos__Type__c`, `pharos__Area__c`) plus the level being tested in `Log_Level__c`.
- **(b) It builds keys for the caller's own map, cache or comparison** — inline a `private` helper in the caller that returns `String.format('Category:{0};Type:{1};Area:{2}', new String[]{ category, type, area })`. That is the 1.x method body, so the output is identical and the caller no longer depends on Triton for it.
- **(c) A test asserts the key format or the keys in `Triton.LOG_LEVELS`** — rewrite it as a behavioral assertion: give the test its own rules (Step 3c) and assert what `TritonHelper.Config.isLogAllowed(...)` returns for a probe log.
- **The purpose is unclear** — stop and ask.

Never re-add `buildLogLevelKey` (or any removed member) to `TritonHelper`: it forks the shipped library, and a package install cannot do it at all.

## Step 3c — Tests and org log-level rules

Under `Test.isRunningTest()`, 2.0 starts with **no** log-level rules (`TritonHelper.Config.logLevelsMdt` is empty). 1.x read the org's `Log_Level__mdt` records, so a 1.x test could pass or fail depending on what was deployed.

- **Find tests that assert on log persistence or absence** — they query `pharos__Log__c` or assert on `Triton.logs` — **without** assigning `TritonHelper.Config.logLevelsMdt` themselves. Flag each:
  - it expected a log to be **dropped** by an org rule → it now fails. Rewrite it to assign its own rule with the `logLevelsMdt` / `logLevels = null` pair from Step 3b;
  - it expected a log to **persist** only because the org had a permissive rule → it now passes without testing anything about filtering. Note it in the summary.
- **1.x tests that mocked rules** (`Triton.LOG_LEVELS_MDT = …`) keep working after the Step 3b rename, unless they depended on 1.x resolution (the `isLogAllowedForLogLevel` row). Running the tests is what catches those — tell the user to run them with no `Log_Level__mdt` records in the org, as Step 9 does.

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

## Step 4b — Conditional 1.x methods: check the library, not the call site

Timing is one axis of behavior change; **whether a log is emitted at all** is the other. 1.x `addDMLResult` and `dmlResult` emitted only when a row failed. From Triton **2.0.0** the mapped form keeps that contract by itself: `dmlResults(results)` marks the builder as skipped when every row succeeded — or the list is null or empty — and `Triton.error`, `Triton.logNow`, `Triton.log` and `Triton.warning` then emit nothing: no blank record, no issue. The Step 3 rows are therefore correct as written, whether or not the call site sits behind a failure check.

What to verify is the library you are migrating **to**. A snapshot of the 2.0 source vendored before 2.0.0 has no skip, and there the same rewrite buffers a blank ERROR record and opens an issue on every successful DML. Check the vendored `TritonBuilder.cls` for an `isSuppressed()` method: if it is missing, upgrade the library to 2.0.0 or later in this change (Step 0c) rather than adding guards at each call site, and say so in the summary.

## Step 5 — LWC

Find the project's own components (Step 1 excludes Triton's) that import from `c/triton` or `c/tritonBuilder`, and check each against this table. 2.0's JavaScript API keeps the 1.x method names, so most components need nothing; what changed is a few constants and one promise contract.

| 1.x pattern | Handling |
|-------------|----------|
| `.category(CATEGORY.WARNING)`, `.category(CATEGORY.DEBUG)`, `.category(CATEGORY.EVENT)`, or a literal `'Warning'`, `'Debug'`, `'Event'` or `'Integration'` passed to `.category(...)` | **Rewrite:** remove the `.category(...)` call. `makeBuilder()` and the level helpers (`error()`, `warning()`, `debug()`, `info()`, `exception()`) already stamp `LWC`. If the chain does not start from a Triton factory — a bare `new TritonBuilder()` — replace the argument with `CATEGORY.LWC` instead (importing `CATEGORY` if needed). Why it is safe: in 2.0 these keys are `undefined`, and the server already re-categorises such logs to `LWC` with an "Invalid Log Category" note in Details, so the rewrite only removes the note. **Do not add a level:** 1.x recorded these logs at whatever level the chain set (INFO if none), and so does the rewrite. List each site in the summary and suggest `.level(LEVEL.WARNING)` / `.level(LEVEL.DEBUG)` where the old category was really expressing severity. |
| An `AREA.*` constant compared to or switched on against a string (`AREA.ACCOUNTS === 'ACCOUNTS'`), used as a map key, sent to the project's own Apex, or stored | **Flag, never auto-apply.** 2.0 changed the values: `'Accounts'`, `'Community'`, `'LeadConversion'`, `'OpportunityManagement'`, `'RestAPI'` (1.x: `'ACCOUNTS'`, `'COMMUNITY'`, `'LEAD_CONVERSION'`, `'OPPORTUNITY_MANAGEMENT'`, `'REST_API'`). Propose the fix — compare against the constant itself, or against the new value — but the comparison is program logic, so each site needs its own `yes`. Passing `AREA.*` to `.area(...)` needs nothing: the server maps any casing or underscore form. |
| `.catch(...)` on, or `try … catch` around, `flush()` or `logNow()` | **Flag, never auto-remove.** It is dead code: 2.0's `flush()` and `logNow()` never reject — a failed flush re-buffers the logs and drops them after `MAX_FLUSH_ATTEMPTS` failures. Recommend removing a handler that only handles a logging failure; keep one that also guards other awaited work in the same chain. |
| Profiling calls — `timeBackendCall`, `timeUserInteraction`, `startPerformanceMark` / `endPerformanceMark`, `trackComponentLifecycle`, `trackComponentRender` | **No code change.** List them for Step 7: 2.0 records them at FINE, FINER or FINEST (failures at ERROR), where 1.x used INFO, so existing `Log_Level__mdt` rules may now drop them. |
| `exception()` on the JavaScript builder | No change. Note in the summary that it now also sets ERROR. |

## Step 6 — Flow XML

Find every Triton Log action: an `<actionCalls>` element with `<actionName>TritonFlow</actionName>` and `<actionType>apex</actionType>`.

- **`category` input set to a literal `Warning`, `Debug`, `Event` or `Integration`** (`<stringValue>`) → **rewrite:** remove that `<inputParameters>` element. The invocable then defaults to `Flow`. 2.0 already does this at runtime and appends an "Unable to locate category" note to Details; the rewrite only removes the note. As in Step 5, do not add a `level`; if the action has no `level` input, suggest `WARNING` or `DEBUG` in the summary where the category was expressing severity.
- **`category` input from an `<elementReference>` or a formula** → **flag.** The value is computed, so it cannot be rewritten statically. Tell the user which values 2.0 removed, so they can fix whatever feeds it.
- **`flowApiName` with a version suffix** (`My_Flow-3`) → **flag**, no edit. 2.0 matches `Component_Name__c` log-level rules on the plain API name and takes the version in the new optional `flowVersion` input. This is not a 1.x break, only a rule-matching improvement the user may want.
- Note in the summary: deploying a changed `.flow-meta.xml` whose `<status>` is `Active` creates and activates a new flow version.

## Step 7 — `Log_Level__mdt` records

Read every `customMetadata/Log_Level.*.md-meta.xml` in scope: `Category__c`, `Type__c`, `Area__c`, `Level__c`, and 2.0's `Component_Name__c` and `User_Id__c`. These rules decide **which logs the org keeps**, so only one shape is ever rewritten automatically; every other finding is flagged with a recommended option and needs the user's decision.

| Rule shape | Handling |
|------------|----------|
| `Category__c` is `Warning`, `Debug`, `Event` or `Integration` | **Flag.** In 2.0 it matches nothing — the field is free text, so there is no error; the rule just goes inert. The logs it governed now land as `Apex` (from the Apex helpers), `Flow` or `LWC`. Offer two options: **delete** it (recommended when it only existed to raise or lower one severity, which 2.0 expresses through Level), or **re-key** it to the producing category *narrowed* by `Type__c` or `Area__c` — for example, integration logs → `Category__c = Apex` plus the integration `Area__c`. Never re-key to a bare category: `Category__c = Apex, Level__c = ERROR` drops every Apex INFO log in the org. |
| `Area__c` is a 1.x LWC area value — `ACCOUNTS`, `COMMUNITY`, `LEAD_CONVERSION`, `OPPORTUNITY_MANAGEMENT`, `REST_API` | **Rewrite** to the 2.0 value: `Accounts`, `Community`, `LeadConversion`, `OpportunityManagement`, `RestAPI`. Rule matching is case-insensitive but not underscore-insensitive, so `LEAD_CONVERSION` would no longer match. This is the only rule edit this skill applies automatically. |
| `Area__c` is `LWC` | **Flag.** 1.x filed every LWC log whose area was not an Apex `Area` name under `LWC`; 2.0 keeps the real area, so this rule now covers far fewer logs. Ask whether to re-key it (to `Category__c = LWC`, or to the real areas) or keep it. |
| A rule that targets LWC logs — `Category__c = LWC` or blank — with `Level__c` of ERROR, WARNING, INFO or DEBUG, when Step 5 found profiling calls | **Flag.** It now drops the profiling records that 1.x kept at INFO. Ask: keep dropping them (recommended in production — the volume is high), or add a narrower rule at FINE, FINER or FINEST (`Category__c = LWC`, `Type__c = BackendCall`, `UserInteraction`, `ComponentLifecycle`, `ComponentRender` or `Performance`, optionally `Component_Name__c`). |
| Any rule, where several rules overlap | Note the resolution change from Step 3b: the most specific matching rule now decides, so an overlap that 1.x resolved permissively can now drop logs. |

Record every rule deleted, re-keyed or kept for the summary.

## Step 8 — Audit flush coverage & collapse

- **Flush coverage.** Now that level methods buffer, flag every path that logs but has no `Triton.flush()` at its boundary/`finally`. Report these alongside the diff (fixing them may require a boundary flush — propose it).
- **`--collapse-exceptions`.** Replace hand-set error fields (`.type(...).summary(e.getMessage()).details(e.getStackTraceString())`) with a single `.exception(e)` (which also sets ERROR level and issue creation). Put any custom `.summary(...)` **after** `.exception(e)`.
- **`--collapse-dml`.** Replace hand-built DML failure summaries with `.dmlResults(results)`.
- **Ad-hoc taxonomy.** Flag `.area('X')` / `.type('X')` string literals; suggest promoting them to `public static final String` constants rather than adding new values to the shipped `TritonTypes` enums — see the Custom Classifications guidance in the docs. How this meets *existing* org-local values depends on the install path:
  - **Source install** — this is about *adding* classifications. It does not mean an existing org-local `Area` or `Type` value may be dropped when re-vendoring the library: preserve those (Step 0c), and promote only *new* ones to String constants.
  - **Package install** — every org-local `Area` and `Type` value becomes a String constant, because the package's `TritonTypes` cannot carry them (Step 0d).

## Step 9 — Verify, review, write, deploy

**Verify before presenting.** These checks are greppable and catch the failure modes a human reviewer reading a diff will not. Each requires **zero** matches in scope, with Triton's own shipped files excluded (Step 1); with `--tech`, run only the checks for the types swept.

1. **Apex: no 1.x member survives.** Zero matches for `Triton.instance`; for any `Triton`-typed variable, field or property assigned from it; for `isLogAllowedForLogLevel`, `buildLogLevelKey` and `Triton.LOG_LEVELS` (which also catches `LOG_LEVELS_MDT`); for `TritonTypes.Category.Warning`, `.Event`, `.Debug` and `.Integration`; and zero static calls to methods 2.0 does not have (`Triton.addError(`, `Triton.addEvent(`, `Triton.dmlResult(` and friends — a half-migrated call that merely dropped `.instance` compiles under neither version). Escaping instances reported under Step 3a are the only allowed survivors, and each is listed in the summary.
2. **LWC: no removed category.** Zero `CATEGORY.WARNING`, `CATEGORY.DEBUG` or `CATEGORY.EVENT`, and no literal `'Warning'`, `'Debug'`, `'Event'` or `'Integration'` passed to `.category(...)`.
3. **Flow: no removed category literal.** No TritonFlow `category` input whose `<stringValue>` is `Warning`, `Debug`, `Event` or `Integration`.
4. **`Log_Level__mdt`: no removed category.** No `Category__c` of `Warning`, `Debug`, `Event` or `Integration` — unless the user chose to keep that rule, which the summary records.
5. **Every enum reference resolves.** Each `TritonTypes.<enum>.<value>` in scope must exist in the post-migration `TritonTypes`. This is the check that catches both a vendored-library overwrite dropping org-local values and a mapping that emits a retired value such as `Category.Event`. For a package install, the post-migration `TritonTypes` is the shipped one, so there must be zero references to org-local values.

**Run the project's tests with no `Log_Level__mdt` records in the org.** 2.0 tests start with no rules (Step 3c), so this shows whether any test relied on the org's rules — and whether a test that mocks rules depended on 1.x resolution (Step 3b).

**Re-run check 1 immediately before merge, not just before presenting the diff.** Because 2.0 removes `Triton.instance`, the library and every caller have to land together — so on an active integration branch a caller that merges *after* your sweep but *before* yours lands leaves the branch with the 2.0 library and live 1.x references, which does not compile. The window is the review period, and it is easy to lose: verifying at sweep time proves nothing about merge time.

For anything beyond a one-off, recommend a CI check rather than a habit: the `setup-standards` skill adds one that fails the build on any `Triton.instance`, so a late 1.x caller breaks its own pull request instead of the branch.

Then present a summary, then the diff, with `yes` / `modify` / `skip`. The summary covers:

- the install path (Step 0a) and, with `--tech`, which artifact types were left for a later pass;
- per-type counts — Apex calls migrated, LWC sites rewritten, Flow actions rewritten, `Log_Level__mdt` rules changed;
- bare-method decisions (A/B) taken, the Step 4b library-version check, collapses applied, flush gaps found, any `.attribute(...)` fallbacks;
- every flagged item and the decision taken — escaping instances, `buildLogLevelKey` purposes, `LOG_LEVELS` reads, tests that relied on org rules, LWC `AREA` comparisons and `.catch` handlers, computed Flow categories and versioned `flowApiName` values;
- `Log_Level__mdt` rules deleted, re-keyed or kept, and the resolution-change note (Step 3b) where rules overlap;
- whether a `setup-standards` CI check is in place, and any `Category` reporting change implied by the severity-category note.

On `yes`, write back to the original file.

**Deploy** with `--deploy` (or on confirmation):

- **Source install** — `sf project deploy start --source-dir <path> --json` (or the `sfdx` equivalent), with the 2.0 library and the migrated callers in the same deployment.
- **Package install** — first ask whether the target org already runs Triton 2.0. If it does, deploy as above. If it does not, do **not** deploy: the migrated callers do not compile against 1.x. Print the pointer to [Upgrading an Org from 1.x](https://triton.pharos.ai/migration/upgrading-an-org) instead (Step 0d).

> After deploying 2.0, remind the user to re-assign the `Triton_Read` / `Triton_Write` permission sets so the new fields are visible.

## Constraints

- Never auto-convert a bare-method call — always present the immediate (`logNow`) vs. buffer (+flush) choice.
- Rely on the `dmlResults` rows only when the target library is Triton 2.0.0 or later (Step 4b); otherwise upgrade the library in the same change.
- Stop and report any `Triton.instance` member *or overload* that is not in the Step 3 table rather than inferring a mapping — and any instance that escapes through a signature (Step 3a).
- Never change program behavior beyond the logging call itself; preserve control flow, throws, signatures.
- Never auto-edit a `Log_Level__mdt` rule, except renaming a 1.x LWC area value (Step 7). Never auto-edit an LWC `AREA` comparison, and never remove a `.catch` or `try … catch` around `flush()` / `logNow()` (Step 5).
- Never re-add a removed 1.x member (`buildLogLevelKey`, `isLogAllowedForLogLevel`, `LOG_LEVELS`, …) to the library.
- Do not add new values to the shipped `TritonTypes` enums; route new org-specific values to `String` constants. On a **source install**, preserve existing org-local `Area` and `Type` values when re-vendoring the library (Step 0c). On a **package install**, move them all to `String` constants (Step 0d).
- Report (don't silently invent) flush gaps introduced by the buffering default.
- Idempotent across all four artifact types: a file with no 1.x usage — Apex, LWC, Flow or `Log_Level__mdt` — is left untouched, and a second run over migrated output changes nothing.
