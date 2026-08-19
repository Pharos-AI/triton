/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

/**
 * Behaviour tests for the Triton performance mark API: paired records, span
 * nesting, ambient parenting of ordinary logs, suppression, and name derivation.
 *
 * Assertions read the log buffer (Triton.logs) rather than querying, because a
 * mark never flushes: the buffer is the observable output of startMark/endMark.
 *
 * Note on stack traces: TritonHelper.getCurrentStackTrace returns the UNFILTERED
 * trace under Test.isRunningTest(), so Triton's own frames are present here and
 * absent in production. Assertions below compare traces between the two paired
 * records rather than inspecting their content, which is immune to that.
 */
@IsTest
private class TritonMarkTest {

    private static final String CPU_TIME_FIELD = 'CPU_Time__c';

    @TestSetup
    private static void testSetup() {
        TritonTestFactory.initTestSetup();
    }

    // ─── Helpers ─────────────────────────────────────────────────────

    private static String requestId() {
        return System.Request.getCurrent().getRequestId();
    }

    private static List<pharos__Log__c> buffer() {
        return Triton.logs;
    }

    private static pharos__Log__c bufferedLog(Integer index) {
        return Triton.logs.get(index);
    }

    private static String spanOf(pharos__Log__c log) {
        return (String) log.get(TritonBuilder.SPAN_ID);
    }

    private static String parentOf(pharos__Log__c log) {
        return (String) log.get(TritonBuilder.PARENT_SPAN_ID);
    }

    private static String actionOf(pharos__Log__c log) {
        return (String) log.get(TritonBuilder.ACTION);
    }

    private static pharos__Log__c bufferedBySummary(String summary) {
        for (pharos__Log__c log : Triton.logs) {
            if (summary.equals(log.pharos__Summary__c)) return log;
        }
        return null;
    }

    private static void setLogLevels(List<Log_Level__mdt> rules) {
        TritonHelper.Config.logLevelsMdt = rules;
        TritonHelper.Config.logLevels = null;
    }

    private static Log_Level__mdt componentRule(String component, TritonTypes.Level level) {
        Log_Level__mdt rule = new Log_Level__mdt();
        rule.Component_Name__c = component;
        rule.Level__c = level.name();
        return rule;
    }

    /** Opens a mark from a named helper so the derived name is predictable. */
    private static String startMarkFromHelper() {
        return Triton.startMark();
    }

    /** Closes a mark from a different method than the one that opened it. */
    private static void endMarkFromHelper(String markName) {
        Triton.endMark(markName);
    }

    /** Stands in for a batch chunk's execute(). */
    private static String executeChunk() {
        return Triton.startMark();
    }

    // ─── Pairing ─────────────────────────────────────────────────────

    @IsTest
    private static void test_startMark_emits_paired_records() {
        Test.startTest();
        Triton.startMark('unit-of-work');
        Triton.endMark();
        Test.stopTest();

        System.assertEquals(2, buffer().size(), 'A mark emits exactly one opening and one completion record');

        pharos__Log__c opening = bufferedLog(0);
        pharos__Log__c completion = bufferedLog(1);

        System.assertEquals('Performance started: unit-of-work', opening.pharos__Summary__c,
            'The opening record carries the converter\'s "Performance started" prefix');
        System.assertEquals('Performance: unit-of-work', completion.pharos__Summary__c,
            'The completion record carries the converter\'s "Performance" prefix');

        System.assertEquals(TritonTypes.Type.Performance.name(), opening.pharos__Type__c, 'Opening record type');
        System.assertEquals(TritonTypes.Type.Performance.name(), completion.pharos__Type__c, 'Completion record type');

        System.assertEquals('unit-of-work', actionOf(opening), 'Action names the mark on the opening record');
        System.assertEquals('unit-of-work', actionOf(completion), 'Action names the mark on the completion record');

        System.assertEquals(spanOf(opening), spanOf(completion), 'Both halves describe the same span');

        System.assertEquals(null, opening.pharos__Duration__c, 'The opening record has no duration yet');
        System.assertNotEquals(null, completion.pharos__Duration__c, 'The completion record carries the elapsed time');
        System.assertEquals(null, opening.pharos__Details__c, 'The opening record has no details');
        System.assert(completion.pharos__Details__c.startsWith('Duration: ')
                && completion.pharos__Details__c.endsWith('ms'),
            'Completion details state the duration, found: ' + completion.pharos__Details__c);

        System.assertEquals(null, opening.get(CPU_TIME_FIELD),
            'The opening record suppresses limit info -- it has no deltas worth carrying');
        System.assertNotEquals(null, completion.get(CPU_TIME_FIELD),
            'The completion record keeps limit info');

        System.assertEquals(false, Triton.hasOpenMark(), 'No mark is left open');
    }

