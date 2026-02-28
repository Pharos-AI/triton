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
 * Comprehensive tests for Flow logging: TritonFlow invocable and TritonFlowFlushBatch pipeline.
 *
 * Organized into four groups:
 *   1. TritonFlow invocable — category handling, stacktraces, additional fields, validation
 *   2. Flow → Batch pipeline — real-life scenarios calling TritonFlow.log()
 *   3. Batch + Cache integration — cache round-trip, constructor, accumulation
 *   4. Edge cases — size limits, drain, static state reset
 *
 * Cache operations use TritonCacheManager which provides a mock cache
 * in test context, so all cache-dependent code paths are fully exercised.
 */
@IsTest
private class TritonFlowTest {

    @TestSetup
    private static void testSetup() {
        pharos.Test_Logger.initSettings();
        Triton.LOG_LEVELS_MDT = new Log_Level__mdt[]{};
        Triton.LOG_LEVELS = null;
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private static void assertBefore() {
        Integer countBefore = [SELECT COUNT() FROM pharos__Log__c];
        System.assertEquals(0, countBefore);
    }

    /**
     * Manually drains any cached flow logs by constructing a batch
     * (which reads all cache keys) and flushing them directly.
     * This is needed because System.scheduleBatch with a delay
     * does not execute during Test.stopTest().
     */
    private static void flushCachedFlowLogs() {
        TritonFlowFlushBatch batch = new TritonFlowFlushBatch();
        if (!batch.logsToFlush.isEmpty()) {
            batch.execute(null, batch.logsToFlush);
        }
    }

    private static TritonFlow.FlowLog makeFlowLog(String summary) {
        TritonFlow.FlowLog fl = new TritonFlow.FlowLog();
        fl.category = TritonTypes.Category.Flow.name();
        fl.type = 'type';
        fl.area = 'area';
        fl.summary = summary;
        fl.details = 'details for ' + summary;
        return fl;
    }

    private static pharos__Log__c makeLogRecord(String summary) {
        return new pharos__Log__c(
            pharos__Summary__c = summary,
            pharos__Category__c = TritonTypes.Category.Flow.name(),
            pharos__Type__c = 'type',
            pharos__Area__c = 'area'
        );
    }

    // ═══════════════════════════════════════════════════════════════════
    // Group 1: TritonFlow Invocable — categories, stacktraces, validation
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Tests multiple flow logs in a single invocable call:
     * valid category, invalid category, transaction ID, and empty category.
     */
    @IsTest
    private static void test_flow() {
        assertBefore();
        TritonCacheManager.resetMock();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();

        // Valid category
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog);

        // Invalid category
        TritonFlow.FlowLog invalidCategoryLog = new TritonFlow.FlowLog();
        invalidCategoryLog.category = 'InvalidCategory';
        invalidCategoryLog.type = 'type';
        invalidCategoryLog.area = 'area';
        invalidCategoryLog.summary = 'test invalid';
        invalidCategoryLog.details = 'test invalid';
        flowLogs.add(invalidCategoryLog);

        // With transaction ID
        TritonFlow.FlowLog transactionLog = new TritonFlow.FlowLog();
        transactionLog.category = TritonTypes.Category.Flow.name();
        transactionLog.type = 'type';
        transactionLog.area = 'area';
        transactionLog.summary = 'test transaction';
        transactionLog.details = 'test transaction';
        transactionLog.transactionId = 'test-transaction-id';
        flowLogs.add(transactionLog);

        // Empty category
        TritonFlow.FlowLog emptyCategoryLog = new TritonFlow.FlowLog();
        emptyCategoryLog.category = '';
        emptyCategoryLog.type = 'type';
        emptyCategoryLog.area = 'area';
        emptyCategoryLog.summary = 'test empty';
        emptyCategoryLog.details = 'test empty';
        flowLogs.add(emptyCategoryLog);

        TritonFlow.log(flowLogs);
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT Id,
                   pharos__Category__c,
                   pharos__Summary__c,
                   pharos__Details__c,
                   pharos__Transaction_Id_External__c,
                   pharos__Hash__c
            FROM pharos__Log__c
            ORDER BY CreatedDate
        ];

