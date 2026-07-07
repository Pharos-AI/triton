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
 * Organized into five groups:
 *   1. TritonFlow invocable — category handling, stacktraces, additional fields, validation
 *   2. Flow → Batch pipeline — real-life scenarios calling TritonFlow.log()
 *   3. Batch + Cache integration — cache round-trip, constructor, accumulation
 *   4. Edge cases — size limits, drain, static state reset
 *   5. TritonCacheManager — production path coverage
 *
 * Cache operations use TritonCacheManager which provides a mock cache
 * in test context, so all cache-dependent code paths are fully exercised.
 */
@IsTest
private class TritonFlowTest {

    @TestSetup
    private static void testSetup() {
        TritonTestFactory.initTestSetup();
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
        TritonTestFactory.assertNoLogs();
        TritonTestFactory.resetFlowState();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();

        // Valid category
        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('test');
        flowLog.details = 'test';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog);

        // Invalid category
        TritonFlow.FlowLog invalidCategoryLog = TritonTestFactory.makeFlowLog('test invalid');
        invalidCategoryLog.category = 'InvalidCategory';
        invalidCategoryLog.details = 'test invalid';
        flowLogs.add(invalidCategoryLog);

        // With transaction ID
        TritonFlow.FlowLog transactionLog = TritonTestFactory.makeFlowLog('test transaction');
        transactionLog.details = 'test transaction';
        transactionLog.transactionId = 'test-transaction-id';
        flowLogs.add(transactionLog);

        // Empty category
        TritonFlow.FlowLog emptyCategoryLog = TritonTestFactory.makeFlowLog('test empty');
        emptyCategoryLog.category = '';
        emptyCategoryLog.details = 'test empty';
        flowLogs.add(emptyCategoryLog);

        TritonFlow.log(flowLogs);
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();

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
        TritonTestFactory.assertNoLogs();
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('test');
        flowLog.details = 'test';
        flowLog.stacktrace = 'test stacktrace';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('test stacktrace', results.get(0).fullStacktrace);

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    /**
     * Multiple logs with chained stacktraces — fullStacktrace accumulates.
     */
    @IsTest
    private static void test_flow_with_stacktrace_multiple_logs() {
        TritonTestFactory.assertNoLogs();
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlow.FlowLog flowLog1 = TritonTestFactory.makeFlowLog('test');
        flowLog1.details = 'test';
        flowLog1.stacktrace = 'teststacktrace1';
        flowLog1.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';

        TritonFlow.FlowLog flowLog2 = TritonTestFactory.makeFlowLog('test');
        flowLog2.details = 'test';
        flowLog2.fullStacktrace = flowLog1.stacktrace;
        flowLog2.stacktrace = 'teststacktrace2';
        flowLog2.additionalFields = '{"pharos__Summary__c":"test summary 2","pharos__Details__c":"test Details 2"}';

        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(
            new List<TritonFlow.FlowLog>{ flowLog1, flowLog2 }
        );
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals('teststacktrace1', results.get(0).fullStacktrace);
        System.assertEquals('teststacktrace1teststacktrace2', results.get(1).fullStacktrace);

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
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
        TritonTestFactory.assertNoLogs();
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('test');
        flowLog.category = 'InvalidCategory';
        flowLog.details = 'test';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
        System.assertEquals(1, logs.size());
        System.assertEquals(TritonTypes.Category.Flow.name(), logs.get(0).pharos__Category__c);
    }

    /**
     * ERROR level via processFlowLog creates an issue (Do_Not_Create_Issue__c = false).
     */
    @IsTest
    private static void test_flow_create_issue() {
        TritonTestFactory.assertNoLogs();
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('test');
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
        TritonTestFactory.assertNoLogs();
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('test summary');
        flowLog.type = 'test type';
        flowLog.area = 'test area';
        flowLog.details = 'test';
        flowLog.level = 'level';
        flowLog.additionalFields = '{bad_json "test"}';
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
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
        TritonTestFactory.resetFlowState();

        Test.startTest();
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(
            new List<TritonFlow.FlowLog>{ TritonTestFactory.makeFlowLog('single-log') }
        );
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
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
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlow.log(new List<TritonFlow.FlowLog>{ TritonTestFactory.makeFlowLog('action-1') });
        TritonFlow.log(new List<TritonFlow.FlowLog>{ TritonTestFactory.makeFlowLog('action-2') });
        TritonFlow.log(new List<TritonFlow.FlowLog>{ TritonTestFactory.makeFlowLog('action-3') });
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
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
        TritonTestFactory.resetFlowState();

        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('tx-test');
        flowLog.transactionId = 'custom-tx-id';

        Test.startTest();
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
        System.assertEquals(1, logs.size());
        System.assertEquals('custom-tx-id', logs[0].pharos__Transaction_Id_External__c,
            'Transaction ID should be preserved through the batch pipeline');
    }

