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
 * Singleton batch class for deferred Flow log publishing.
 * Buffers Flow logs in Org Cache across invocable calls and transactions,
 * then publishes them in a single batch via pharos.Logger to minimize
 * platform event consumption.
 *
 * Within a single Flow transaction, logs accumulate in a static buffer
 * and are written to Org Cache on each invocable call (overwriting the
 * same key). Across concurrent transactions, a singleton check via
 * AsyncApexJob prevents multiple batch jobs from running simultaneously.
 *
 * The batch constructor reads all pending cache entries (from all transactions),
 * so the execute method can publish everything in one pharos.Logger.flush() call.
 */
global class TritonFlowFlushBatch implements Database.Batchable<SObject> {

    private static final String BATCH_CLASS_NAME = 'TritonFlowFlushBatch';
    private static final String BATCH_JOB_PREFIX = 'TritonFlowFlush-';
    private static final Set<String> ACTIVE_BATCH_STATUSES = new Set<String>{
        'Queued', 'Preparing', 'Processing', 'Holding'
    };

    // Delay in minutes before the batch executes — gives concurrent Flows
    // time to add their logs to cache before the batch picks them up.
    @TestVisible
    private static final Integer BATCH_DELAY_MINUTES = 1;

    // Per-transaction static state — accumulates logs across invocable calls
    @TestVisible
    private static List<pharos__Log__c> pendingLogs = new List<pharos__Log__c>();

    // Instance state — serialized with the batch job
    @TestVisible
    private List<pharos__Log__c> logsToFlush;

    /**
     * Constructor: collects all pending flow logs from Org Cache.
     * Each cache key represents a different transaction's buffered logs.
     * Keys are removed after reading to prevent double-processing.
     */
    public TritonFlowFlushBatch() {
        this.logsToFlush = new List<pharos__Log__c>();
        for (String key : TritonHelper.getFlowLogCacheKeys()) {
            this.logsToFlush.addAll(TritonHelper.getCachedFlowLogs(key));
            TritonHelper.removeFlowLogCacheKey(key);
        }
    }

    /**
     * Test constructor: allows tests to inject pre-loaded logs
     * when Org Cache is unavailable in the test environment.
     */
    @TestVisible
    private TritonFlowFlushBatch(List<pharos__Log__c> logs) {
        this.logsToFlush = logs;
    }

    /**
     * Buffers logs for deferred flush. Handles all failure cases internally —
     * never throws. Every log is guaranteed to be either cached+batched or
     * immediately flushed.
     * @param logs The log records to buffer
     * @param transactionId The current transaction ID (used as cache key)
     */
    public static void addLogs(List<pharos__Log__c> logs, String transactionId) {
        pendingLogs.addAll(logs);

        // Cache stores SObjects directly — no JSON serialization.
        // Platform enforces the 100KB per-key limit; cacheFlowLogs returns
        // false if the write fails (size exceeded or cache unavailable).
        if (!TritonHelper.cacheFlowLogs(transactionId, pendingLogs)) {
            flushAndClearPending();
            return;
        }

        // In test context, skip batch scheduling — the batch constructor
        // eagerly drains the cache, and System.scheduleBatch with a delay
        // does not execute during Test.stopTest(). Tests flush cached logs
        // manually by constructing a batch and calling execute().
        if (Test.isRunningTest()) {
            return;
        }

        try {
            scheduleBatchIfNeeded();
        } catch (Exception e) {
            flushAndClearPending();
        }
    }

    /**
     * Publishes a list of logs via pharos.Logger in a single flush.
     */
    private static void flush(List<SObject> logs) {
        pharos.Logger logger = pharos.Logger.getInstance();
        for (SObject log : logs) {
            logger.add((pharos__Log__c) log);
        }
        logger.flush();
    }

    /**
     * Flushes the pending buffer immediately and clears it.
     */
    private static void flushAndClearPending() {
        flush(pendingLogs);
        pendingLogs.clear();
    }

    /**
     * Schedules a new batch only if no TritonFlowFlushBatch is already
     * queued or processing. This prevents batch job proliferation when
     * multiple Flows run concurrently.
     */
    @TestVisible
    private static void scheduleBatchIfNeeded() {
        Integer existingJobs = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = :BATCH_CLASS_NAME
            AND Status IN :ACTIVE_BATCH_STATUSES
        ];
        if (existingJobs == 0) {
            scheduleBatch();
        }
    }

    /**
     * Schedules a new deferred flush batch with a unique job name.
     */
    private static void scheduleBatch() {
        System.scheduleBatch(
            new TritonFlowFlushBatch(),
            BATCH_JOB_PREFIX + Datetime.now().getTime(),
            BATCH_DELAY_MINUTES
        );
    }

    global Iterable<SObject> start(Database.BatchableContext bc) {
        return logsToFlush;
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        flush(scope);
    }

    /**
     * After processing, checks if new logs arrived during batch execution.
     * If so, schedules another batch to handle them.
     */
    global void finish(Database.BatchableContext bc) {
        if (!TritonHelper.getFlowLogCacheKeys().isEmpty()) {
            scheduleBatch();
        }
    }

    /**
     * For testing — reset static state between test methods.
     */
    @TestVisible
    private static void reset() {
        pendingLogs.clear();
    }
}