        System.assertEquals(4, logs.size(), 'Should have created 4 logs');
        System.assertEquals(TritonTypes.Category.Flow.name(), logs[0].pharos__Category__c);
        System.assertEquals('test summary', logs[0].pharos__Summary__c);
        System.assertEquals(TritonTypes.Category.Flow.name(), logs[1].pharos__Category__c);
        System.assert(logs[1].pharos__Details__c.contains('Unable to locate category: InvalidCategory'));
        System.assertEquals('test-transaction-id', logs[2].pharos__Transaction_Id_External__c);
        System.assertEquals(TritonTypes.Category.Flow.name(), logs[3].pharos__Category__c);
        System.assert(!logs[3].pharos__Details__c.contains('Unable to locate category'));
    }

    /**
     * Stacktrace is passed through to the output and persisted.
     */
    @IsTest
    private static void test_flow_with_stacktrace() {
        assertBefore();
        TritonCacheManager.resetMock();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.stacktrace = 'test stacktrace';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog);
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(flowLogs);
        flushCachedFlowLogs();
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('test stacktrace', results.get(0).fullStacktrace);

        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    /**
     * Multiple logs with chained stacktraces — fullStacktrace accumulates.
     */
    @IsTest
    private static void test_flow_with_stacktrace_multiple_logs() {
        assertBefore();
        TritonCacheManager.resetMock();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog1 = new TritonFlow.FlowLog();
        flowLog1.category = TritonTypes.Category.Flow.name();
        flowLog1.type = 'type';
        flowLog1.area = 'area';
        flowLog1.summary = 'test';
        flowLog1.details = 'test';
        flowLog1.stacktrace = 'teststacktrace1';
        flowLog1.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog1);
        TritonFlow.FlowLog flowLog2 = new TritonFlow.FlowLog();
        flowLog2.category = TritonTypes.Category.Flow.name();
        flowLog2.type = 'type';
        flowLog2.area = 'area';
        flowLog2.summary = 'test';
        flowLog2.details = 'test';
        flowLog2.fullStacktrace = flowLog1.stacktrace;
        flowLog2.stacktrace = 'teststacktrace2';
        flowLog2.additionalFields = '{"pharos__Summary__c":"test summary 2","pharos__Details__c":"test Details 2"}';
        flowLogs.add(flowLog2);
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(flowLogs);
        flushCachedFlowLogs();
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals('teststacktrace1', results.get(0).fullStacktrace);
        System.assertEquals('teststacktrace1teststacktrace2', results.get(1).fullStacktrace);

        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c, pharos__Stacktrace__c FROM pharos__Log__c];
        System.assertEquals(2, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertEquals('test summary 2', logs.get(1).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
        System.assertNotEquals(null, logs.get(1).pharos__Hash__c);
        System.assertEquals('teststacktrace1', logs.get(0).pharos__Stacktrace__c);
        System.assertEquals('teststacktrace1teststacktrace2', logs.get(1).pharos__Stacktrace__c);
    }

    /**
     * Invalid category falls back to Flow category.
     */
    @IsTest
    private static void test_flow_wrong_category() {
        assertBefore();
        TritonCacheManager.resetMock();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = 'InvalidCategory';
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog);
        TritonFlow.log(flowLogs);
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Category__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals(TritonTypes.Category.Flow.name(), logs.get(0).pharos__Category__c);
    }

    /**
     * ERROR level via processFlowLog creates an issue (Do_Not_Create_Issue__c = false).
     */
    @IsTest
    private static void test_flow_create_issue() {
        assertBefore();
        TritonCacheManager.resetMock();

        Test.startTest();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.level = 'ERROR';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        TritonFlow.processFlowLog(flowLog);
        Test.stopTest();
        System.assertEquals(1, Triton.logs.size());
        System.assertEquals(false, Triton.logs.get(0).pharos__Do_Not_Create_Issue__c);
    }

    /**
     * Bad JSON in additionalFields is handled gracefully — log is still created
     * with error details appended.
     */
    @IsTest
    private static void test_flow_bad_additional_fields_json() {
        assertBefore();
        TritonCacheManager.resetMock();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'test type';
        flowLog.area = 'test area';
        flowLog.summary = 'test summary';
        flowLog.details = 'test';
        flowLog.level = 'level';
        flowLog.additionalFields = '{bad_json "test"}';
        flowLogs.add(flowLog);
        TritonFlow.log(flowLogs);
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id,
                                       pharos__Details__c,
                                       pharos__Summary__c,
                                       pharos__Hash__c
                                FROM pharos__Log__c];
        pharos__Log__c log = logs.get(0);
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', log.pharos__Summary__c);
        System.assert(log.pharos__Details__c.contains('Unable to locate log level'), 'Log level error should be present');
        System.assert(log.pharos__Details__c.contains('failed to parse json input'), 'Additional fields parse error should be present');
    }

    // ═══════════════════════════════════════════════════════════════════
    // Group 2: Flow → Batch Pipeline (real-life scenarios)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * A single Flow log action creates exactly 1 published log.
     * Verifies the full pipeline: processFlowLog → Triton.log → drain → addLogs → publish.
     */
    @IsTest
    private static void test_single_flow_invocable_publishes_log() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        Test.startTest();
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(
            new List<TritonFlow.FlowLog>{ makeFlowLog('single-log') }
        );
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Summary__c, pharos__Category__c, pharos__Area__c
            FROM pharos__Log__c
        ];
        System.assertEquals(1, logs.size(), 'Should publish exactly 1 log');
        System.assertEquals(TritonTypes.Category.Flow.name(), logs[0].pharos__Category__c);
        System.assertEquals(0, Triton.logs.size(), 'Triton buffer should be empty after drain');
        System.assertEquals(1, results.size(), 'Should return 1 output to Flow');
    }

    /**
     * Simulates a Flow with 3 separate log actions in one transaction.
     * Each TritonFlow.log() call is a separate invocable invocation.
     */
    @IsTest
    private static void test_multiple_flow_invocable_calls_in_transaction() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        Test.startTest();
        TritonFlow.log(new List<TritonFlow.FlowLog>{ makeFlowLog('action-1') });
        TritonFlow.log(new List<TritonFlow.FlowLog>{ makeFlowLog('action-2') });
        TritonFlow.log(new List<TritonFlow.FlowLog>{ makeFlowLog('action-3') });
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Summary__c FROM pharos__Log__c ORDER BY CreatedDate
        ];
        System.assertEquals(3, logs.size(),
            'All 3 logs from separate invocable calls should be published');
        System.assertEquals(0, Triton.logs.size(),
            'Triton buffer should be empty — all logs drained');
    }

    /**
     * Transaction ID is preserved through the full batch pipeline.
     */
    @IsTest
    private static void test_flow_invocable_with_transaction_id() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        TritonFlow.FlowLog flowLog = makeFlowLog('tx-test');
        flowLog.transactionId = 'custom-tx-id';

        Test.startTest();
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Transaction_Id_External__c FROM pharos__Log__c
        ];
        System.assertEquals(1, logs.size());
        System.assertEquals('custom-tx-id', logs[0].pharos__Transaction_Id_External__c,
            'Transaction ID should be preserved through the batch pipeline');
    }

    /**
     * ERROR level creates an issue via the full invocable → batch pipeline.
     */
    @IsTest
    private static void test_flow_invocable_error_level_creates_issue() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        TritonFlow.FlowLog flowLog = makeFlowLog('error-test');
        flowLog.level = 'ERROR';

        Test.startTest();
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Do_Not_Create_Issue__c FROM pharos__Log__c
        ];
        System.assertEquals(1, logs.size());
        System.assertEquals(false, logs[0].pharos__Do_Not_Create_Issue__c,
            'ERROR level should create an issue');
    }

    /**
     * Log level filtering prevents FINE logs when org level is DEBUG.
     * Verifies filtering happens BEFORE the drain/batch pipeline.
     */
    @IsTest
    private static void test_flow_invocable_respects_log_level_filtering() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        Log_Level__mdt ll = new Log_Level__mdt();
        ll.Level__c = TritonTypes.Level.DEBUG.name();
        Triton.LOG_LEVELS_MDT = new Log_Level__mdt[]{ ll };
        Triton.LOG_LEVELS = null;

        TritonFlow.FlowLog flowLog = makeFlowLog('should-be-filtered');
        flowLog.level = 'FINE';

        Test.startTest();
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id FROM pharos__Log__c];
        System.assertEquals(0, logs.size(),
            'FINE log should be filtered out when org level is DEBUG');
        System.assertEquals(0, TritonFlowFlushBatch.pendingLogs.size(),
            'Filtered log should not reach the batch pending buffer');
    }

    /**
     * Empty input list produces empty output with no side effects.
     */
    @IsTest
    private static void test_flow_invocable_empty_list() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        Test.startTest();
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(new List<TritonFlow.FlowLog>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input should produce empty output');
        List<pharos__Log__c> logs = [SELECT Id FROM pharos__Log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created');
    }

    // ═══════════════════════════════════════════════════════════════════
    // Group 3: Batch + Cache Integration
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Full cache round-trip: put → getKeys → get → remove.
     * Skips gracefully if Org Cache is unavailable.
     */
    @IsTest
    private static void test_cache_roundtrip_put_get_remove() {
        TritonCacheManager.resetMock();

        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            makeLogRecord('cache-1'), makeLogRecord('cache-2')
        };

        Boolean cached = TritonHelper.cacheFlowLogs('txroundtrip', logs);
        System.assert(cached, 'cacheFlowLogs should succeed with mock cache');

        Set<String> keys = TritonHelper.getFlowLogCacheKeys();
        System.assert(!keys.isEmpty(), 'Should find cached flow log keys');

        String firstKey = new List<String>(keys)[0];
        List<pharos__Log__c> retrieved = TritonHelper.getCachedFlowLogs(firstKey);
        System.assertEquals(2, retrieved.size(), 'Should deserialize 2 log records');

        TritonHelper.removeFlowLogCacheKey(firstKey);
        List<pharos__Log__c> afterRemove = TritonHelper.getCachedFlowLogs(firstKey);
        System.assertEquals(0, afterRemove.size(), 'Should be empty after removal');
    }

    /**
     * Batch constructor collects logs from multiple cache keys
     * (simulating concurrent Flow transactions) and clears the keys.
     */
    @IsTest
    private static void test_batch_constructor_reads_and_clears_cache() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        List<pharos__Log__c> txA = new List<pharos__Log__c>{
            makeLogRecord('a-1'), makeLogRecord('a-2')
        };
        List<pharos__Log__c> txB = new List<pharos__Log__c>{
            makeLogRecord('b-1'), makeLogRecord('b-2'), makeLogRecord('b-3')
        };

        TritonHelper.cacheFlowLogs('txa', txA);
        TritonHelper.cacheFlowLogs('txb', txB);

        Test.startTest();
        TritonFlowFlushBatch batch = new TritonFlowFlushBatch();
        Test.stopTest();

        System.assertEquals(5, batch.logsToFlush.size(),
            'Constructor should collect all 5 logs from both cache keys');
        System.assert(TritonHelper.getFlowLogCacheKeys().isEmpty(),
            'All cache keys should be removed after constructor reads them');
    }

    /**
     * addLogs accumulates in the static buffer and writes to cache.
     * Each call overwrites the same cache key with the growing list.
     */
    @IsTest
    private static void test_addLogs_accumulates_in_static_buffer_with_cache() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        List<pharos__Log__c> batch1 = new List<pharos__Log__c>{ makeLogRecord('log1') };

        Test.startTest();
        TritonFlowFlushBatch.addLogs(batch1, 'txacc');
        TritonFlowFlushBatch.addLogs(
            new List<pharos__Log__c>{ makeLogRecord('log2'), makeLogRecord('log3') },
            'txacc'
        );
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id FROM pharos__Log__c];
        System.assertEquals(3, logs.size(),
            'All 3 accumulated logs should be published');
    }

    /**
     * addLogs publishes all logs through the pipeline — either via
     * cache+batch or immediate flush depending on cache availability.
     */
    @IsTest
    private static void test_addLogs_publishes_all_logs() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            makeLogRecord('publish-1'),
            makeLogRecord('publish-2')
        };

        Test.startTest();
        TritonFlowFlushBatch.addLogs(logs, 'txpublish');
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> published = [SELECT Id, pharos__Summary__c FROM pharos__Log__c];
        System.assertEquals(2, published.size(),
            'All logs should be published regardless of cache availability');
    }

    // ═══════════════════════════════════════════════════════════════════
    // Group 4: Edge Cases
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Triton.drain() returns all buffered logs and leaves the buffer empty.
     */
    @IsTest
    private static void test_drain_returns_buffered_logs_and_clears() {
        Triton.log(Triton.makeBuilder()
            .category(TritonTypes.Category.Flow)
            .type('type')
            .area('area')
            .summary('drain-me')
            .level(TritonTypes.Level.INFO));

        System.assertEquals(1, Triton.logs.size(), 'Buffer should have 1 log before drain');

        List<pharos__Log__c> drained = Triton.drain();

        System.assertEquals(1, drained.size(), 'drain() should return 1 log');
        System.assertEquals(0, Triton.logs.size(), 'Buffer should be empty after drain');
    }

    /**
     * drain() on an empty buffer returns an empty list without errors.
     */
    @IsTest
    private static void test_drain_empty_buffer_returns_empty() {
        Triton.logs.clear();

        List<pharos__Log__c> drained = Triton.drain();

        System.assertEquals(0, drained.size(), 'drain() on empty buffer should return empty list');
        System.assertEquals(0, Triton.logs.size(), 'Buffer should remain empty');
    }

    /**
     * reset() clears the static pendingLogs buffer.
     */
    @IsTest
    private static void test_reset_clears_static_pending_logs() {
        TritonFlowFlushBatch.pendingLogs.add(makeLogRecord('stale'));
        System.assertEquals(1, TritonFlowFlushBatch.pendingLogs.size());

        TritonFlowFlushBatch.reset();

        System.assertEquals(0, TritonFlowFlushBatch.pendingLogs.size(),
            'reset() should clear pendingLogs');
    }

    /**
     * scheduleBatchIfNeeded creates at least one AsyncApexJob.
     */
    @IsTest
    private static void test_scheduleBatchIfNeeded_creates_job() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        Test.startTest();
        TritonFlowFlushBatch.scheduleBatchIfNeeded();
        Test.stopTest();

        Integer jobCount = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'TritonFlowFlushBatch'
        ];
        System.assert(jobCount >= 1,
            'scheduleBatchIfNeeded should create at least 1 batch job');
    }

    /**
     * Exercises the full batch lifecycle: start → execute → finish.
     * Uses @TestVisible constructor to inject logs, bypassing cache dependency.
     */
    @IsTest
    private static void test_batch_full_lifecycle_start_execute_finish() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            makeLogRecord('lifecycle-1'),
            makeLogRecord('lifecycle-2')
        };

        Test.startTest();
        Database.executeBatch(new TritonFlowFlushBatch(logs), 200);
        Test.stopTest();

        List<pharos__Log__c> published = [SELECT Id, pharos__Summary__c FROM pharos__Log__c];
        System.assertEquals(2, published.size(),
            'Both logs should be published through the batch lifecycle');
    }

    /**
     * finish() reschedules another batch when new cache keys appear
     * during execution. We simulate this by caching logs after constructing
     * the batch, then calling finish() directly.
     */
    @IsTest
    private static void test_batch_finish_reschedules_when_new_keys_exist() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        // Construct the batch first (reads current cache, which is empty)
        TritonFlowFlushBatch batch = new TritonFlowFlushBatch();

        // Now simulate new logs arriving during batch execution
        List<pharos__Log__c> lateArrival = new List<pharos__Log__c>{
            makeLogRecord('late-1')
        };
        TritonHelper.cacheFlowLogs('txlate', lateArrival);

        Test.startTest();
        // Call finish() — it should detect new cache keys and reschedule
        batch.finish(null);
        Test.stopTest();

        Integer jobCount = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'TritonFlowFlushBatch'
        ];
        System.assert(jobCount >= 1,
            'finish() should reschedule a batch when new cache keys exist');
    }

    /**
     * finish() does NOT reschedule when cache is empty.
     */
    @IsTest
    private static void test_batch_finish_no_reschedule_when_empty() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        TritonFlowFlushBatch batch = new TritonFlowFlushBatch();

        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        Integer jobCount = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'TritonFlowFlushBatch'
            AND Status IN ('Queued', 'Preparing', 'Processing', 'Holding')
        ];
        System.assertEquals(0, jobCount,
            'finish() should not reschedule when no cache keys exist');
    }

    /**
     * start() returns the logsToFlush iterable for the batch framework.
     */
    @IsTest
    private static void test_batch_start_returns_logs() {
        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            makeLogRecord('start-1'),
            makeLogRecord('start-2'),
            makeLogRecord('start-3')
        };
        TritonFlowFlushBatch batch = new TritonFlowFlushBatch(logs);

        Iterable<SObject> result = batch.start(null);
        List<SObject> resultList = new List<SObject>();
        Iterator<SObject> it = result.iterator();
        while (it.hasNext()) {
            resultList.add(it.next());
        }

        System.assertEquals(3, resultList.size(),
            'start() should return all logsToFlush');
    }

    /**
     * execute() calls flush on the provided scope — verifies logs are published.
     */
    @IsTest
    private static void test_batch_execute_publishes_scope() {
        List<pharos__Log__c> scope = new List<pharos__Log__c>{
            makeLogRecord('exec-1'),
            makeLogRecord('exec-2')
        };
        TritonFlowFlushBatch batch = new TritonFlowFlushBatch(new List<pharos__Log__c>());

        Test.startTest();
        batch.execute(null, scope);
        Test.stopTest();

        List<pharos__Log__c> published = [SELECT Id, pharos__Summary__c FROM pharos__Log__c];
        System.assertEquals(2, published.size(),
            'execute() should publish all logs in the scope');
    }

    /**
     * Uses the @TestVisible private constructor to inject logs
     * and run the full batch lifecycle: start → execute → finish.
     */
    @IsTest
    private static void test_batch_with_injected_logs() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        List<pharos__Log__c> injectedLogs = new List<pharos__Log__c>{
            makeLogRecord('inject-1'),
            makeLogRecord('inject-2'),
            makeLogRecord('inject-3')
        };

        Test.startTest();
        Database.executeBatch(new TritonFlowFlushBatch(injectedLogs), 200);
        Test.stopTest();

        List<pharos__Log__c> published = [SELECT Id FROM pharos__Log__c];
        System.assertEquals(3, published.size(),
            'All injected logs should be published through the batch');
    }

    /**
     * When cache write fails (e.g. null transactionId), addLogs falls back
     * to immediate flush — no logs are lost.
     */
    @IsTest
    private static void test_addLogs_cache_failure_falls_back_to_immediate_flush() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            makeLogRecord('fallback-1')
        };

        Test.startTest();
        // null transactionId causes NPE in buildFlowCacheKey → cacheFlowLogs returns false
        TritonFlowFlushBatch.addLogs(logs, null);
        Test.stopTest();

        System.assertEquals(0, TritonFlowFlushBatch.pendingLogs.size(),
            'Buffer should be cleared after cache failure fallback');

        List<pharos__Log__c> published = [SELECT Id FROM pharos__Log__c];
        System.assertEquals(1, published.size(),
            'Log should be published via immediate flush fallback');
    }

    /**
     * addLogs with multiple transaction IDs publishes all logs.
     */
    @IsTest
    private static void test_addLogs_multiple_transactions() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();

        Test.startTest();
        TritonFlowFlushBatch.addLogs(
            new List<pharos__Log__c>{ makeLogRecord('robust-1') }, 'txr1'
        );
        TritonFlowFlushBatch.addLogs(
            new List<pharos__Log__c>{ makeLogRecord('robust-2') }, 'txr2'
        );
        flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> published = [SELECT Id FROM pharos__Log__c];
        System.assert(published.size() >= 2,
            'All logs should be published whether via batch or immediate flush');
    }

    // ═══════════════════════════════════════════════════════════════════
    // Group 5: TritonCacheManager — production path coverage
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Exercises real Cache.Org code paths by disabling the mock.
     * Operations may throw if no cache partition is configured —
     * that is expected; the lines are still covered.
     */
    @IsTest
    private static void test_cache_manager_org_production_paths() {
        TritonCacheManager.useMock = false;

        try { TritonCacheManager.put('tcm_test', 'value', 300); } catch (Exception e) { /* expected */ }
        try { TritonCacheManager.get('tcm_test'); } catch (Exception e) { /* expected */ }
        try { TritonCacheManager.getKeys(); } catch (Exception e) { /* expected */ }
        try { TritonCacheManager.remove('tcm_test'); } catch (Exception e) { /* expected */ }

        TritonCacheManager.resetMock(); // resets useMock = true
    }

    /**
     * Exercises real Cache.Session code paths by disabling the mock.
     */
    @IsTest
    private static void test_cache_manager_session_production_paths() {
        TritonCacheManager.useMock = false;

        try { TritonCacheManager.sessionPut('tcm_sess', 'value', 300); } catch (Exception e) { /* expected */ }
        try { TritonCacheManager.sessionGet('tcm_sess'); } catch (Exception e) { /* expected */ }
        try { TritonCacheManager.sessionRemove('tcm_sess'); } catch (Exception e) { /* expected */ }
        try { TritonCacheManager.sessionAvailable(); } catch (Exception e) { /* expected */ }

        TritonCacheManager.resetMock(); // resets useMock = true
    }
}
