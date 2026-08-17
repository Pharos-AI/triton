# LOG-2927 — Deprecate Integration Category Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the `TritonTypes.Category.Integration` enum member and fold integration logging into the Apex category (payload via `integrationPayload`), with sanctioned context-mapping of the `'Integration'` string in the Flow/LWC bridges.

**Architecture:** Three small, independent surfaces: (1) bridge guards in `TritonFlow`/`TritonLwc` that accept the deprecated `'Integration'` string case-insensitively and keep the context default category without the invalid-category note; (2) test rewrites in `TritonTest` so integration-payload coverage asserts Apex category + populated `pharos__Stacktrace_Parse_Result__c`; (3) the enum removal plus doc-comment and skill-guidance updates. The payload mechanism (`integrationPayload`, `TritonHelper.toJson`, `IntegrationWrapper`) is untouched.

**Tech Stack:** Salesforce Apex (no namespace, depends on managed package `Pharos@2.275.0.3`), qa42 persistent org via `/Users/glyuk/dev/triton/.claude/ship-org.sh` wrapper only, Jest for LWC (unaffected — sanity run only).

**Spec:** `docs/superpowers/specs/2026-08-17-LOG-2927-deprecate-integration-category-design.md`

## Global Constraints

- Base branch `origin/release/2.0`; work happens in worktree `/Users/glyuk/dev/triton-wt-LOG-2927` on branch `feature/LOG-2927`. Never push, never create PRs; commit locally only.
- Org access ONLY via `/Users/glyuk/dev/triton/.claude/ship-org.sh` (absolute path; works from the worktree): `deploy`, `test <ClassName>`, `test` (full), `status`. Direct `sf` denied.
- Keep the diff surgically minimal in `TritonTest.cls`, `TritonHelper.cls`, `TritonFlow.cls` to minimize conflicts with PR #48 (feature/LOG-2921, not yet in base).
- RELEASE-ORDERING (informational, no code impact here): Logger PR #3416 must reach subscribers no later than this Triton change.
- Known non-blocking full-suite failure on qa42: org-resident stale `LogTest.test_save_component_log`.
- `integrationPayload` / `TritonHelper.toJson` / `IntegrationWrapper` are KEPT — do not touch TritonBuilder.cls.
- No `Co-Authored-By` trailers in commit messages.

---

### Task 1: Flow bridge — sanctioned `'Integration'` → Flow mapping

**Files:**
- Modify: `force-app/main/default/classes/TritonFlow.cls:86-93`
- Test: `force-app/main/default/classes/TritonFlowTest.cls` (new test after `test_flow_wrong_category`, ends line 174)

**Interfaces:**
- Consumes: `TritonTestFactory.makeFlowLog(String)`, `.resetFlowState()`, `.flushCachedFlowLogs()`, `.queryLogs()` (selects `pharos__Category__c`, `pharos__Details__c`), `TritonFlow.log(List<TritonFlow.FlowLog>)`.
- Produces: `TritonFlow` resolves category `'Integration'`/`'integration'` to `TritonTypes.Category.Flow` with no `INVALID_CATEGORY` note in details. Behavior for all other category strings unchanged.

- [ ] **Step 1: Write the failing test**

Insert into `TritonFlowTest.cls` immediately after the closing brace of `test_flow_wrong_category` (line 174), before the `test_flow_create_issue` doc comment:

```apex
    /**
     * Deprecated 'Integration' category is a sanctioned input (LOG-2927):
     * mapped case-insensitively to the Flow context category,
     * without the invalid-category note.
     */
    @IsTest
    private static void test_flow_integration_category_maps_to_flow() {
        TritonTestFactory.assertNoLogs();
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('integration exact case');
        flowLog.category = 'Integration';
        TritonFlow.FlowLog flowLogLowercase = TritonTestFactory.makeFlowLog('integration lower case');
        flowLogLowercase.category = 'integration';
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog, flowLogLowercase });
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
        System.assertEquals(2, logs.size(), 'Expected both flow logs to be created');
        for (pharos__Log__c log : logs) {
            System.assertEquals(TritonTypes.Category.Flow.name(), log.pharos__Category__c,
                'Deprecated Integration category should map to Flow, but was: ' + log.pharos__Category__c);
            System.assert(log.pharos__Details__c == null || !log.pharos__Details__c.contains('Unable to locate category'),
                'Sanctioned Integration mapping must not append the invalid-category note');
        }
    }
```

- [ ] **Step 2: Deploy and run test to verify it fails**

