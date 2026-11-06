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
 *
 * Never throws into the Flow. If a batch cannot be scheduled, every log its
 * constructor drained is published immediately instead; a publish that fails drops
 * the logs it carried (see TritonHelper.publishLogs).
 */
global class TritonFlowFlushBatch implements Database.Batchable<SObject> {

    @TestVisible
    private static final String BATCH_CLASS_NAME = 'TritonFlowFlushBatch';
    private static final String BATCH_JOB_PREFIX = 'TritonFlowFlush-';
    @TestVisible
    private static final Set<String> ACTIVE_BATCH_STATUSES = new Set<String>{
        'Queued', 'Preparing', 'Processing', 'Holding'
    };

    // Per-transaction static state — accumulates logs across invocable calls
    @TestVisible
    private static List<pharos__Log__c> pendingLogs = new List<pharos__Log__c>();

    // Instance state — serialized with the batch job
    @TestVisible
    private List<pharos__Log__c> logsToFlush;

    /** Test seam: when set, scheduleBatch throws it inside its own guard. Only tests set it. */
    @TestVisible
    private static Exception scheduleFault;

    /** Test seam: lets a test reach the scheduling path, which addLogs skips in tests by default. */
    @TestVisible
    private static Boolean scheduleInTests = false;

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
     * Buffers logs for deferred flush. Never throws. Each log is cached for a batch,
     * handed to a scheduled batch, or published immediately; a publish that fails
     * drops the logs it carried (see TritonHelper.publishLogs).
     * @param logs The log records to buffer
     * @param transactionId The current transaction ID (used as cache key)
     */
    public static void addLogs(List<pharos__Log__c> logs, String transactionId) {
        if (logs == null || logs.isEmpty()) return;
        try {
            pendingLogs.addAll(logs);

            // Cache stores SObjects directly — no JSON serialization.
            // Platform enforces the 100KB per-key limit; cacheFlowLogs returns
            // false if the write fails (size exceeded or cache unavailable).
            if (!TritonHelper.cacheFlowLogs(transactionId, pendingLogs)) {
                publishPendingNow(transactionId);
                return;
            }

            // In test context, skip batch scheduling unless a test opts in — the
            // batch constructor eagerly drains the cache, and System.scheduleBatch
            // with a delay does not execute during Test.stopTest(). Tests flush cached
            // logs manually by constructing a batch and calling execute().
            if (Test.isRunningTest() && !scheduleInTests) {
                return;
            }

            if (scheduleBatchIfNeeded()) {
                // The constructor drained this transaction's key (and every other one):
                // those logs now belong to the scheduled batch, or scheduleBatch has
                // already published them. Keeping them would cache them again.
                pendingLogs.clear();
            }
        } catch (Exception e) {
            TritonHelper.recordFailure('flow batch hand-off', e, 0);
            publishPendingNow(transactionId);
        }
    }

    /**
     * Publishes a list of logs in a single flush, through TritonHelper.publishLogs.
     * Never throws: a failed publish drops the logs and is written to the debug log.
     */
    private static void flush(List<SObject> logs) {
        List<pharos__Log__c> records = new List<pharos__Log__c>();
        for (SObject log : logs) {
            records.add((pharos__Log__c) log);
        }
        TritonHelper.publishLogs(records);
    }

    /**
     * Publishes this transaction's pending logs now and clears the buffer. Removes the
     * transaction's cache key first, so no later batch republishes them: an earlier call
     * in this transaction may have cached some of them even when the latest write failed.
     * @param transactionId The transaction whose cache key to remove (null-safe)
     */
    private static void publishPendingNow(String transactionId) {
        TritonHelper.removeFlowLogs(transactionId);
        List<pharos__Log__c> toPublish = new List<pharos__Log__c>(pendingLogs);
        pendingLogs.clear();
        TritonHelper.publishLogs(toPublish);
    }

    /**
     * Schedules a new batch only if no TritonFlowFlushBatch is already
     * queued or processing. This prevents batch job proliferation when
     * multiple Flows run concurrently.
     * @return true when it constructed (and so drained the cache into) a batch
     */
    @TestVisible
    private static Boolean scheduleBatchIfNeeded() {
        Integer existingJobs = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = :BATCH_CLASS_NAME
            AND Status IN :ACTIVE_BATCH_STATUSES
        ];
        if (existingJobs > 0) {
            return false;
        }
        scheduleBatch();
        return true;
    }

    /**
     * Schedules a new deferred flush batch with a unique job name. Never throws:
     * the constructor has already removed every cache key it read, so this instance
     * holds the only copy of those logs, and a failed schedule publishes them now.
     */
    @TestVisible
    private static void scheduleBatch() {
        TritonFlowFlushBatch batch = null;
        try {
            batch = new TritonFlowFlushBatch(); // removes every key it reads
            if (scheduleFault != null) throw scheduleFault;
            System.scheduleBatch(
                batch,
                BATCH_JOB_PREFIX + Datetime.now().getTime(),
                TritonHelper.Config.getFlowFlushBatchDelayMinutes()
            );
        } catch (Exception e) {
            TritonHelper.recordFailure('flow batch schedule', e, 0);
            if (batch != null) {
                TritonHelper.publishLogs(batch.logsToFlush);
            }
        }
    }

    global Iterable<SObject> start(Database.BatchableContext bc) {
        return logsToFlush;
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        flush(scope);
    }

    /**
     * After processing, checks if new logs arrived during batch execution.
     * If so, schedules another batch to handle them; if that schedule fails,
     * they are published immediately (see scheduleBatch).
     */
    global void finish(Database.BatchableContext bc) {
        if (!TritonHelper.getFlowLogCacheKeys().isEmpty()) {
            scheduleBatch();
        }
    }

    /**
     * For testing — reset static state and the test seams between test methods.
     */
    @TestVisible
    private static void reset() {
        pendingLogs.clear();
        scheduleFault = null;
        scheduleInTests = false;
    }
}
