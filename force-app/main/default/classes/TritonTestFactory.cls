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
 * Shared test infrastructure for Triton test classes.
 * Provides setup, record creation, flush helpers, query helpers,
 * and assertion methods to eliminate duplication across test files.
 */
@IsTest
public class TritonTestFactory {

    // ─── Setup ───────────────────────────────────────────────────────

    /**
     * Standard test setup logic. Called from each test class's @TestSetup.
     * Initializes pharos test settings and clears log level metadata.
     */
    public static void initTestSetup() {
        pharos.Test_Logger.initSettings();
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{};
        TritonHelper.Config.logLevels = null;
    }

    // ─── State Reset ────────────────────────────────────────────────

    /**
     * Resets Flow-related static state: TritonFlowFlushBatch pending buffer
     * and TritonCacheManager mock cache.
     */
    public static void resetFlowState() {
        TritonFlowFlushBatch.reset();
        TritonCacheManager.resetMock();
    }

    // ─── Record Creation ────────────────────────────────────────────

    /**
     * Creates a TritonFlow.FlowLog with standard test defaults.
     * Category: Flow, type: 'type', area: 'area', details: 'details for {summary}'.
     */
    public static TritonFlow.FlowLog makeFlowLog(String summary) {
        TritonFlow.FlowLog fl = new TritonFlow.FlowLog();
        fl.category = TritonTypes.Category.Flow.name();
        fl.type = 'type';
        fl.area = 'area';
        fl.summary = summary;
        fl.details = 'details for ' + summary;
        return fl;
    }

    /**
     * Creates a pharos__Log__c record with standard test defaults.
     * Category: Flow, type: 'type', area: 'area'.
     */
    public static pharos__Log__c makeLogRecord(String summary) {
        return new pharos__Log__c(
            pharos__Summary__c = summary,
            pharos__Category__c = TritonTypes.Category.Flow.name(),
            pharos__Type__c = 'type',
            pharos__Area__c = 'area'
        );
    }

    // ─── Flush ──────────────────────────────────────────────────────

    /**
     * Manually drains any cached flow logs by constructing a batch
     * (which reads all cache keys) and flushing them directly.
     * Needed because System.scheduleBatch with a delay does not execute
     * during Test.stopTest().
     */
    public static void flushCachedFlowLogs() {
        TritonFlowFlushBatch batch = new TritonFlowFlushBatch();
        if (!batch.logsToFlush.isEmpty()) {
            batch.execute(null, batch.logsToFlush);
        }
    }

    // ─── Assertions ─────────────────────────────────────────────────

    /**
     * Asserts that no pharos__Log__c records exist.
     */
    public static void assertNoLogs() {
        Integer count = [SELECT COUNT() FROM pharos__Log__c];
        System.assertEquals(0, count, 'Expected no log records to exist');
    }

    /**
     * Asserts that exactly the expected number of logs were created.
     */
    public static void assertLogCount(Integer expected) {
        Integer count = [SELECT COUNT() FROM pharos__Log__c];
        System.assertEquals(expected, count,
            'Expected ' + expected + ' log(s), found ' + count);
    }

    /**
     * Asserts exactly 1 log was created with a valid hash, in the given category.
     */
    public static pharos__Log__c assertSingleLog(TritonTypes.Category expectedCategory) {
        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Category__c, pharos__Hash__c
            FROM pharos__Log__c
        ];
        System.assertEquals(1, logs.size(), 'Expected exactly 1 log');
        System.assertNotEquals(null, logs[0].pharos__Hash__c, 'Hash should be populated');
        return logs[0];
    }

    // ─── Query Helpers ──────────────────────────────────────────────

    /**
     * Returns all pharos__Log__c records with commonly queried fields.
     * Consolidates many different SELECT variants into one reusable query.
     */
    public static List<pharos__Log__c> queryLogs() {
        return [
            SELECT Id,
                   pharos__Category__c,
                   pharos__Type__c,
                   pharos__Area__c,
                   pharos__Summary__c,
                   pharos__Details__c,
                   pharos__Hash__c,
                   pharos__Stacktrace__c,
                   pharos__Transaction_Id_External__c,
                   pharos__Do_Not_Create_Issue__c,
                   Log_Level__c
            FROM pharos__Log__c
            ORDER BY CreatedDate
        ];
    }

    /**
     * Returns the count of TritonFlowFlushBatch async apex jobs.
     */
    public static Integer countFlowFlushBatchJobs() {
        return [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = :TritonFlowFlushBatch.BATCH_CLASS_NAME
        ];
    }

    /**
     * Returns the count of active (queued/processing) TritonFlowFlushBatch jobs.
     */
    public static Integer countActiveFlowFlushBatchJobs() {
        return [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = :TritonFlowFlushBatch.BATCH_CLASS_NAME
            AND Status IN :TritonFlowFlushBatch.ACTIVE_BATCH_STATUSES
        ];
    }
}