Run: `/Users/glyuk/dev/triton/.claude/ship-org.sh deploy` then `/Users/glyuk/dev/triton/.claude/ship-org.sh test TritonFlowTest`
Expected: `test_flow_integration_category_maps_to_flow` FAILS — the `'Integration'` log resolves via `Category.valueOf` to `Integration` (enum member still exists at this point), and the `'integration'` log takes the invalid path and appends the note. All other TritonFlowTest tests PASS.

- [ ] **Step 3: Implement the guard in TritonFlow.cls**

Replace lines 86–93 (`TritonTypes.Category category = ...` through the closing `}` of its catch):

```apex
        TritonTypes.Category category = TritonTypes.Category.Flow;
        // LOG-2927: deprecated 'Integration' category is accepted and maps to the context default (Flow)
        if (!'Integration'.equalsIgnoreCase(flowLog.category)) {
            try {
                category = TritonTypes.Category.valueOf(flowLog.category);
            } catch (Exception e) {
                if(String.isNotBlank(flowLog.category)) {
                    flowDetails += Triton.SPACE_SEP + TritonHelper.formatMessage(INVALID_CATEGORY, flowLog.category);
                }
            }
        }
```

(Note: `'Integration'.equalsIgnoreCase(null)` is `false`, so null/blank categories keep their existing path.)

- [ ] **Step 4: Deploy and run test to verify it passes**

Run: `/Users/glyuk/dev/triton/.claude/ship-org.sh deploy` then `/Users/glyuk/dev/triton/.claude/ship-org.sh test TritonFlowTest`
Expected: ALL TritonFlowTest tests PASS (including existing `test_flow_wrong_category` and the invalid-category branch of `test_flow`, which use `'InvalidCategory'`).

- [ ] **Step 5: Commit**

```bash
cd /Users/glyuk/dev/triton-wt-LOG-2927
git add force-app/main/default/classes/TritonFlow.cls force-app/main/default/classes/TritonFlowTest.cls
git commit -m "LOG-2927: Flow bridge maps deprecated 'Integration' category to Flow (case-insensitive, no invalid-category note)"
```

---

### Task 2: LWC bridge — sanctioned `'Integration'` → LWC mapping

**Files:**
- Modify: `force-app/main/default/classes/TritonLwc.cls:81-86`
- Test: `force-app/main/default/classes/TritonTest.cls` (new test after `test_save_component_log`, ends line 714)

**Interfaces:**
- Consumes: `TritonLwc.ComponentLog` / `TritonLwc.Component` shapes, `TritonLwc.saveComponentLogs(List<ComponentLog>)`, `TritonTestFactory.assertNoLogs()`.
- Produces: `TritonLwc` resolves category `'Integration'`/`'integration'` to `TritonTypes.Category.LWC` with no "Invalid Log Category" note in details. All other category strings unchanged.

- [ ] **Step 1: Write the failing test**

Insert into `TritonTest.cls` immediately after the closing brace of `test_save_component_log` (line 714), before `test_lwc_runtime_info`:

```apex
    /**
     * Deprecated 'Integration' category is a sanctioned input (LOG-2927):
     * mapped case-insensitively to the LWC context category,
     * without the invalid-category note.
     */
    @IsTest
    private static void test_save_component_log_integration_category_maps_to_lwc() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        List<TritonLwc.ComponentLog> componentLogs = new List<TritonLwc.ComponentLog>();
        for (String categoryValue : new List<String>{'Integration', 'integration'}) {
            TritonLwc.ComponentLog componentLog = new TritonLwc.ComponentLog();
            componentLog.category = categoryValue;
            componentLog.type = 'test type';
            componentLog.area = TritonTypes.Area.LWC.name();
            componentLog.level = TritonTypes.Level.ERROR.name();
            componentLog.summary = 'integration category mapping: ' + categoryValue;
            componentLog.details = 'test details';
            TritonLwc.Component component = new TritonLwc.Component();
            component.name = 'TestComponent';
            component.function = 'testFunction';
            componentLog.componentInfo = component;
            componentLogs.add(componentLog);
        }
        TritonLwc.saveComponentLogs(componentLogs);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Category__c, pharos__Details__c FROM pharos__Log__c];
        System.assertEquals(2, logs.size(), 'Expected both component logs to be created');
        for (pharos__Log__c log : logs) {
            System.assertEquals(TritonTypes.Category.LWC.name(), log.pharos__Category__c,
                'Deprecated Integration category should map to LWC, but was: ' + log.pharos__Category__c);
            System.assert(log.pharos__Details__c == null || !log.pharos__Details__c.contains('Invalid Log Category'),
                'Sanctioned Integration mapping must not append the invalid-category note');
        }
    }
```