    @IsTest
    private static void test_mark_level_is_fine() {
        Test.startTest();
        Triton.startMark('level-check');
        Triton.endMark();
        Test.stopTest();

        for (pharos__Log__c log : buffer()) {
            System.assertEquals(TritonTypes.Level.FINE.name(), log.Log_Level__c,
                'Marks are FINE; verbosity is dialled by Log_Level__mdt, never by a call-site argument');
        }
    }

    @IsTest
    private static void test_mark_level_is_dialled_by_metadata() {
        setLogLevels(new List<Log_Level__mdt>{ componentRule('quiet-mark', TritonTypes.Level.ERROR) });

        Test.startTest();
        Triton.startMark('quiet-mark');
        Triton.endMark();
        Test.stopTest();

        System.assertEquals(0, buffer().size(),
            'A metadata rule less verbose than FINE filters both halves of the mark out');
    }

    @IsTest
    private static void test_mark_records_use_template_area() {
        Triton.setTemplate(Triton.makeBuilder().area(TritonTypes.Area.OpportunityManagement));

        Test.startTest();
        Triton.startMark('templated');
        Triton.endMark();
        Test.stopTest();

        System.assertEquals(2, buffer().size(), 'Both halves emitted');
        for (pharos__Log__c log : buffer()) {
            System.assertEquals(TritonTypes.Area.OpportunityManagement.name(), log.pharos__Area__c,
                'Marks are built from the template, so an entry point\'s Area survives onto them');
        }
    }

    // ─── Nesting ─────────────────────────────────────────────────────

    @IsTest
    private static void test_startMark_nesting_parent_chain() {
        Test.startTest();
        Triton.startMark('outer');
        Triton.startMark('middle');
        Triton.startMark('inner');
        Triton.endMark();
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        System.assertEquals(6, buffer().size(), 'Three marks emit six records');

        pharos__Log__c outerLog = bufferedBySummary('Performance started: outer');
        pharos__Log__c middle = bufferedBySummary('Performance started: middle');
        pharos__Log__c innerLog = bufferedBySummary('Performance started: inner');

        System.assertEquals(requestId(), spanOf(outerLog),
            'The first mark at depth 0 claims the request node');
        System.assertEquals(null, parentOf(outerLog),
            'The request node has no parent of its own -- the session umbrella supplies it');
        System.assertEquals(spanOf(outerLog), parentOf(middle), 'The middle mark nests under the outer one');
        System.assertEquals(spanOf(middle), parentOf(innerLog), 'The inner mark nests under the middle one');
        System.assertNotEquals(spanOf(middle), spanOf(innerLog), 'Each mark gets its own span id');
    }

    @IsTest
    private static void test_startMark_siblings_share_parent() {
        Test.startTest();
        Triton.startMark('boundary');
        Triton.startMark('first');
        Triton.endMark();
        Triton.startMark('second');
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c boundary = bufferedBySummary('Performance started: boundary');
        pharos__Log__c first = bufferedBySummary('Performance started: first');
        pharos__Log__c second = bufferedBySummary('Performance started: second');

        System.assertEquals(spanOf(boundary), parentOf(first), 'Siblings share the enclosing parent');
        System.assertEquals(spanOf(boundary), parentOf(second), 'Siblings share the enclosing parent');
        System.assertNotEquals(spanOf(first), spanOf(second), 'Siblings are distinct spans');
    }