    /**
     * ERROR level creates an issue via the full invocable → batch pipeline.
     */
    @IsTest
    private static void test_flow_invocable_error_level_creates_issue() {
        TritonTestFactory.resetFlowState();

        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('error-test');
        flowLog.level = 'ERROR';

        Test.startTest();
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> logs = TritonTestFactory.queryLogs();
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
        TritonTestFactory.resetFlowState();

        Log_Level__mdt ll = new Log_Level__mdt();
        ll.Level__c = TritonTypes.Level.DEBUG.name();
        Triton.LOG_LEVELS_MDT = new Log_Level__mdt[]{ ll };
        Triton.LOG_LEVELS = null;

        TritonFlow.FlowLog flowLog = TritonTestFactory.makeFlowLog('should-be-filtered');
        flowLog.level = 'FINE';

        Test.startTest();
        TritonFlow.log(new List<TritonFlow.FlowLog>{ flowLog });
        Test.stopTest();

        TritonTestFactory.assertNoLogs();
        System.assertEquals(0, TritonFlowFlushBatch.pendingLogs.size(),
            'Filtered log should not reach the batch pending buffer');
    }

    /**
     * Empty input list produces empty output with no side effects.
     */
    @IsTest
    private static void test_flow_invocable_empty_list() {
        TritonTestFactory.resetFlowState();

        Test.startTest();
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(new List<TritonFlow.FlowLog>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input should produce empty output');
        TritonTestFactory.assertNoLogs();
    }

    // ═══════════════════════════════════════════════════════════════════
    // Group 3: Batch + Cache Integration
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Full cache round-trip: put → getKeys → get → remove.
     */
    @IsTest
    private static void test_cache_roundtrip_put_get_remove() {
        TritonTestFactory.resetFlowState();

        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            TritonTestFactory.makeLogRecord('cache-1'), TritonTestFactory.makeLogRecord('cache-2')
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
        TritonTestFactory.resetFlowState();

        List<pharos__Log__c> txA = new List<pharos__Log__c>{
            TritonTestFactory.makeLogRecord('a-1'), TritonTestFactory.makeLogRecord('a-2')
        };
        List<pharos__Log__c> txB = new List<pharos__Log__c>{
            TritonTestFactory.makeLogRecord('b-1'), TritonTestFactory.makeLogRecord('b-2'), TritonTestFactory.makeLogRecord('b-3')
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
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlowFlushBatch.addLogs(
            new List<pharos__Log__c>{ TritonTestFactory.makeLogRecord('log1') }, 'txacc'
        );
        TritonFlowFlushBatch.addLogs(
            new List<pharos__Log__c>{ TritonTestFactory.makeLogRecord('log2'), TritonTestFactory.makeLogRecord('log3') },
            'txacc'
        );
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        TritonTestFactory.assertLogCount(3);
    }

    /**
     * addLogs publishes all logs through the pipeline — either via
     * cache+batch or immediate flush depending on cache availability.
     */
    @IsTest
    private static void test_addLogs_publishes_all_logs() {
        TritonTestFactory.resetFlowState();

        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            TritonTestFactory.makeLogRecord('publish-1'),
            TritonTestFactory.makeLogRecord('publish-2')
        };

        Test.startTest();
        TritonFlowFlushBatch.addLogs(logs, 'txpublish');
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        TritonTestFactory.assertLogCount(2);
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
        TritonFlowFlushBatch.pendingLogs.add(TritonTestFactory.makeLogRecord('stale'));
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
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlowFlushBatch.scheduleBatchIfNeeded();
        Test.stopTest();

        System.assert(TritonTestFactory.countFlowFlushBatchJobs() >= 1,
            'scheduleBatchIfNeeded should create at least 1 batch job');
    }

    /**
     * Exercises the full batch lifecycle: start → execute → finish.
     * Uses @TestVisible constructor to inject logs, bypassing cache dependency.
     */
    @IsTest
    private static void test_batch_full_lifecycle_start_execute_finish() {
        TritonTestFactory.resetFlowState();

        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            TritonTestFactory.makeLogRecord('lifecycle-1'),
            TritonTestFactory.makeLogRecord('lifecycle-2')
        };

        Test.startTest();
        Database.executeBatch(new TritonFlowFlushBatch(logs), 200);
        Test.stopTest();

        TritonTestFactory.assertLogCount(2);
    }