- [ ] **Step 2: Deploy and run test to verify it fails**

Run: `/Users/glyuk/dev/triton/.claude/ship-org.sh deploy` then `/Users/glyuk/dev/triton/.claude/ship-org.sh test TritonTest`
Expected: `test_save_component_log_integration_category_maps_to_lwc` FAILS (`'Integration'` resolves to the still-present enum member; `'integration'` takes the invalid path and appends the note). Other TritonTest tests PASS.

- [ ] **Step 3: Implement the guard in TritonLwc.cls**

Replace lines 81–86 (the `try { category = ... }` block):

```apex
            // LOG-2927: deprecated 'Integration' category is accepted and maps to the context default (LWC)
            if (!'Integration'.equalsIgnoreCase(componentLog.category)) {
                try {
                    category = TritonTypes.Category.valueOf(componentLog.category);
                } catch(Exception e) {
                    //invalid category
                    details += Triton.SPACE_SEP + TritonHelper.formatMessage('Invalid Log Category: {0}. Default LWC category will be used.', componentLog.category);
                }
            }
```

- [ ] **Step 4: Deploy and run test to verify it passes**

Run: `/Users/glyuk/dev/triton/.claude/ship-org.sh deploy` then `/Users/glyuk/dev/triton/.claude/ship-org.sh test TritonTest`
Expected: new test PASSES; the existing invalid-category assertion (TritonTest:899, uses a non-Integration bad string) still PASSES.

- [ ] **Step 5: Commit**

```bash
cd /Users/glyuk/dev/triton-wt-LOG-2927
git add force-app/main/default/classes/TritonLwc.cls force-app/main/default/classes/TritonTest.cls
git commit -m "LOG-2927: LWC bridge maps deprecated 'Integration' category to LWC (case-insensitive, no invalid-category note)"
```

---

### Task 3: Rewrite TritonTest integration-payload coverage onto Apex category

**Files:**
- Modify: `force-app/main/default/classes/TritonTest.cls` (lines 14–23, 660, 674–680, 1133, 1136, 1822, 1840, 1860–1868, 2383–2387, 2401, 2411 — pre-Task-2 numbering; Task 2 inserted ~35 lines after line 714, so locations from 1121 onward shift by that amount; locate by content, not line number)

