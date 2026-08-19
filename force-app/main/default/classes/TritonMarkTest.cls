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

    /**
     * Share of the CPU limit the org's worst-case mark volume is allowed to consume.
     *
     * 50% is a 5,000ms ceiling. Back-to-back runs in a quiet org land at 2,723-2,826ms,
     * a spread of only ~4% -- but the same build measured 3,105ms on a run that overlapped
     * a deploy, which is 12% above that whole range. Apex CPU accounting swings much wider
     * under org load than a quiet-org sample suggests, and a tighter ceiling would make
     * this the flakiest assert in the suite: 40% left the observed outlier only 1.29x of
     * headroom. The assertion keeps its meaning at 50% -- 217 marks still leave most of
     * the budget to the business logic they are measuring.
     */
    private static final Integer CPU_BUDGET_NUMERATOR = 50;

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
        String transactionId = Triton.startTransaction();
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

        System.assertNotEquals(requestId(), spanOf(outerLog),
            'Every mark mints its own span id, depth 0 included: the span converter hashes the '
            + 'request id to build the request span but resolves an explicit id as a UUID, so a '
            + 'mark carrying the request id would name a span nothing else can point at');
        System.assertEquals(transactionId, parentOf(outerLog),
            'The outermost mark parents onto the transaction span the converter synthesises from '
            + 'the transaction id');
        System.assertEquals(spanOf(outerLog), parentOf(middle), 'The middle mark nests under the outer one');
        System.assertEquals(spanOf(middle), parentOf(innerLog), 'The inner mark nests under the middle one');
        System.assertNotEquals(spanOf(middle), spanOf(innerLog), 'Each mark gets its own span id');
    }

    @IsTest
    private static void test_outermost_mark_has_no_parent_without_a_transaction() {
        Test.startTest();
        Triton.startMark('lonely');
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c opening = bufferedBySummary('Performance started: lonely');
        System.assertEquals(null, parentOf(opening),
            'With no transaction the parent is left null, so the span converter falls back to the '
            + 'request root it hashes from the request id. Substituting the request id here instead '
            + 'would name a span that nothing carries');
        System.assertNotEquals(null, spanOf(opening), 'The mark still has a span id');
        System.assertNotEquals(requestId(), spanOf(opening), 'Which is its own, not the request id');
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
        String transactionId = Triton.startTransaction();
        Triton.startMark('open-mark');
        Triton.endMark('never-started');

        System.assertEquals(1, buffer().size(), 'An unknown name emits nothing');
        System.assertEquals(true, Triton.hasOpenMark(), 'The open mark is untouched');

        Triton.endMark();
        Triton.startMark('follow-up');
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c first = bufferedBySummary('Performance started: open-mark');
        pharos__Log__c later = bufferedBySummary('Performance started: follow-up');

        System.assertNotEquals(requestId(), spanOf(later),
            'A second mark at depth 0 mints its own span id -- nothing claims the request id, '
            + 'which the converter reaches only by hashing');
        System.assertNotEquals(spanOf(first), spanOf(later),
            'Two sequential depth-0 marks are two distinct spans');
        System.assertEquals(transactionId, parentOf(first),
            'Both parent onto the same synthetic transaction span');
        System.assertEquals(transactionId, parentOf(later),
            'Both parent onto the same synthetic transaction span, so the second is not orphaned');
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
    private static void test_unclosed_inner_mark_leaves_outer_as_ambient_parent() {
        Test.startTest();
        Triton.startMark('outer');
        Triton.startMark('inner');
        Triton.endMark();
        Triton.info(Triton.t.summary('after the inner close'));

        pharos__Log__c outerLog = bufferedBySummary('Performance started: outer');
        System.assertEquals(true, Triton.hasOpenMark(), 'The outer mark is still open');
        System.assertEquals(spanOf(outerLog), Triton.currentSpanId(),
            'Closing the inner mark popped exactly one level -- the stack is not corrupted');
        System.assertEquals(spanOf(outerLog), parentOf(bufferedBySummary('after the inner close')),
            'And the outer mark is the ambient parent again');

        Triton.endMark();
        Test.stopTest();

        System.assertEquals(false, Triton.hasOpenMark(), 'Both marks are closed');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'And the stack is back at its root');
    }

    @IsTest
    private static void test_clearMarks_mid_nest_then_new_mark_roots() {
        Test.startTest();
        String transactionId = Triton.startTransaction();
        Triton.startMark('outer');
        Triton.startMark('inner');
        Triton.clearMarks();

        System.assertEquals(false, Triton.hasOpenMark(), 'clearMarks discards both open marks');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'And resets the stack to its root');

        Triton.startMark('after-clear');
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c afterClear = bufferedBySummary('Performance started: after-clear');
        System.assertEquals(transactionId, parentOf(afterClear),
            'A mark opened after clearMarks roots at the transaction span, not under the discarded nest');
        System.assertNotEquals(requestId(), spanOf(afterClear), 'And is its own span');
        System.assertEquals(false, Triton.hasOpenMark(), 'And closes cleanly');
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

    @IsTest
    private static void test_stopTransaction_leaves_an_open_mark_alone() {
        Test.startTest();
        Triton.startTransaction();
        Triton.startMark('spans-the-stop');
        Triton.stopTransaction();
        Triton.info(Triton.t.summary('after the stop'));
        Triton.endMark();
        Triton.startMark('opened-after-the-stop');
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c opening = bufferedBySummary('Performance started: spans-the-stop');
        pharos__Log__c completion = bufferedBySummary('Performance: spans-the-stop');
        System.assertNotEquals(null, completion,
            'stopTransaction deliberately does not clearMarks -- spans are request-scoped while '
            + 'transactions are not, so the open mark survives the stop and still closes');
        System.assertEquals(spanOf(opening), spanOf(completion),
            'And both halves still describe one span across the stop');
        System.assertEquals(spanOf(opening), parentOf(bufferedBySummary('after the stop')),
            'The mark is still the ambient parent after the stop');

        pharos__Log__c later = bufferedBySummary('Performance started: opened-after-the-stop');
        System.assertEquals(null, later.pharos__Transaction_Id_External__c,
            'A mark opened after the stop carries no transaction id -- the documented consequence');
        System.assertEquals(null, parentOf(later),
            'And no parent, which the span converter resolves to the request root');
    }

    @IsTest
    private static void test_resumeTransaction_is_inert_for_open_marks() {
        Test.startTest();
        Triton.startMark('outer');
        String outerSpan = Triton.currentSpanId();
        Triton.resumeTransaction(TritonHelper.generateUUID4());

        System.assertEquals(true, Triton.hasOpenMark(), 'resumeTransaction never touches open marks');
        System.assertEquals(outerSpan, Triton.currentSpanId(),
            'Nor the span stack. The stack is rooted at the request id precisely so that a '
            + 'transaction reassigned mid-request cannot re-root an already-built subtree');

        Triton.startMark('inner');
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        pharos__Log__c outerLog = bufferedBySummary('Performance started: outer');
        pharos__Log__c innerLog = bufferedBySummary('Performance started: inner');
        System.assertEquals(spanOf(outerLog), parentOf(innerLog),
            'A mark opened after the resume still nests under the enclosing mark, not under the '
            + 'newly resumed transaction');
        System.assertEquals(null, parentOf(outerLog),
            'And the outer mark keeps the parent it was given when it opened -- none, because no '
            + 'transaction existed then');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'The stack unwinds to its root');
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

    @IsTest
    private static void test_suppressed_parent_with_unsuppressed_child() {
        setLogLevels(new List<Log_Level__mdt>{ componentRule('quiet-parent', TritonTypes.Level.INFO) });

        Test.startTest();
        String transactionId = Triton.startTransaction();
        Triton.startMark('quiet-parent');
        Triton.startMark('loud-child');
        Triton.info(Triton.t.summary('inside the child'));
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        System.assertEquals(null, bufferedBySummary('Performance started: quiet-parent'),
            'The filtered parent emits nothing');
        pharos__Log__c child = bufferedBySummary('Performance started: loud-child');
        System.assertNotEquals(null, child, 'A filtered parent does not filter its child');
        System.assertEquals(transactionId, parentOf(child),
            'The child skips the transparent parent and attaches to the nearest surviving ancestor '
            + '-- here the synthetic transaction span, since the parent was the outermost mark');
        System.assertNotEquals(requestId(), parentOf(child),
            'Never the request id: the converter only ever reaches the request span by hashing, so '
            + 'a request id used as a parent value resolves onto nothing');
        System.assertEquals(spanOf(child), parentOf(bufferedBySummary('inside the child')),
            'And the surviving child parents its own children normally');

        System.assertEquals(false, Triton.hasOpenMark(), 'Both marks close cleanly');
        System.assertEquals(requestId(), Triton.currentSpanId(), 'And the stack is back at its root');
    }

    @IsTest
    private static void test_nested_suppression_two_levels_deep() {
        setLogLevels(new List<Log_Level__mdt>{
            componentRule('quiet-outer', TritonTypes.Level.INFO),
            componentRule('quiet-inner', TritonTypes.Level.INFO)
        });

        // No surviving mark stands above the suppressed pair: quiet-outer is itself the
        // outermost mark, so both suppressions push the span stack's request-id root and
        // spans.current() never names a real span. That is exactly the case the
        // ambientParentSpanId translation exists for, so it must be tested at depth 0 --
        // a surviving boundary mark above these two would supply a genuine parent span
        // id and the translation would never fire.
        Test.startTest();
        String transactionId = Triton.startTransaction();
        Triton.startMark('quiet-outer');
        Triton.startMark('quiet-inner');
        Triton.info(Triton.t.summary('two suppressions deep'));
        Triton.endMark();
        Triton.endMark();
        Test.stopTest();

        System.assertEquals(null, bufferedBySummary('Performance started: quiet-outer'),
            'The outer suppression emits nothing');
        System.assertEquals(null, bufferedBySummary('Performance started: quiet-inner'),
            'The inner suppression emits nothing either');
        System.assertEquals(1, buffer().size(),
            'Neither suppressed pair leaves a record, so the leaf is the only log buffered');

        String leafParent = parentOf(bufferedBySummary('two suppressions deep'));
        System.assertEquals(transactionId, leafParent,
            'Stacked suppressions at depth 0 collapse past both marks to the transaction span, '
            + 'which the converter synthesises for every transaction id');
        System.assertNotEquals(requestId(), leafParent,
            'And never to the request id the two suppressions actually stacked: the converter '
            + 'reaches the request span only by hashing, so a request id used as a parent value '
            + 'names a span nothing in the trace carries');

        System.assertEquals(false, Triton.hasOpenMark(), 'Both marks closed');
        System.assertEquals(requestId(), Triton.currentSpanId(),
            'And popping by value unwinds the duplicate ids the two suppressions pushed, so the '
            + 'stack ends exactly where it started');
    }

    @IsTest
    private static void test_suppressed_only_mark_still_reshapes_surrounding_logs() {
        setLogLevels(new List<Log_Level__mdt>{ componentRule('invisible', TritonTypes.Level.INFO) });

        Test.startTest();
        String transactionId = Triton.startTransaction();
        Triton.startMark('invisible');
        Triton.info(Triton.t.summary('beside an invisible mark'));
        Triton.endMark();
        Test.stopTest();

        System.assertEquals(null, bufferedBySummary('Performance started: invisible'),
            'The only open mark emitted nothing at all');

        pharos__Log__c beside = bufferedBySummary('beside an invisible mark');
        System.assertNotEquals(requestId(), spanOf(beside),
            'Suppression is transparent for parenting but NOT for data shape: a mark is still open, '
            + 'so a surrounding log gets its own span id rather than the request id it would carry '
            + 'with no mark open at all');
        System.assertEquals(transactionId, parentOf(beside),
            'And a parent -- the transparent mark\'s own ancestor, never the mark itself');
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
            'Nor TritonSpanContext, whose TRITON_FRAMEWORK_CLASSES registration is what keeps a '
            + 'span-stack frame from being attributed as the caller. Not caught by the assert '
            + 'above: TritonSpanContext has no dot after Triton, so it does not contain "Triton."');

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
        String first = TritonHelper.deriveMarkName('');
        String second = TritonHelper.deriveMarkName('no frames here');

        System.assertEquals('AnonymousMark1', first, 'A blank derivation falls back to a counted anonymous name');
        System.assertEquals('AnonymousMark2', second, 'The counter keeps anonymous marks distinguishable');
    }

    // startMark() cannot reach the blank-derivation fallback from a test: every trace
    // captured inside a test has an application frame. The fallback itself is covered by
    // test_deriveMarkName_falls_back_to_anonymous; this covers only what remains, that a
    // mark carrying such a name nests like any other.
    @IsTest
    private static void test_derived_fallback_name_nests_like_any_other() {
        Test.startTest();
        Triton.startMark('boundary');
        String anonymous = Triton.startMark(TritonHelper.deriveMarkName(''));
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
    private static void test_mark_in_async_chunk_parents_to_the_carried_transaction() {
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
        System.assertNotEquals(requestId(), spanOf(opening),
            'The chunk mark is its own span -- the chunk\'s request id is the converter\'s request '
            + 'root, not a span id a mark can borrow');
        System.assertEquals(carriedTransactionId, parentOf(opening),
            'It parents onto the carried transaction, which is what makes sibling chunks one tree');
        System.assertEquals(carriedTransactionId, opening.pharos__Transaction_Id_External__c,
            'The carried transaction id ties the chunk back to its parent transaction');
    }

    // ─── Volume ──────────────────────────────────────────────────────

    @IsTest
    private static void test_marks_volume_stays_within_a_cpu_budget() {
        // 217 marks is the worst case measured in a real org. Asserting only that the
        // governor limits were not blown would be tautological -- exceeding one throws
        // an uncatchable LimitException, so reaching an assert already proves it. The
        // real requirement is that instrumentation leaves most of the CPU budget to the
        // business logic it is measuring, so this asserts a delta against a ceiling.
        Integer markCount = 217;
        Integer cpuCeiling = CPU_BUDGET_NUMERATOR * Limits.getLimitCpuTime() / 100;

        Test.startTest();
        Integer cpuBefore = Limits.getCpuTime();
        for (Integer i = 0; i < markCount; i++) {
            Triton.startMark('bulk-' + i);
            Triton.endMark();
        }
        Integer cpuUsed = Limits.getCpuTime() - cpuBefore;
        Test.stopTest();

        System.assertEquals(markCount * 2, buffer().size(), 'N marks emit exactly 2N records');
        System.assert(cpuUsed < cpuCeiling,
            markCount + ' marks must fit inside ' + CPU_BUDGET_NUMERATOR + '% of the CPU limit, '
            + 'leaving the rest to the code being measured. Ceiling ' + cpuCeiling
            + 'ms, used ' + cpuUsed + 'ms');
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