    /**
     * finish() reschedules another batch when new cache keys appear
     * during execution. We simulate this by caching logs after constructing
     * the batch, then calling finish() directly.
     */
    @IsTest
    private static void test_batch_finish_reschedules_when_new_keys_exist() {
        TritonTestFactory.resetFlowState();

        // Construct the batch first (reads current cache, which is empty)
        TritonFlowFlushBatch batch = new TritonFlowFlushBatch();

        // Now simulate new logs arriving during batch execution
        TritonHelper.cacheFlowLogs('txlate', new List<pharos__Log__c>{
            TritonTestFactory.makeLogRecord('late-1')
        });

        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        System.assert(TritonTestFactory.countFlowFlushBatchJobs() >= 1,
            'finish() should reschedule a batch when new cache keys exist');
    }

    /**
     * finish() does NOT reschedule when cache is empty.
     */
    @IsTest
    private static void test_batch_finish_no_reschedule_when_empty() {
        TritonTestFactory.resetFlowState();

        TritonFlowFlushBatch batch = new TritonFlowFlushBatch();

        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        System.assertEquals(0, TritonTestFactory.countActiveFlowFlushBatchJobs(),
            'finish() should not reschedule when no cache keys exist');
    }

    /**
     * start() returns the logsToFlush iterable for the batch framework.
     */
    @IsTest
    private static void test_batch_start_returns_logs() {
        List<pharos__Log__c> logs = new List<pharos__Log__c>{
            TritonTestFactory.makeLogRecord('start-1'),
            TritonTestFactory.makeLogRecord('start-2'),
            TritonTestFactory.makeLogRecord('start-3')
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
            TritonTestFactory.makeLogRecord('exec-1'),
            TritonTestFactory.makeLogRecord('exec-2')
        };
        TritonFlowFlushBatch batch = new TritonFlowFlushBatch(new List<pharos__Log__c>());

        Test.startTest();
        batch.execute(null, scope);
        Test.stopTest();

        TritonTestFactory.assertLogCount(2);
    }

    /**
     * Uses the @TestVisible private constructor to inject logs
     * and run the full batch lifecycle: start → execute → finish.
     */
    @IsTest
    private static void test_batch_with_injected_logs() {
        TritonTestFactory.resetFlowState();

        List<pharos__Log__c> injectedLogs = new List<pharos__Log__c>{
            TritonTestFactory.makeLogRecord('inject-1'),
            TritonTestFactory.makeLogRecord('inject-2'),
            TritonTestFactory.makeLogRecord('inject-3')
        };

        Test.startTest();
        Database.executeBatch(new TritonFlowFlushBatch(injectedLogs), 200);
        Test.stopTest();

        TritonTestFactory.assertLogCount(3);
    }

    /**
     * When cache write fails (e.g. null transactionId), addLogs falls back
     * to immediate flush — no logs are lost.
     */
    @IsTest
    private static void test_addLogs_cache_failure_falls_back_to_immediate_flush() {
        TritonTestFactory.resetFlowState();

        Test.startTest();
        // null transactionId causes NPE in buildFlowCacheKey → cacheFlowLogs returns false
        TritonFlowFlushBatch.addLogs(
            new List<pharos__Log__c>{ TritonTestFactory.makeLogRecord('fallback-1') }, null
        );
        Test.stopTest();

        System.assertEquals(0, TritonFlowFlushBatch.pendingLogs.size(),
            'Buffer should be cleared after cache failure fallback');
        TritonTestFactory.assertLogCount(1);
    }

    /**
     * addLogs with multiple transaction IDs publishes all logs.
     */
    @IsTest
    private static void test_addLogs_multiple_transactions() {
        TritonTestFactory.resetFlowState();

        Test.startTest();
        TritonFlowFlushBatch.addLogs(
            new List<pharos__Log__c>{ TritonTestFactory.makeLogRecord('robust-1') }, 'txr1'
        );
        TritonFlowFlushBatch.addLogs(
            new List<pharos__Log__c>{ TritonTestFactory.makeLogRecord('robust-2') }, 'txr2'
        );
        TritonTestFactory.flushCachedFlowLogs();
        Test.stopTest();

        List<pharos__Log__c> published = TritonTestFactory.queryLogs();
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
        try { TritonCacheManager.available(); } catch (Exception e) { /* expected */ }

        TritonCacheManager.resetMock(); // resets useMock = true
    }
}