**Interfaces:**
- Consumes: builder default-category behavior (`TritonBuilder.build()` defaults `pharos__Category__c` to `Apex` when no category set).
- Produces: helper renamed to `assertCreatedIntegrationPayloadLogs()`; zero references to `TritonTypes.Category.Integration` remain in `TritonTest.cls` (precondition for Task 4's enum removal).

- [ ] **Step 1: Rewrite the assertion helper (lines 14–23)**

Replace `assertCreatedIntegrationLog` entirely with:

```apex
    private static void assertCreatedIntegrationPayloadLogs() {
        List<pharos__Log__c> logs = [SELECT Id, pharos__Category__c, pharos__Hash__c, pharos__Summary__c, pharos__Stacktrace_Parse_Result__c FROM pharos__Log__c ORDER BY CreatedDate];
        System.assertEquals(2, logs.size(), 'Expected exactly 2 logs, found: ' + logs.size());
        for(Integer i = 0; i < logs.size(); i++) {
            System.assertEquals(TritonTypes.Category.Apex.name(), logs.get(i).pharos__Category__c,
                'Log ' + i + ' (' + logs.get(i).pharos__Summary__c + ') should be Apex category, but was: ' + logs.get(i).pharos__Category__c);
            System.assertNotEquals(null, logs.get(i).pharos__Stacktrace_Parse_Result__c,
                'Log ' + i + ' should carry the integration payload');
        }
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
        System.assertNotEquals(null, logs.get(1).pharos__Hash__c);
    }
```

Update its single call site in `test_sync_integration_from_exception` (line 660): `assertCreatedIntegrationLog();` → `assertCreatedIntegrationPayloadLogs();`

- [ ] **Step 2: Drop explicit Integration category from emitting helpers/tests**

1. `test_integration_error_sync` (~line 674): remove `.category(TritonTypes.Category.Integration)` from the builder chain, and replace the query + assertions (~lines 677–680) with:

```apex
        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c, pharos__Category__c, pharos__Stacktrace_Parse_Result__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertEquals(TritonTypes.Category.Apex.name(), logs.get(0).pharos__Category__c, 'Integration payload log should default to Apex category');
        System.assertNotEquals(null, logs.get(0).pharos__Stacktrace_Parse_Result__c, 'Integration payload should be preserved');
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
```

2. `testHttpRequest()` helper (~lines 1133 and 1136): remove `.category(TritonTypes.Category.Integration)` from both `Triton.logNow(...)` builder chains (leave everything else identical).

3. `test_event_and_integration_error_variations` (~lines 1822 and 1840): remove `.category(TritonTypes.Category.Integration)` from both builders. Replace the verification loop (~lines 1860–1868) with:

```apex
        System.assertEquals(3, logs.size(), 'Should have created event and integration error logs');

        Integer payloadLogs = 0;
        for(pharos__Log__c log : logs) {
            if(log.pharos__Stacktrace_Parse_Result__c != null) {
                payloadLogs++;
                System.assertEquals(TritonTypes.Category.Apex.name(), log.pharos__Category__c,
                    'Integration payload log should default to Apex category');
            }
        }
        System.assertEquals(2, payloadLogs, 'Both integration error logs should carry parsed request/response data');
```

- [ ] **Step 3: Substitute Category.Event in the two builder-behavior tests**

1. `test_default_category_not_overridden` (~lines 2383–2387): change `.category(TritonTypes.Category.Integration)` → `.category(TritonTypes.Category.Event)` and the assertion to `System.assertEquals(TritonTypes.Category.Event.name(), log.pharos__Category__c, 'Explicit category should not be overridden');`

2. `test_builder_clone` (~line 2401): change `.category(TritonTypes.Category.Integration)` → `.category(TritonTypes.Category.Event)`; assertion (~line 2411): `TritonTypes.Category.Integration.name()` → `TritonTypes.Category.Event.name()`.

- [ ] **Step 4: Verify zero enum references remain, deploy, run**

Run: `grep -n "Category.Integration" /Users/glyuk/dev/triton-wt-LOG-2927/force-app/main/default/classes/TritonTest.cls` — expected: no matches.
Run: `/Users/glyuk/dev/triton/.claude/ship-org.sh deploy` then `/Users/glyuk/dev/triton/.claude/ship-org.sh test TritonTest`
Expected: ALL PASS. (These rewrites are green even before the enum removal — dropping `.category(...)` means the logs already default to Apex; the compile-breaking dependency on the enum is what this task removes ahead of Task 4.)

- [ ] **Step 5: Commit**

```bash
cd /Users/glyuk/dev/triton-wt-LOG-2927
git add force-app/main/default/classes/TritonTest.cls
git commit -m "LOG-2927: rewrite integration-payload test coverage onto Apex-category logs"
```

---

### Task 4: Remove the Category.Integration enum member + doc comments

**Files:**
- Modify: `force-app/main/default/classes/TritonTypes.cls:15,53-54`
- Modify: `force-app/main/default/classes/TritonHelper.cls:423`

**Interfaces:**
- Consumes: Task 3's guarantee that no Apex in the repo references `Category.Integration` (grep-verified).
- Produces: `TritonTypes.Category` = `{Apex, Flow, LWC, Aura, Warning, Event, Debug}`.

- [ ] **Step 1: Remove the enum member and update doc comments**

`TritonTypes.cls` — the Category enum (lines 46–55) becomes:

```apex
    public enum Category {
        Apex,
        Flow,
        LWC,
        Aura,
        Warning,
        Event,
        Debug
    }
```

`TritonTypes.cls:15`: ` * - Category enum: Provides high-level classification of log entries (e.g., Apex, Flow, Integration)` → ` * - Category enum: Provides high-level classification of log entries (e.g., Apex, Flow, LWC)`

`TritonHelper.cls:423`: `         * Only applicable to Apex and Integration logs` → `         * Only applicable to Apex logs`

- [ ] **Step 2: Verify no remaining references, deploy, run affected suites**

Run: `grep -rn "Category.Integration" /Users/glyuk/dev/triton-wt-LOG-2927/force-app/` — expected: no matches.
Run: `/Users/glyuk/dev/triton/.claude/ship-org.sh deploy`
Expected: deploy succeeds (compile proves nothing references the removed member).
Run: `/Users/glyuk/dev/triton/.claude/ship-org.sh test TritonTest` and `/Users/glyuk/dev/triton/.claude/ship-org.sh test TritonFlowTest`
Expected: ALL PASS — including Task 1/2's bridge tests, which now exercise the post-removal path (`'Integration'` no longer resolvable via `valueOf`, handled by the guards).

- [ ] **Step 3: Commit**

```bash
cd /Users/glyuk/dev/triton-wt-LOG-2927
git add force-app/main/default/classes/TritonTypes.cls force-app/main/default/classes/TritonHelper.cls
git commit -m "LOG-2927: remove deprecated TritonTypes.Category.Integration enum member"
```

---

### Task 5: Update skill guidance (instrument-apex.md, migrate-to-2.0.md)

**Files:**
- Modify: `agent-skills/instrument-apex.md:40,204,213,225,366`
- Modify: `agent-skills/migrate-to-2.0.md` (note after the mapping table, ~line 51)

**Interfaces:**
- Consumes: nothing from earlier tasks (docs only, no deploy needed).
- Produces: skill guidance that no longer instructs `Category.Integration`.

- [ ] **Step 1: Edit instrument-apex.md**

1. Line 40: `(For callouts, classify as `` `Category.Integration` `` + a call type such as `` `BackendCall` ``.)` → `(For callouts, keep the default `` `Apex` `` category, classify with a call type such as `` `BackendCall` ``, and always attach `` `.integrationPayload(req, res)` ``.)`
2. Line 204: `Attach the HTTP payload with `` `integrationPayload(req, res)` `` and classify as `` `Category.Integration` `` + `` `Type.BackendCall` ``:` → `Attach the HTTP payload with `` `integrationPayload(req, res)` ``, keep the default `` `Apex` `` category, and classify as `` `Type.BackendCall` ``:`
3. Delete the line `                .category(TritonTypes.Category.Integration)` from the first code example (line 213).
4. Delete the line `            .category(TritonTypes.Category.Integration)` from the catch-block example (line 225).
5. Line 366: `Category should stay standard (`` `Apex` ``, or `` `Integration` `` for callouts).` → `Category should stay standard (`` `Apex` `` — including callouts, which are distinguished by `` `integrationPayload` `` + a call type, not by category).`

- [ ] **Step 2: Add the note to migrate-to-2.0.md**

Insert after the mapping table (after line 50's `stopTransaction` row, before line 52's "Transaction/template methods..." paragraph):

```markdown

> **Note on `addIntegrationError`:** the legacy call wrote `Category = 'Integration'`; the 2.0 form intentionally lands as `Apex` — the Integration category is deprecated, and post-processing payload preservation is triggered by the `integrationPayload` itself, not by category.
```

- [ ] **Step 3: Verify no stale guidance remains**

Run: `grep -rn "Category.Integration" /Users/glyuk/dev/triton-wt-LOG-2927/agent-skills/` — expected: no matches.
Run: `grep -rni "integration" /Users/glyuk/dev/triton-wt-LOG-2927/agent-skills/instrument-apex.md` — expected: only `integrationPayload` mentions and the reworded lines.

- [ ] **Step 4: Commit**

```bash
cd /Users/glyuk/dev/triton-wt-LOG-2927
git add agent-skills/instrument-apex.md agent-skills/migrate-to-2.0.md
git commit -m "LOG-2927: skill guidance — callouts keep default Apex category with integrationPayload"
```

---

### Task 6: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Full Apex suite on qa42**

Run: `/Users/glyuk/dev/triton/.claude/ship-org.sh test`
Expected: all tests PASS except the documented non-blocking org-resident stale `LogTest.test_save_component_log` failure. Record exact pass/fail counts for the DONE message.

- [ ] **Step 2: Jest sanity**

Run: `npm test` (from the worktree root)
Expected: PASS (no LWC changes in this ticket).

- [ ] **Step 3: Final review of the branch diff**

Run: `git -C /Users/glyuk/dev/triton-wt-LOG-2927 diff origin/release/2.0...HEAD --stat` and `git -C /Users/glyuk/dev/triton-wt-LOG-2927 status --short`
Expected: only the spec/plan docs, TritonFlow.cls, TritonFlowTest.cls, TritonLwc.cls, TritonTest.cls, TritonTypes.cls, TritonHelper.cls, instrument-apex.md, migrate-to-2.0.md; clean tree, no featureParameters mutations (none were made — no `param` toggles used).

- [ ] **Step 4: Send DONE**

Send `DONE LOG-2927 triton: ...` to atlas with files changed, full test-run summary (counts, noting the documented non-blocking failure), and commits on branch.
