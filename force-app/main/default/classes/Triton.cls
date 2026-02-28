/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 *
 * The Triton class provides a robust logging framework for Salesforce applications.
 * It uses a fluent builder pattern for constructing structured logs with different
 * severity levels (ERROR, WARNING, DEBUG, INFO), categories, types, and functional areas.
 *
 * Key features:
 * - Unified builder-pattern API
 * - Buffered (log) and immediate (logNow) logging
 * - Automatic stack trace capture
 * - Transaction tracking across multiple Salesforce contexts
 * - Configurable log levels via Custom Metadata
 * - Template pattern for reusable log configurations
 *
 * Basic usage:
 *   Triton.log(Triton.t
 *       .category(Category.Apex)
 *       .type(Type.Backend)
 *       .area(Area.Accounts)
 *       .summary('Operation completed')
 *       .level(Level.INFO));
 *   Triton.flush();
 *
 * For critical errors that need immediate persistence:
 *   Triton.logNow(Triton.t
 *       .summary('Critical failure')
 *       .exception(e)
 *       .level(Level.ERROR));
 */

global with sharing class Triton {

    public static final String SPACE_SEP = '\n\n';

    /**
     * Underlying pharos Logger instance — lazy-initialized.
     */
    @TestVisible
    private static pharos.Logger logger {
        get {
            if (logger == null) {
                logger = pharos.Logger.getInstance();
            }
            return logger;
        }
        private set;
    }

    /**
    * Helper map for storing current log levels
    */
    @TestVisible
    private static Map<String, TritonTypes.Level> LOG_LEVELS {
        get {
            if (LOG_LEVELS == null) {
                LOG_LEVELS = new Map<String, TritonTypes.Level>();
                for(Log_Level__mdt ll : LOG_LEVELS_MDT) {
                    LOG_LEVELS.put(
                            TritonHelper.buildLogLevelKey(ll.Category__c, ll.Type__c, ll.Area__c),
                            TritonTypes.Level.valueOf(ll.Level__c));
                }
            }
            return LOG_LEVELS;
        }
        set;
    }

    @TestVisible
    private static Log_Level__mdt[] LOG_LEVELS_MDT = Log_Level__mdt.getAll().values();

    private static TritonBuilder template {
        get {
            if (template == null) {
                template = new TritonBuilder();
            }
            return template;
        }
        set;
    }

    // Logs buffer (queue) property
    @TestVisible
    private static List<pharos__Log__c> logs {
        get {
            if (logs == null) {
                logs = new List<pharos__Log__c>();
            }
            return logs;
        }
        set;
    }

    /**
     * Indicates whether platform cache is available for transaction management
     */
    @TestVisible
    private static Boolean CACHE_AVAILABLE {
        get {
            if (CACHE_AVAILABLE == null) {
                CACHE_AVAILABLE = TritonCacheManager.sessionAvailable();
            }
            return CACHE_AVAILABLE;
        }
        private set;
    }

    /**
     * Indicates whether platform cache should be used for transaction management
     */
    @TestVisible
    private static Boolean cacheEnabled = false;

    /**
     * This value can be passed around to trace a complex process spanning multiple Salesforce transactions
     * Can be used between LWC/Apex/Flow transitions when complex tracing is required.
     */
    public static String TRANSACTION_ID;

    /**
     * Enables platform cache for transaction management
     */
    public static void withCache() {
        if (!CACHE_AVAILABLE) {
            cacheEnabled = false;
            if (TRANSACTION_ID == null) {
                startTransaction();
            }
            return;
        }

        cacheEnabled = true;
        String transactionId = TritonHelper.getCachedTransactionId();
        if (String.isNotBlank(transactionId)) {
            resumeTransaction(transactionId);
        } else if(TRANSACTION_ID == null) {
            startTransaction();
        }
    }

    /**
    * Sets a builder template that can be re-used
    * @param builder -- Pharos builder to be used as a template
    */
    public static void setTemplate(TritonBuilder builder) {
        template = builder;
    }

    /**
    * Retrieves a copy of a previously saved template
    * @return builder -- Pharos builder previously saved as a template
    */
    public static TritonBuilder fromTemplate() {
        return (TritonBuilder)template.cloneBuilder()
                .transactionId(TRANSACTION_ID);
    }

    /**
    * Persist Log records immediately.
    * Use this method to persist logs to the database right away.
    * If platform event allocation is near capacity (95%), logs will be scheduled
    * for delayed publishing with exponential backoff using a singleton batch.
    */
    public static void flush() {
        // Check if we have any logs to flush
        if (logs.isEmpty()) {
            return;
        }

        for(pharos__Log__c log : logs) {
            logger.add(log);
        }
        logger.flush();
        logs.clear();
    }

    /**
    * Returns all buffered logs and clears the internal buffer.
    * Used by TritonFlow to hand off logs to the deferred flush batch
    * without publishing them immediately.
    * @return List of buffered log records
    */
    public static List<pharos__Log__c> drain() {
        List<pharos__Log__c> drained = new List<pharos__Log__c>(logs);
        logs.clear();
        return drained;
    }

    /**
    * Persist the last Log in the queue only, immediately.
    * Use this method to persist a single log to the database right away.
    * If platform event allocation is near capacity (95%), the log will be scheduled
    * for delayed publishing with exponential backoff using a singleton batch.
    */
    public static void flushTop() {
        if (logs.size() == 0) {
            return;
        }

        logger.add(logs.get(logs.size() - 1));
        logger.flush();
        logs.remove(logs.size() - 1);
    }

    /**
    * Shorthand method for creating a new builder with default category set to Apex
    */
    public static TritonBuilder makeBuilder() {
        return new TritonBuilder().category(TritonTypes.Category.Apex);
    }

    /**
     * Shorthand static property for creating a builder from template
     * Usage: Triton.log(Triton.t.summary('test').details('test'))
     */
    public static TritonBuilder t {
        get {
            return fromTemplate();
        }
    }

    /**
    * Shorthand method for creating a new post processing controls builder
    */
    public static TritonHelper.PostProcessingControlsBuilder makePostProcessingBuilder() {
        return new TritonHelper.PostProcessingControlsBuilder();
    }

    /**
     * Start new transaction
     * Autogenrated Transaction UUID
     * This method will obtain a new autogenrated transaction id or use the current one
     */
    public static String startTransaction() {
        TRANSACTION_ID = TritonHelper.generateUUID4();
        if (cacheEnabled) {
            TritonHelper.cacheTransactionId(TRANSACTION_ID);
        }
        return TRANSACTION_ID;
    }

    /**
     * Resumes a transaction
     * Assumes an existing transaction id
     * Use this method to tie together different Salesforce transactions.
     */
    public static void resumeTransaction(String transactionId) {
        if (cacheEnabled) {
            //cache the transaction id, even if it's the same as the current one to extend the TTL
            TritonHelper.cacheTransactionId(transactionId);
        }
        TRANSACTION_ID = transactionId;
    }

    /**
     * Stops a transaction
     * Resets the current transaction Id
     * Use this method to marking tracking logs with the current transaction Id
     */
    public static void stopTransaction() {
        TRANSACTION_ID = null;
        if (cacheEnabled) {
            TritonHelper.clearCachedTransactionId();
        }
    }

    /**
     * ---------------------------
     * Log methods.
     * ---------------------------
     *
     * log(builder)    - Buffers log for later flush
     * logNow(builder) - Immediately flushes log
     *
     * Use Triton.t as shorthand for Triton.fromTemplate()
     *
     * Examples:
     *   Triton.log(Triton.t.summary('Info').level(Level.INFO));
     *   Triton.logNow(Triton.t.summary('Error').level(Level.ERROR).exception(e));
     */

    /**
    * Adds a log to the buffer
    * @param builder TritonBuilder instance containing log details
    */
    public static void log(TritonBuilder builder) {
        pharos__Log__c log = builder.build();

        if (!isLogAllowedForLogLevel(log)) {
            return;
        }

        builder.prepareForLogging(TRANSACTION_ID);
        logs.add(builder.build());
    }

    /**
    * Adds a log to the buffer and immediately flushes it
    * @param builder TritonBuilder instance containing log details
    */
    public static void logNow(TritonBuilder builder) {
        log(builder);
        flushTop();
    }

    /**
    * Checks if a log should be persisted based on the current log level
    * @param log -- Pharos log record to be saved
    */
    public static Boolean isLogAllowedForLogLevel(pharos__Log__c log) {
        if (String.isBlank(log.Log_Level__c) || LOG_LEVELS.isEmpty()) return true;

        //a set of possible mapping permutations
        //these will be checked in the same order as this list
        String[] permutations = new String[] {
                TritonHelper.buildLogLevelKey(log.pharos__Category__c, log.pharos__Type__c, log.pharos__Area__c),
                TritonHelper.buildLogLevelKey(log.pharos__Category__c, log.pharos__Type__c, null),
                TritonHelper.buildLogLevelKey(log.pharos__Category__c, null, log.pharos__Area__c),
                TritonHelper.buildLogLevelKey(null, log.pharos__Type__c, log.pharos__Area__c),
                TritonHelper.buildLogLevelKey(null, null, log.pharos__Area__c),
                TritonHelper.buildLogLevelKey(null, log.pharos__Type__c, null),
                TritonHelper.buildLogLevelKey(log.pharos__Category__c, null, null),
                TritonHelper.buildLogLevelKey(null, null, null)
        };

        TritonTypes.Level currentLevel = TritonTypes.Level.valueOf(log.Log_Level__c);
        Boolean allPermutationsDontExistInMdt = true;
        for (String key : permutations) {
            if (LOG_LEVELS.containsKey(key)) {
                if (TritonHelper.compareLevel(LOG_LEVELS.get(key), currentLevel)) return true;
            }
            allPermutationsDontExistInMdt = allPermutationsDontExistInMdt && !LOG_LEVELS.containsKey(key);
        }

        return allPermutationsDontExistInMdt;
    }
}
