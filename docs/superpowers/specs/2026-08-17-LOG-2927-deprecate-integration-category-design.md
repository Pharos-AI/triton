# LOG-2927 — Deprecate the Integration log Category (fold into Apex)

- **Ticket:** https://goldenratio.atlassian.net/browse/LOG-2927
- **Base branch:** `origin/release/2.0` (branch `feature/LOG-2927`)
- **Scope:** triton repo only. The Logger-side change is already implemented, reviewed, and pushed (https://github.com/grsys/Logger/pull/3416): post-processing payload preservation is now payload-triggered (request+response shape detection), so Apex-category logs carrying integration payloads keep their payloads. The legacy Integration branch is retained in Logger for old producers.

## ⚠️ RELEASE-ORDERING CONSTRAINT (read first)

**The Logger release containing PR #3416 must reach subscriber orgs NO LATER than the Triton release containing this change.** On older Logger versions, post-processing payload preservation still keys on `Category = 'Integration'`; Apex-category logs with integration payloads would **lose their payloads in post-processing**. Do not ship this Triton change to a subscriber population ahead of that Logger release.

## Summary of change

The `Integration` log Category is deprecated product-wide. Integration (callout/REST) logs become **Apex-category logs that carry an integration payload** via `integrationPayload(req, res)`. This change:

1. **Removes** the `TritonTypes.Category.Integration` enum member (accepted breaking change — see below).
2. **Keeps** the payload mechanism unchanged: `TritonBuilder.integrationPayload(HttpRequest, HttpResponse)` and `(RestRequest, RestResponse)` (TritonBuilder.cls:477, 488) and `TritonHelper.toJson`/`IntegrationWrapper` (TritonHelper.cls:286–315) are category-agnostic and remain the ongoing mechanism.
3. **Updates** skill guidance (`agent-skills/instrument-apex.md`) — the highest-value change, since that skill is what generates new Integration-category logs in customer orgs.
4. **Maps** the `'Integration'` category string in the Flow/LWC bridges to the emission context's own category (Flow → `Flow`, LWC → `LWC`), case-insensitively, without the invalid-category details note — sanctioned deprecation mapping, not bad input.
5. **Rewrites** tests so integration-payload behavior keeps full coverage on Apex-category logs, plus new tests for the bridge mapping.

## Breaking-change statement

**What breaks:** Triton is source-distributed. Any customer Apex referencing `TritonTypes.Category.Integration` fails to compile when they take this version.

**Migration note (for release notes / changelog):** replace explicit `.category(TritonTypes.Category.Integration)` with no category call at all — the builder defaults to `Apex` (TritonBuilder.cls:810–815) — and attach the HTTP payload with `.integrationPayload(req, res)`. Example:

```apex
// Before
Triton.logNow(Triton.makeBuilder()
    .category(TritonTypes.Category.Integration)
    .type(TritonTypes.Type.BackendCall)
    .area(...).summary(...).integrationPayload(req, res).error());

// After
Triton.logNow(Triton.makeBuilder()
    .type(TritonTypes.Type.BackendCall)
    .area(...).summary(...).integrationPayload(req, res).error());
```

**Accepted behavior changes (state, don't fight):**

- Former Integration-category logs now get **`apexExecutionContext` captured**: `TritonBuilder.prepareForLogging()` gates context capture on `Category == Apex` (TritonBuilder.cls:794–797), which these logs now satisfy.

**Sanctioned `'Integration'` string mapping in the bridges (decision from Nikita):** the string `'Integration'` remains an **accepted** input, overridden by the emission context's own category — Flow bridge → `Flow`, LWC bridge → `LWC`, Apex → `Apex`. It must NOT take the invalid-category path: no "Invalid Log Category"/"Unable to locate category" note is appended to details — this is sanctioned deprecation mapping, not bad input. Matching is **case-insensitive** (`'integration'` too, consistent with the case-insensitive matching philosophy adopted on LOG-2921). We also add **no** "deprecated category mapped to …" breadcrumb in details: the mapping is documented product-wide, details stay clean, and the invalid-category note remains reserved for genuinely bad input. The Apex context needs no code: `Category.Integration` no longer compiles after enum removal, and the builder default (`Apex`, TritonBuilder.cls:810–815) already applies when no category is set.

## Exact file/line changes

All line numbers are against `origin/release/2.0` (998079f).

### 1. `force-app/main/default/classes/TritonTypes.cls`
- **:54** — remove the `Integration` enum member (last in the `Category` list; also remove the trailing comma on `Debug`, line 53).
- **:15** — class doc comment `(e.g., Apex, Flow, Integration)` → `(e.g., Apex, Flow, LWC)`.

### 2. `agent-skills/instrument-apex.md`
- **:40** — `(For callouts, classify as `Category.Integration` + a call type such as `BackendCall`.)` → callouts keep the default `Apex` category; classify with a call type such as `BackendCall` and always attach `.integrationPayload(req, res)`.
- **:204** — "Attach the HTTP payload with `integrationPayload(req, res)` and classify as `Category.Integration` + `Type.BackendCall`" → "…keep the default `Apex` category and classify as `Type.BackendCall`".
- **:213, :225** — delete the `.category(TritonTypes.Category.Integration)` lines from both code examples (success-path status check and catch block).
- **:366** — "Category should stay standard (`Apex`, or `Integration` for callouts)." → "Category should stay standard (`Apex` — including callouts, which are distinguished by `integrationPayload` + a call type, not by category)."
- (`:63` mentions `integrationPayload` only — no category reference, unchanged.)

### 3. `agent-skills/migrate-to-2.0.md`
- **:43** — the mapping target for `addIntegrationError` **already** reads `Triton.error(Triton.t.area(area).exception(e).integrationPayload(request, response))` — i.e. default Apex category. No mapping change needed. **Add a short note** (below the table or as a table footnote): the legacy call wrote `Category = 'Integration'`; the 2.0 form intentionally lands as `Apex` — the Integration category is deprecated, and payload preservation is triggered by the payload itself.

### 4. `force-app/main/default/classes/TritonHelper.cls`
- **:423** — `PostProcessingControlsBuilder.stackTrace` doc comment "Only applicable to Apex and Integration logs" → "Only applicable to Apex logs". (No code change; `toJson`/`IntegrationWrapper` at :286–315 are kept as-is.)

### 5. `force-app/main/default/classes/TritonFlow.cls` — sanctioned `'Integration'` mapping
- **:86–93** — in the category-resolution block, before `Category.valueOf(...)`: if `'Integration'.equalsIgnoreCase(flowLog.category)`, keep the context default (`Category.Flow`) and **skip** both `valueOf` and the `INVALID_CATEGORY` details note (a one-line comment marks it as deprecation mapping). All other unknown strings keep the existing invalid-category path unchanged.

### 6. `force-app/main/default/classes/TritonLwc.cls` — sanctioned `'Integration'` mapping
- **:81–86** — same guard: if `'Integration'.equalsIgnoreCase(componentLog.category)`, keep the context default (`Category.LWC`), skip `valueOf` and the "Invalid Log Category" details note. All other unknown strings unchanged.

### 7. `force-app/main/default/classes/TritonTest.cls` — test rewrite plan

Principle: every scenario that exercised the integration-payload pipeline keeps full coverage, now asserting **Apex category + populated `pharos__Stacktrace_Parse_Result__c`** instead of `Category = 'Integration'`. Test *method* names are kept (they describe integration-payload scenarios, still accurate); only the helper is renamed for honesty.

| Location | Current | Change |
|---|---|---|
| :14–23 `assertCreatedIntegrationLog()` | asserts both logs have `Category = Integration` | rename to `assertCreatedIntegrationPayloadLogs()`; assert `Category = Apex` **and** `pharos__Stacktrace_Parse_Result__c != null` for both logs (add the field to the SOQL); keep the 2-log count and hash assertions |
| :643–661 `test_sync_integration_from_exception` | calls the helper | update helper call site only |
| :663–681 `test_integration_error_sync` | builder uses `.category(Category.Integration)` | drop the `.category(...)` call; add assertions `Category = Apex` and payload non-null (add fields to the SOQL at :677) |
| :995–1007 (builder attribute test) | `integrationPayload` round-trip assertions | **unchanged** — category-agnostic |
| :1121–1138 `testHttpRequest()` helper | both `logNow` builders use `.category(Category.Integration)` | drop both `.category(...)` calls |
| :1795–1869 `test_event_and_integration_error_variations` | two builders use `.category(Category.Integration)`; assertion loop at :1863–1868 keys on `Category == 'Integration'` | drop both `.category(...)` calls; rewrite the loop to assert exactly 2 of the 3 logs are `Category = Apex` with non-null `pharos__Stacktrace_Parse_Result__c` (the Event log has none) |
| :2380–2388 `test_default_category_not_overridden` | uses `Category.Integration` as the explicit non-default category | substitute `Category.Event` — preserves the "explicit category is not overridden by the Apex default" coverage |
| :2398–2419 `test_builder_clone` | clones a builder with `Category.Integration`; asserts it at :2411 | substitute `Category.Event` in both places — preserves clone-preserves-category coverage |

**New tests for the sanctioned bridge mapping:**

- `TritonFlowTest.cls` — new test `test_flow_integration_category_maps_to_flow`, placed after `test_flow_wrong_category` (:157–178): invoke `TritonFlow.log` with `category = 'Integration'` and a second log with `category = 'integration'` (case-insensitivity); assert both logs get `Category = Flow` and details do **not** contain `'Unable to locate category'`. (Existing `test_flow_wrong_category` and the invalid-category branch of `test_flow` (:54–65, :82) stay green unchanged — they use `'InvalidCategory'`.)
- `TritonTest.cls` — new test `test_save_component_log_integration_category_maps_to_lwc`, placed near the existing LWC-bridge tests (~:683–910): submit a `TritonLwc.ComponentLog` with `category = 'Integration'` (plus a case-variant log); assert `Category = LWC` and details do **not** contain `'Invalid Log Category'`. (Existing invalid-category assertion at :899 uses `'test category'`-style bad input and stays unchanged.)

No changes to `TritonTestFactory`, `Triton.cls`, `TritonBuilder.cls`, or any LWC (zero JS references to Integration).

## Merge-conflict notes vs PR #48 (feature/LOG-2921, not yet in base)

PR #48 modified `TritonHelper.cls`, `TritonBuilder.cls`, `TritonFlow.cls`, `TritonTest.cls`, `TritonFlowTest.cls`, `agent-skills/instrument-flows.md`. Expected interaction:

- **TritonTest.cls** — PR #48 is a single ~380-line insertion hunk at old lines ~572–583. LOG-2927 edits lines 14–23, 644–681, 1121–1138, 1795–1869, 2380–2419 — no overlapping hunks; git should auto-merge. This is still the file to watch: whichever PR merges second should re-run the suite, since PR #48's added tests build logs via `makeBuilder()` and could theoretically reference the removed enum (spot-check on merge; its diff predates LOG-2927).
- **TritonHelper.cls** — PR #48's hunks all start at line 689+; LOG-2927 touches only the :423 doc comment. No conflict.
- **TritonFlow.cls** — **expected conflict point.** PR #48 has a hunk at old lines ~92–97 (`@@ -92,6 +93,15 @@`), directly adjacent to LOG-2927's guard insertion in the category block at :86–93 — overlapping context makes a small textual conflict likely. Resolution is trivial: both edits are additive within the same resolution block (LOG-2927's `'Integration'` guard before `valueOf`, PR #48's insertion after it).
- **TritonFlowTest.cls** — PR #48 is a single insertion at old line ~85; LOG-2927 adds a new test after :178. No overlap expected.
- **TritonLwc.cls** — untouched by PR #48. No conflict.
- **TritonBuilder.cls** — LOG-2927 makes **no changes**. No conflict.
- **agent-skills** — PR #48 touches `instrument-flows.md` only; LOG-2927 touches `instrument-apex.md` + `migrate-to-2.0.md`. No conflict.
- **docs/superpowers/** — both PRs add distinct new files. No conflict.

## Verification plan

1. **TDD order:** first rewrite the tests (they fail to compile against the removed enum, or fail asserting Apex category while Integration is still emitted), then remove the enum member and watch them pass.
2. Deploy each increment to **qa42** via the hub-provisioned wrapper (`.claude/ship-org.sh deploy`, invoked by absolute path from the worktree).
3. Focused loop: `test TritonTest` and `test TritonFlowTest` after the test rewrite + enum removal + bridge guards.
4. Before DONE: **full Apex suite** on qa42 via the wrapper. Known non-blocking: the org-resident stale `LogTest` failure documented for this org.
5. `npm test` (Jest) as a cheap sanity pass — no LWC files change, expected green.
6. No feature-param toggles are needed for this change; nothing to restore.

## Out of scope

- Any Logger-side work (already shipped via PR #3416).
- Removing `integrationPayload` / `toJson` / `IntegrationWrapper` — these are the ongoing mechanism and are kept.

## Resolved decisions (from Nikita, via hub)

1. **migrate-to-2.0.md:43** — confirmed note-only: the mapping already targets default-Apex + `integrationPayload`; add the explanatory note, no mapping change.
2. **`'Integration'` string in the bridges** — accepted input, overridden by the emission context's own category: Flow → `Flow`, LWC → `LWC`, Apex → `Apex` (covered by enum removal + builder default). Case-insensitive. Not the invalid-category path — no "Invalid Log Category" note. (Breadcrumb note in details was left to implementer discretion; decision: none — see the sanctioned-mapping section.)
3. **`Category.Event`** confirmed as the substitute explicit category in `test_default_category_not_overridden` and `test_builder_clone`.

## Open questions

None.