    @IsTest
    private static void test_endMark_recursion_same_name() {
        Test.startTest();
        Triton.startMark('f');
        Triton.startMark('f');
        Triton.startMark('f');
        Triton.endMark('f');
        Triton.endMark('f');
        Triton.endMark('f');
        Test.stopTest();

        System.assertEquals(6, buffer().size(), 'Three same-named marks emit six records, none orphaned');

        List<String> openingSpans = new List<String>();
        for (pharos__Log__c log : buffer()) {
            if ('Performance started: f'.equals(log.pharos__Summary__c)) openingSpans.add(spanOf(log));
        }
        System.assertEquals(3, openingSpans.size(), 'Three opening records');
        System.assertEquals(3, new Set<String>(openingSpans).size(),
            'Same-named marks are three distinct spans -- the defect a name-keyed map would introduce');

        List<pharos__Log__c> openings = new List<pharos__Log__c>();
        for (pharos__Log__c log : buffer()) {
            if ('Performance started: f'.equals(log.pharos__Summary__c)) openings.add(log);
        }
        System.assertEquals(spanOf(openings.get(0)), parentOf(openings.get(1)), 'Recursion nests');
        System.assertEquals(spanOf(openings.get(1)), parentOf(openings.get(2)), 'Recursion nests');

        System.assertEquals(false, Triton.hasOpenMark(), 'Every mark was closed');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'The span stack is back at the request root');
    }

    @IsTest
    private static void test_endMark_out_of_order() {
        Test.startTest();
        String a = Triton.startMark('A');
        String b = Triton.startMark('B');
        Triton.endMark(a);
        Triton.endMark(b);
        Test.stopTest();

        System.assertEquals(4, buffer().size(), 'Both marks emit both halves regardless of close order');
        System.assertEquals(false, Triton.hasOpenMark(), 'No mark is left open');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'The span stack is back at the request root');
    }

    @IsTest
    private static void test_endMark_unknown_name_is_ignored() {
        Test.startTest();
        Triton.startMark('open-mark');
        Triton.endMark('never-started');

        System.assertEquals(1, buffer().size(), 'An unknown name emits nothing');
        System.assertEquals(true, Triton.hasOpenMark(), 'The open mark is untouched');

        Triton.endMark();
        String followUp = Triton.startMark('follow-up');
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c later = bufferedBySummary('Performance started: follow-up');
        System.assertEquals(requestId(), parentOf(later),
            'A later root mark still parents to the request id');
    }

    // ─── Exception path ──────────────────────────────────────────────

    @IsTest
    private static void test_clearMarks_after_exception() {
        Test.startTest();
        try {
            Triton.startMark('throws');
            throw new IllegalArgumentException('boom');
        } catch (Exception e) {
            // swallowed on purpose: the mark is left open
        }

        System.assertEquals(1, buffer().size(), 'The opening record survives a throw');
        System.assertEquals(null, bufferedBySummary('Performance: throws'), 'No completion record was emitted');
        System.assertEquals(true, Triton.hasOpenMark(), 'The mark is still open');

        Triton.clearMarks();
        Test.stopTest();

        System.assertEquals(false, Triton.hasOpenMark(), 'clearMarks discards open marks');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'clearMarks resets the stack to the request root');
    }

    @IsTest
    private static void test_startTransaction_clears_marks() {
        Test.startTest();
        Triton.startMark('stale');
        Triton.startTransaction();
        Test.stopTest();

        System.assertEquals(false, Triton.hasOpenMark(), 'startTransaction starts from a clean span hierarchy');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'The stack is reset to the request root');
    }

    // ─── Ambient stamping ────────────────────────────────────────────

    @IsTest
    private static void test_log_inside_mark_is_child_span() {
        Test.startTest();
        Triton.startMark('boundary');
        Triton.startMark('inner');
        Triton.info(Triton.t.summary('leaf log'));
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c innerLog = bufferedBySummary('Performance started: inner');
        pharos__Log__c leaf = bufferedBySummary('leaf log');

        System.assertEquals(spanOf(innerLog), parentOf(leaf), 'A log inside a mark is parented to that mark');
        System.assertNotEquals(null, spanOf(leaf), 'A log inside a mark gets its own span id');
        System.assertNotEquals(spanOf(innerLog), spanOf(leaf), 'The leaf is its own span, not the mark');
        System.assertNotEquals(requestId(), spanOf(leaf), 'The leaf no longer collapses onto the request node');
    }

    @IsTest
    private static void test_log_outside_mark_is_unchanged() {
        Test.startTest();
        Triton.info(Triton.t.summary('no mark here'));
        Test.stopTest();

        pharos__Log__c log = bufferedBySummary('no mark here');
        System.assertEquals(requestId(), spanOf(log),
            'Outside a mark the span id is still the request id -- byte-identical to today');
        System.assertEquals(null, parentOf(log), 'Outside a mark there is still no parent');
    }

    @IsTest
    private static void test_explicit_span_ids_win_inside_mark() {
        Test.startTest();
        Triton.startMark('boundary');
        Triton.info(Triton.t.summary('explicit').spanId('browser-span').parentSpanId('browser-parent'));
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c log = bufferedBySummary('explicit');
        System.assertEquals('browser-span', spanOf(log), 'An explicitly set span id is never clobbered');
        System.assertEquals('browser-parent', parentOf(log), 'An explicitly set parent span id is never clobbered');
    }

    @IsTest
    private static void test_explicit_span_ids_win_via_lwc() {
        TritonLwc.ComponentLog componentLog = new TritonLwc.ComponentLog();
        componentLog.category = TritonTypes.Category.LWC.name();
        componentLog.level = TritonTypes.Level.INFO.name();
        componentLog.summary = 'lwc log';
        componentLog.spanId = 'lwc-span';
        componentLog.parentSpanId = 'lwc-parent';
        componentLog.componentInfo = new TritonLwc.Component();
        componentLog.componentInfo.name = 'myCmp';

        Test.startTest();
        Triton.startMark('boundary');
        TritonLwc.saveComponentLogs(new List<TritonLwc.ComponentLog>{ componentLog });
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT Id, Span_Id__c, Parent_Span_Id__c
            FROM pharos__Log__c
            WHERE pharos__Summary__c = 'lwc log'
        ];
        System.assertEquals(1, logs.size(), 'The LWC log was persisted');
        System.assertEquals('lwc-span', logs.get(0).Span_Id__c,
            'The browser\'s span id survives the whole LWC path');
        System.assertEquals('lwc-parent', logs.get(0).Parent_Span_Id__c,
            'The browser\'s parent span id survives the whole LWC path');
    }

    // ─── Suppression ─────────────────────────────────────────────────

    @IsTest
    private static void test_suppressed_mark_is_transparent() {
        setLogLevels(new List<Log_Level__mdt>{ componentRule('suppressed', TritonTypes.Level.INFO) });

        Test.startTest();
        Triton.startMark('boundary');
        Triton.startMark('suppressed');
        Triton.info(Triton.t.summary('inside suppressed'));
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        System.assertEquals(null, bufferedBySummary('Performance started: suppressed'),
            'The filtered mark emits no opening record');
        System.assertEquals(null, bufferedBySummary('Performance: suppressed'),
            'The filtered mark emits no completion record either -- half a pair is worse than none');

        pharos__Log__c boundary = bufferedBySummary('Performance started: boundary');
        pharos__Log__c inside = bufferedBySummary('inside suppressed');
        System.assertEquals(spanOf(boundary), parentOf(inside),
            'A filtered mark is transparent: its children nest under the nearest surviving ancestor');

        System.assertEquals(false, Triton.hasOpenMark(), 'The suppressed mark still closes cleanly');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'And still pops what it pushed');
    }

    @IsTest
    private static void test_unsuppressed_mark_parents_its_children() {
        Test.startTest();
        Triton.startMark('boundary');
        Triton.startMark('suppressed');
        Triton.info(Triton.t.summary('inside suppressed'));
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c innerLog = bufferedBySummary('Performance started: suppressed');
        pharos__Log__c inside = bufferedBySummary('inside suppressed');

        System.assertNotEquals(null, innerLog, 'Without a filtering rule the same mark does emit');
        System.assertEquals(spanOf(innerLog), parentOf(inside),
            'And its children nest under it -- proving the suppression fixture is not vacuous');
    }

    // ─── Name derivation ─────────────────────────────────────────────

    @IsTest
    private static void test_startMark_derives_name_from_stack_trace() {
        Test.startTest();
        String markName = startMarkFromHelper();
        Triton.endMark();
        Test.stopTest();

        System.assertEquals('TritonMarkTest.startMarkFromHelper', markName,
            'The name is derived from the call site');
        System.assertEquals(false, markName.startsWith('Class.'),
            'The literal Class. prefix that getOperation retains is stripped');
        System.assertEquals(false, markName.contains('Triton.'),
            'Triton\'s own frames are never used as the mark name');
        System.assertEquals(false, markName.contains('TritonSpanContext'),
            'TritonSpanContext is registered as a framework class, so it cannot be attributed as the caller');

        pharos__Log__c opening = bufferedLog(0);
        pharos__Log__c completion = bufferedLog(1);
        System.assertEquals('Performance started: ' + markName, opening.pharos__Summary__c, 'Opening summary');
        System.assertEquals('Performance: ' + markName, completion.pharos__Summary__c, 'Completion summary');
        System.assertEquals(markName, actionOf(opening), 'Opening action');
        System.assertEquals(markName, actionOf(completion), 'Completion action');
        System.assertEquals(markName, opening.pharos__Apex_Name__c, 'Opening operation');
        System.assertEquals(markName, completion.pharos__Apex_Name__c, 'Completion operation');
    }

    @IsTest
    private static void test_deriveMarkName_falls_back_to_anonymous() {
        String first = Triton.deriveMarkName('');
        String second = Triton.deriveMarkName('no frames here');

        System.assertEquals('AnonymousMark1', first, 'A blank derivation falls back to a counted anonymous name');
        System.assertEquals('AnonymousMark2', second, 'The counter keeps anonymous marks distinguishable');
    }

    @IsTest
    private static void test_anonymous_mark_still_nests() {
        Test.startTest();
        Triton.startMark('boundary');
        String anonymous = Triton.startMark(Triton.deriveMarkName(''));
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        System.assertEquals('AnonymousMark1', anonymous, 'The fallback name is used as the mark name');
        pharos__Log__c boundary = bufferedBySummary('Performance started: boundary');
        pharos__Log__c anon = bufferedBySummary('Performance started: AnonymousMark1');
        System.assertNotEquals(null, anon, 'An anonymous mark still emits its pair');
        System.assertEquals(spanOf(boundary), parentOf(anon), 'And still nests correctly');
    }

    @IsTest
    private static void test_startMark_explicit_name_overrides_derivation() {
        Test.startTest();
        String markName = Triton.startMark('explicit');
        Triton.endMark();
        Test.stopTest();

        System.assertEquals('explicit', markName, 'The supplied name is used verbatim');
        pharos__Log__c opening = bufferedLog(0);
        pharos__Log__c completion = bufferedLog(1);
        System.assertEquals('explicit', actionOf(opening), 'Opening action is the explicit name');
        System.assertEquals('explicit', actionOf(completion), 'Completion action is the explicit name');
        System.assert(String.isNotBlank(opening.pharos__Stacktrace__c),
            'The explicit form is not a capture-free path: the trace is still captured');
        System.assertEquals(opening.pharos__Stacktrace__c, completion.pharos__Stacktrace__c,
            'And still reused on both halves');
    }

    // ─── One stack capture per pair ──────────────────────────────────

    @IsTest
    private static void test_mark_pair_captures_the_stack_once() {
        Test.startTest();
        String markName = Triton.startMark();
        endMarkFromHelper(markName);
        Test.stopTest();

        pharos__Log__c opening = bufferedLog(0);
        pharos__Log__c completion = bufferedLog(1);

        System.assert(String.isNotBlank(opening.pharos__Stacktrace__c), 'The opening record carries a trace');
        System.assertEquals(opening.pharos__Stacktrace__c, completion.pharos__Stacktrace__c,
            'Both records carry the identical trace, which can only hold if neither re-captured it');
        System.assertEquals(false, completion.pharos__Stacktrace__c.contains('endMarkFromHelper'),
            'The completion record carries the opening call site, not endMark\'s own frame');
        System.assert(opening.pharos__Stacktrace__c.contains('test_mark_pair_captures_the_stack_once'),
            'The captured trace is the call site that opened the mark');
    }

    @IsTest
    private static void test_mark_pair_captures_once_with_component_scoped_levels() {
        // A component-scoped rule makes Triton.log resolve the stack trace ahead of
        // the level check -- the second place the short-circuit has to fire.
        setLogLevels(new List<Log_Level__mdt>{ componentRule('SomeOtherComponent', TritonTypes.Level.FINEST) });
        System.assertEquals(true, TritonHelper.Config.hasComponentScopedLevels(),
            'The fixture configures a component-scoped level');

        Test.startTest();
        String markName = Triton.startMark();
        endMarkFromHelper(markName);
        Test.stopTest();

        System.assertEquals(2, buffer().size(), 'The mark still emits both halves');
        pharos__Log__c opening = bufferedLog(0);
        pharos__Log__c completion = bufferedLog(1);

        System.assertEquals(opening.pharos__Stacktrace__c, completion.pharos__Stacktrace__c,
            'The early resolution short-circuits too, so still one capture per pair');
        System.assertEquals(markName, opening.pharos__Apex_Name__c,
            'And the derived operation is not re-derived over the top of the mark name');
        System.assertEquals(markName, completion.pharos__Apex_Name__c,
            'And the derived operation is not re-derived over the top of the mark name');
    }

    // ─── Trigger shorthand ───────────────────────────────────────────

    @IsTest
    private static void test_triggerMarkName_distinguishes_trigger_operations() {
        String beforeUpdate = Triton.triggerMarkName('OpportunityHandler.run', System.TriggerOperation.BEFORE_UPDATE);
        String afterUpdate = Triton.triggerMarkName('OpportunityHandler.run', System.TriggerOperation.AFTER_UPDATE);

        System.assertEquals('OpportunityHandler.BEFORE_UPDATE', beforeUpdate,
            'The handler class comes from the trace, the context from the trigger');
        System.assertEquals('OpportunityHandler.AFTER_UPDATE', afterUpdate,
            'The same frame in a different context is a different span');
        System.assertNotEquals(beforeUpdate, afterUpdate,
            'Distinct names are the whole reason this shorthand exists');
    }

    @IsTest
    private static void test_startTriggerMark_outside_trigger_context() {
        Test.startTest();
        String markName = Triton.startTriggerMark();
        Triton.endMark();
        Test.stopTest();

        System.assertEquals('TritonMarkTest.test_startTriggerMark_outside_trigger_context', markName,
            'Outside a trigger it degrades to the derived name, exactly like startMark()');
        System.assertEquals(2, buffer().size(), 'And behaves like any other mark');
        System.assertEquals(markName, actionOf(bufferedLog(0)),
            'The derived name names the span on both halves');
    }

    // ─── Async / batch ───────────────────────────────────────────────

    @IsTest
    private static void test_mark_in_async_chunk_roots_at_request_id() {
        String carriedTransactionId = TritonHelper.generateUUID4();

        Test.startTest();
        // The two-call batch idiom -- no mark-specific API needed for async.
        Triton.resumeTransaction(carriedTransactionId);
        String markName = executeChunk();
        Triton.endMark();
        Test.stopTest();

        System.assertEquals('TritonMarkTest.executeChunk', markName,
            'The phase is the method name, so a batch needs no dedicated shorthand');

        pharos__Log__c opening = bufferedLog(0);
        System.assertEquals(requestId(), spanOf(opening),
            'A fresh context self-seeds from its own request id and the chunk mark claims it');
        System.assertEquals(carriedTransactionId, opening.pharos__Transaction_Id_External__c,
            'The carried transaction id ties the chunk back to its parent transaction');
    }

    // ─── Volume ──────────────────────────────────────────────────────

    @IsTest
    private static void test_marks_volume_stays_within_limits() {
        Integer markCount = 100;

        Test.startTest();
        for (Integer i = 0; i < markCount; i++) {
            Triton.startMark('bulk-' + i);
            Triton.endMark();
        }
        Test.stopTest();

        System.assertEquals(markCount * 2, buffer().size(), 'N marks emit exactly 2N records');
        System.assert(Limits.getCpuTime() < Limits.getLimitCpuTime(),
            'A realistic number of marks stays inside the CPU limit');
        System.assert(Limits.getHeapSize() < Limits.getLimitHeapSize(),
            'A realistic number of marks stays inside the heap limit');
    }

    // ─── Never throws ────────────────────────────────────────────────

    @IsTest
    private static void test_mark_api_never_throws() {
        Test.startTest();
        try {
            Triton.endMark();
            Triton.endMark(null);
            Triton.endMark('never-opened');
            Triton.clearMarks();
            String derived = Triton.startMark(null);
            System.assert(String.isNotBlank(derived), 'A null name falls back to derivation');
            Triton.endMark();
            Triton.clearMarks();
            Triton.clearMarks();
        } catch (Exception e) {
            System.assert(false, 'Instrumentation must never throw into business logic, but got: ' + e);
        }
        Test.stopTest();
    }
}
