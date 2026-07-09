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
    * Cached, parsed Log_Level__mdt rules used to decide whether a log is verbose
    * enough to be persisted. Lazily built from LOG_LEVELS_MDT and reset by tests
    * by assigning null.
    */
    @TestVisible
    private static List<LogLevelRule> LOG_LEVELS {
        get {
            if (LOG_LEVELS == null) {
                LOG_LEVELS = new List<LogLevelRule>();
                for (Log_Level__mdt ll : LOG_LEVELS_MDT) {
                    LOG_LEVELS.add(new LogLevelRule(ll));
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
                CACHE_AVAILABLE = TritonCacheManager.available();
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
     * Buffered (queued for later flush):
     *   Triton.log(builder)     - Uses builder's level
     *   Triton.info(builder)    - Overrides level to INFO
     *   Triton.debug(builder)   - Overrides level to DEBUG
     *   Triton.warning(builder) - Overrides level to WARNING
     *   Triton.error(builder)   - Overrides level to ERROR
     *   Triton.fine(builder)    - Overrides level to FINE
     *   Triton.finer(builder)   - Overrides level to FINER
     *   Triton.finest(builder)  - Overrides level to FINEST
     *
     * Immediate (flushed right away):
     *   Triton.logNow(builder)  - Uses builder's level
     *
     * Use Triton.t as shorthand for Triton.fromTemplate()
     *
     * Examples:
     *   Triton.info(Triton.t.summary('Fetching items').details('...'));
     *   Triton.error(Triton.t.summary('Failed').exception(e));
     *   Triton.logNow(Triton.t.summary('Critical').error().exception(e));
     */

    /**
    * Adds a log to the buffer
    * @param builder TritonBuilder instance containing log details
    */
    public static void log(TritonBuilder builder) {
        if (TritonHelper.isLoggingDisabled()) {
            return;
        }

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

    public static void error(TritonBuilder builder) { log(builder.error()); }
    public static void warning(TritonBuilder builder) { log(builder.warning()); }
    public static void info(TritonBuilder builder) { log(builder.info()); }
    public static void debug(TritonBuilder builder) { log(builder.debug()); }
    public static void fine(TritonBuilder builder) { log(builder.fine()); }
    public static void finer(TritonBuilder builder) { log(builder.finer()); }
    public static void finest(TritonBuilder builder) { log(builder.finest()); }

    /**
    * Checks if a log should be persisted based on the configured log levels.
    *
    * A Log_Level__mdt record "targets" a log when every attribute it specifies
    * (Category, Type, Area, User Id, Component Name) matches the log. Unspecified
    * (null) attributes act as wildcards, so a record can scope a level as broadly
    * (a global default) or as narrowly (a single user or component) as needed.
    *
    * A log is allowed when either no configured level targets it, or at least one
    * targeting level is verbose enough (its level is greater than or equal to the
    * log's level).
    * @param log -- Pharos log record to be saved
    */
    public static Boolean isLogAllowedForLogLevel(pharos__Log__c log) {
        if (String.isBlank(log.Log_Level__c) || LOG_LEVELS.isEmpty()) return true;

        String logUserId = normalizeUserId(log.pharos__User_Id__c);
        String logComponent = getComponentName(log);
        TritonTypes.Level currentLevel = TritonTypes.Level.valueOf(log.Log_Level__c);

        Boolean anyLevelTargetsLog = false;
        for (LogLevelRule rule : LOG_LEVELS) {
            if (!rule.targets(log, logUserId, logComponent)) continue;
            anyLevelTargetsLog = true;
            if (TritonHelper.compareLevel(rule.level, currentLevel)) return true;
        }

        // No configured level targets this log -- allow it through by default.
        return !anyLevelTargetsLog;
    }

    /**
    * Resolves the component name used for log level matching.
    * Flows are identified by their API name; Apex/LWC by the class/component
    * portion of the Apex Name (the text before the first '.').
    *
    * Note: this runs during the log level check, before prepareForLogging derives
    * the operation from the stack trace. The component is therefore only available
    * when it is known at log() time -- LWC logs, Flow logs, or Apex logs with an
    * explicit operation. Apex logs relying on stack-trace-derived naming will have
    * a blank component here and are not matched by component-scoped levels.
    * @param log -- Pharos log record being evaluated
    * @return the component name, or null/blank when it cannot be determined
    */
    @TestVisible
    private static String getComponentName(pharos__Log__c log) {
        if (String.isNotBlank(log.pharos__Flow_API_Name__c)) return log.pharos__Flow_API_Name__c;

        String apexName = log.pharos__Apex_Name__c;
        if (String.isBlank(apexName)) return apexName;
        Integer dotIndex = apexName.indexOf('.');
        return dotIndex == -1 ? apexName : apexName.substring(0, dotIndex);
    }

    /**
    * Salesforce Ids are 18 characters in Apex, but Log Level metadata stores the
    * 15-character form. Matching is performed on the case-sensitive 15-character
    * prefix so both representations line up.
    * @param userId -- a 15 or 18 character user Id (or null)
    * @return the 15-character prefix, or the original value when shorter/blank
    */
    @TestVisible
    private static String normalizeUserId(String userId) {
        return String.isNotBlank(userId) && userId.length() > 15 ? userId.substring(0, 15) : userId;
    }

    /**
    * In-memory representation of a Log_Level__mdt record, parsed once and cached
    * so that log level checks avoid re-reading and re-parsing metadata per log.
    */
    private class LogLevelRule {
        private final String category;
        private final String type;
        private final String area;
        private final String userId;
        private final String component;
        private final TritonTypes.Level level;

        private LogLevelRule(Log_Level__mdt mdt) {
            this.category = mdt.Category__c;
            this.type = mdt.Type__c;
            this.area = mdt.Area__c;
            this.userId = normalizeUserId(mdt.User_Id__c);
            this.component = mdt.Component_Name__c;
            this.level = TritonTypes.Level.valueOf(mdt.Level__c);
        }

        /**
        * True when every attribute specified on this rule matches the log.
        * Null (unspecified) rule attributes are treated as wildcards.
        */
        private Boolean targets(pharos__Log__c log, String logUserId, String logComponent) {
            return matches(category, log.pharos__Category__c)
                && matches(type, log.pharos__Type__c)
                && matches(area, log.pharos__Area__c)
                && matches(userId, logUserId)
                && matches(component, logComponent);
        }

        // String.equals is case-sensitive and null-safe, preserving the
        // case-sensitivity required for 15-character Salesforce Ids.
        private Boolean matches(String ruleValue, String logValue) {
            return ruleValue == null || ruleValue.equals(logValue);
        }
    }
}
