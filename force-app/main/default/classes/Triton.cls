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
    
    public static Triton instance {
        get {
            if (instance == null) {
                instance = new Triton(pharos.Logger.getInstance());
            }
            return instance;
        }
        private set;
    }

    //singleton instance
    private final pharos.Logger logger;

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

    private TritonBuilder template;

    // Logs buffer (queue) property
    @TestVisible
    private List<pharos__Log__c> logs {
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
                try {
                    // Try to get the Session partition - this will throw an exception
                    // if platform cache is not enabled or no partitions are configured
                    Cache.Session.getKeys();
                    CACHE_AVAILABLE = true;
                } catch (Exception e) {
                    CACHE_AVAILABLE = false;
                }
            }
            return CACHE_AVAILABLE;
        }
        private set;
    }

    /**
     * Indicates whether this instance should use platform cache for transaction management
     */
    @TestVisible
    private Boolean withCache = false;

    // Constructor
    private Triton(pharos.Logger logger) {
        this.logger = logger;
        this.template = makeBuilder();
    }

    /**
     * Enables platform cache for transaction management
     * @return Triton instance for chaining
     */
    public Triton withCache() {
        if (!CACHE_AVAILABLE) {
            this.withCache = false;
            if (TRANSACTION_ID == null) {
                startTransaction();
            }
            return this;
        }

        this.withCache = true;
        String transactionId = TritonHelper.getCachedTransactionId();       
        if (String.isNotBlank(transactionId)) {
            resumeTransaction(transactionId);
        } else if(TRANSACTION_ID == null) {
            startTransaction();
        }        
        return this;
    }

    /**
    * Sets a builder template that can be re-used
    * @param builder -- Pharos builder to be used as a template
    */
    public void setTemplate(TritonBuilder builder) {
        this.template = builder;
    }

    /**
    * Retrieves a copy of a previously saved template
    * @return builder -- Pharos builder previously saved as a template
    */
    public TritonBuilder fromTemplate() {
        return (TritonBuilder)this.template.cloneBuilder()
                .transactionId(TRANSACTION_ID);
    }

    /**
    * Persist Log records immediately.
    * Use this method to persist logs to the database right away.
    * If platform event allocation is near capacity (95%), logs will be scheduled
    * for delayed publishing with exponential backoff using a singleton batch.
    */
    public void flush() {
        // Check if we have any logs to flush
        if (logs.isEmpty()) {
            return;
        }
        
        for(pharos__Log__c log : logs) {
            this.logger.add(log);
        }
        this.logger.flush();
        this.logs.clear();
    }

    /**
    * Persist the last Log in the queue only, immediately.
    * Use this method to persist a single log to the database right away.
    * If platform event allocation is near capacity (95%), the log will be scheduled
    * for delayed publishing with exponential backoff using a singleton batch.
    */
    public void flushTop() {
        if (logs.size() == 0) {
            return;
        }
        
        this.logger.add(logs.get(logs.size() - 1));
        this.logger.flush();
        this.logs.remove(logs.size() - 1);
    }

    /**
    * Shorthand method for creating a new builder
    */
    public static TritonBuilder makeBuilder() {
        return new TritonBuilder();
    }

    /**
     * Shorthand static property for creating a builder from template
     * Usage: Triton.log(Triton.t.summary('test').details('test'))
     */
    public static TritonBuilder t {
        get {
            return instance.fromTemplate();
        }
    }

    /**
    * Shorthand method for creating a new post processing controls builder
    */
    public static TritonHelper.PostProcessingControlsBuilder makePostProcessingBuilder() {
        return new TritonHelper.PostProcessingControlsBuilder();
    }

    // -------------------------------------------------------
    // Static API — delegates to singleton instance
    // These wrappers eliminate the need for Triton.instance.*
    // -------------------------------------------------------

    public static void log(TritonBuilder builder) {
        instance.log(builder);
    }

    public static void logNow(TritonBuilder builder) {
        instance.logNow(builder);
    }

    public static void flush() {
        instance.flush();
    }

    public static void flushTop() {
        instance.flushTop();
    }

    public static String startTransaction() {
        return instance.startTransaction();
    }

    public static void resumeTransaction(String transactionId) {
        instance.resumeTransaction(transactionId);
    }

    public static void stopTransaction() {
        instance.stopTransaction();
    }

    public static void setTemplate(TritonBuilder builder) {
        instance.setTemplate(builder);
    }

    public static void withCache() {
        instance.withCache();
    }

    /**
     * This value can be passed around to trace a complex process spanning multiple Salesforce transactions
     * Can be used between LWC/Apex/Flow transitions when complex tracing is required.
     */
    public String TRANSACTION_ID;

    /**
     * Start new transaction
     * Autogenrated Transaction UUID
     * This method will obtain a new autogenrated transaction id or use the current one
     */
    public String startTransaction() {
        TRANSACTION_ID = TritonHelper.generateUUID4();
        if (withCache) {
            TritonHelper.cacheTransactionId(TRANSACTION_ID);
        }
        return TRANSACTION_ID;
    }

    /**
     * Resumes a transaction
     * Assumes an existing transaction id
     * Use this method to tie together different Salesforce transactions.
     */
    public void resumeTransaction(String transactionId) {
        if (withCache) {
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
    public void stopTransaction() {
        TRANSACTION_ID = null;
        if (withCache) {
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
    public void log(TritonBuilder builder) {
        pharos__Log__c log = builder.build();

        if (!isLogAllowedForLogLevel(log)) {
            return;
        }
        builder.transactionId(TRANSACTION_ID);

        //get the stacktrace if one isn't provided
        String stackTrace = log.pharos__Stacktrace__c;
        if(String.isBlank(log.pharos__Stacktrace__c)) {
            stackTrace = TritonHelper.getCurrentStackTrace();
            builder.stackTrace(stackTrace);
        }

        //set the operation based on the class name and method name
        if(String.isBlank(builder.build().pharos__Apex_Name__c)) {
            builder.operation(TritonHelper.getOperation(stackTrace));
        }

        builder.tracePoint()
               .limitInfo();

        logs.add(builder.build());
    }

    /**
    * Adds a log to the buffer and immediately flushes it
    * @param builder TritonBuilder instance containing log details
    */
    public void logNow(TritonBuilder builder) {
        log(builder);
        flushTop();
    }    

    /**
    * Checks if a log should be persisted based on the current log level
    * @param log -- Pharos log record to be saved
    * @param builder TritonBuilder instance containing log details
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
