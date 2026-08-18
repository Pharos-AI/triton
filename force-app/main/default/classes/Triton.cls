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
        if (TritonHelper.Config.isLoggingDisabled()) {
            return;
        }

        // Component-scoped log levels match on the Apex Name, which is otherwise
        // only derived from the stacktrace later, in prepareForLogging -- too late
        // for the check below. Resolve it up front only when a component-scoped
        // level exists, so orgs without one never pay for the stacktrace.
        if (TritonHelper.Config.hasComponentScopedLevels()) {
            builder.resolveStackTraceAndOperation();
        }

        pharos__Log__c log = builder.build();

        if (!TritonHelper.Config.isLogAllowed(log)) {
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

    /* ---------------------------------------------------------------------
     * Performance marks — Apex mirror of the LWC library's startMark/endMark.
     * startMark pushes a span onto the context stack; endMark pops it and
     * logs the timing. Nested marks parent to the enclosing mark, so a
     * cascade of marks renders as a nested span tree.
     * --------------------------------------------------------------------- */

    /** Active marks by name (mirrors the LWC performance tracker). */
    private static Map<String, MarkData> activeMarks = new Map<String, MarkData>();

    /** Span-context stack: the innermost open mark is the current parent. */
    private static List<String> markSpanStack = new List<String>();

    private class MarkData {
        private String name;
        private String spanId;
        private String parentSpanId;
        private Long startTime;
    }

    /**
     * Starts a performance mark: generates a span id, parents it to the
     * innermost open mark (span-context stack, as in the LWC library) and
     * pushes it. No log is emitted until endMark.
     * @param markName mark name, e.g. 'AccountHandler.BEFORE_UPDATE'
     * @return the mark name, for symmetry with the LWC API
     */
    public static String startMark(String markName) {
        MarkData mark = new MarkData();
        mark.name = markName;
        mark.spanId = TritonHelper.generateUUID4();
        mark.parentSpanId = markSpanStack.isEmpty()
            ? null
            : markSpanStack[markSpanStack.size() - 1];
        mark.startTime = System.currentTimeMillis();
        markSpanStack.add(mark.spanId);
        activeMarks.put(markName, mark);
        return markName;
    }

    /**
     * Ends a performance mark: pops its span from the context stack and logs
     * the timing as a FINE Performance span (volume-gated by Log_Level rules,
     * so production stays quiet until a component is dialed up). Unknown mark
     * names are ignored, mirroring the LWC library's warn-and-return.
     * @param markName mark name used in startMark
     */
    public static void endMark(String markName) {
        MarkData mark = activeMarks.remove(markName);
        if (mark == null) {
            return;
        }
        Long duration = System.currentTimeMillis() - mark.startTime;
        // Pop this mark's span id — searched from the top so out-of-order
        // ends stay safe, like spanContext.pop(spanId) in the LWC library.
        for (Integer i = markSpanStack.size() - 1; i >= 0; i--) {
            if (markSpanStack[i] == mark.spanId) {
                markSpanStack.remove(i);
                break;
            }
        }
        TritonBuilder b = makeBuilder()
            .type(TritonTypes.Type.Performance)
            .summary('Performance: ' + mark.name)
            .details('Duration: ' + duration + 'ms')
            .duration(duration)
            .action(mark.name)
            .spanId(mark.spanId);
        if (mark.parentSpanId != null) {
            b.parentSpanId(mark.parentSpanId);
        }
        fine(b);
    }

    /**
     * Convenience over startMark for tracing a method body: call at the top
     * of the method, pair with methodExit at every return path (or in a
     * finally block).
     * @return the mark name, for symmetry with the LWC API
     */
    public static String methodEntry(String className, String methodName) {
        return startMark(className + '.' + methodName);
    }

    /** Ends a method mark opened by methodEntry and logs its timing. */
    public static void methodExit(String className, String methodName) {
        endMark(className + '.' + methodName);
    }

    public static void error(TritonBuilder builder) { log(builder.error()); }
    public static void warning(TritonBuilder builder) { log(builder.warning()); }
    public static void info(TritonBuilder builder) { log(builder.info()); }
    public static void debug(TritonBuilder builder) { log(builder.debug()); }
    public static void fine(TritonBuilder builder) { log(builder.fine()); }
    public static void finer(TritonBuilder builder) { log(builder.finer()); }
    public static void finest(TritonBuilder builder) { log(builder.finest()); }

}
