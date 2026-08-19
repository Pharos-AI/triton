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
     * Span stack for the current execution context, rooted at the request id -- which,
     * unlike TRANSACTION_ID, cannot change mid-request and re-root a built subtree.
     * The root is a sentinel, never a parent value: see ambientParentSpanId.
     */
    private static TritonSpanContext spans {
        get {
            if (spans == null) {
                spans = new TritonSpanContext();
                spans.reset(TritonHelper.requestId());
            }
            return spans;
        }
        set;
    }

    /**
     * Open marks, innermost last. Keyed by position, not by name, so two same-named
     * marks (a loop, a recursion) are two distinct spans and neither orphans the other.
     */
    private static List<Mark> openMarks = new List<Mark>();

    /**
     * A single open mark. Everything both paired records need is captured once, at
     * open, so the two halves cannot disagree and neither re-derives or re-captures.
     */
    private class Mark {
        String name;
        String stackTrace;
        String spanId;
        String parentSpanId;
        // What was pushed: this mark's span id, or the enclosing span when suppressed.
        String stackedSpanId;
        Long startedAt;
        Boolean suppressed = false;
    }


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
        // A new transaction starts from a clean span hierarchy, mirroring the LWC logger.
        clearMarks();
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
     *
     * Deliberately does NOT call clearMarks(): spans are request-scoped while
     * transactions are not, so this leaves the span hierarchy intact. Consequence: a
     * mark opened afterwards carries a null pharos__Transaction_Id_External__c and, at
     * the outermost level, a null parent -- which the converter resolves to the
     * request root.
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
        doLog(builder);
    }

    /**
    * Adds a log to the buffer and reports whether it was buffered: the body of log(),
    * with the outcome returned rather than discarded. A mark whose opening record was
    * filtered out must not push a span id that no record will carry.
    * @param builder TritonBuilder instance containing log details
    * @return true when the log was buffered, false when it was filtered out
    */
    private static Boolean doLog(TritonBuilder builder) {
        if (TritonHelper.Config.isLoggingDisabled()) {
            return false;
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
            return false;
        }

        builder.prepareForLogging(TRANSACTION_ID);
        logs.add(builder.build());
        return true;
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
     * ---------------------------
     * Performance marks.
     * ---------------------------
     *
     * A mark is a timed span: opening one emits a 'Performance started' record and
     * pushes its span id, so everything logged until it closes nests under it;
     * closing one emits the matching 'Performance' record carrying the duration. No
     * mark method ever flushes. For the try/finally idiom and when to reach for a
     * mark at all, see agent-skills/instrument-apex.md, step 3c.
     */

    /**
    * Opens a mark whose name is derived from the stack trace ('MyClass.myMethod').
    * The trace is captured once and reused three ways -- the name and both records'
    * stacktrace -- so a pair costs one capture rather than three.
    * @return the mark name, passable to endMark(String) for an out-of-order close
    */
    public static String startMark() {
        String stackTrace = TritonHelper.getCurrentStackTrace();
        return openMark(TritonHelper.deriveMarkName(stackTrace), stackTrace);
    }

    /**
    * Opens a mark with an explicit name, for spans whose meaningful name is not a
    * method name ('nightly-reconcile'). A blank name falls back to derivation. Not a
    * performance shortcut: both records carry the trace, so it is captured either way.
    * @param markName -- name for the mark
    * @return the mark name actually used
    */
    public static String startMark(String markName) {
        String stackTrace = TritonHelper.getCurrentStackTrace();
        return openMark(String.isBlank(markName) ? TritonHelper.deriveMarkName(stackTrace) : markName, stackTrace);
    }

    /**
    * Opens a mark named '<Handler>.<TriggerOperation>'. The trigger context is the one
    * naming fact a trace cannot carry: BEFORE_UPDATE and AFTER_UPDATE run the same
    * method from the same frame. Outside trigger context this is exactly startMark().
    * @return the mark name
    */
    public static String startTriggerMark() {
        String stackTrace = TritonHelper.getCurrentStackTrace();
        String derivedName = TritonHelper.deriveMarkName(stackTrace);
        return openMark(
            triggerMarkName(derivedName, Trigger.isExecuting ? Trigger.operationType : null),
            stackTrace);
    }

    /**
    * Combines a derived name with a trigger context. Split out from startTriggerMark
    * because Trigger.operationType cannot be simulated in a test.
    * @param derivedName -- name derived from the stack trace ('MyHandler.run')
    * @param operation -- the trigger operation, or null outside trigger context
    * @return '<Handler>.<OPERATION>' in trigger context, the derived name otherwise
    */
    @TestVisible
    private static String triggerMarkName(String derivedName, System.TriggerOperation operation) {
        if (operation == null) return derivedName;
        return derivedName.substringBefore('.') + '.' + operation.name();
    }

    /**
    * Closes the innermost open mark. A no-op when none is open: instrumentation must
    * never throw into business logic.
    */
    public static void endMark() {
        if (openMarks.isEmpty()) return;
        closeMark(openMarks.size() - 1);
    }

    /**
    * Closes the newest open mark with that name, so a loop or a recursion closes its
    * own span. An unknown name is ignored.
    * @param markName -- name returned by startMark
    */
    public static void endMark(String markName) {
        if (String.isBlank(markName)) return;
        for (Integer i = openMarks.size() - 1; i >= 0; i--) {
            if (markName.equals(openMarks.get(i).name)) {
                closeMark(i);
                return;
            }
        }
    }

    /**
    * Discards all open marks and resets the span stack to the request root. Called
    * automatically by startTransaction(). Exposed for deliberate recovery only: an
    * async context already starts with empty statics and re-seeds itself.
    */
    public static void clearMarks() {
        openMarks.clear();
        spans.reset(TritonHelper.requestId());
    }

    /**
    * True when at least one mark is open. Internal; deliberately not global.
    * @return whether a mark is currently open
    */
    public static Boolean hasOpenMark() {
        return !openMarks.isEmpty();
    }

    /**
    * The innermost span id on the span stack, or null when it is empty. Internal.
    * Test-visible rather than public: the raw stack accessor the mark tests assert
    * against, with no production caller of its own.
    * @return the current span id
    */
    @TestVisible
    private static String currentSpanId() {
        return spans.current();
    }

    /**
    * Parent for a span opening at the current stack position. Internal, but public
    * rather than @TestVisible: TritonBuilder resolves ordinary logs through it.
    *
    * Resolves to the enclosing mark, or -- outermost, where the stack holds only its
    * request-id root -- TRANSACTION_ID, which the span converter resolves onto the
    * transaction span it synthesises. Null with no transaction, so the converter falls
    * back to the request root itself.
    * The request id is never returned: the converter reaches the request span only by
    * hashing, so a request id used as a parent names a span nothing carries.
    * @return the ambient parent span id, or null
    */
    public static String ambientParentSpanId() {
        String enclosing = spans.current();
        if (String.isNotBlank(enclosing) && !enclosing.equals(TritonHelper.requestId())) {
            return enclosing;
        }
        return String.isBlank(TRANSACTION_ID) ? null : TRANSACTION_ID;
    }

    /**
    * Opens a mark: mints its span id, emits the opening record, and pushes the span so
    * everything logged until it closes nests under it.
    * @param markName -- resolved mark name, shared by both paired records
    * @param stackTrace -- trace captured by the caller, set on both paired records
    * @return the mark name
    */
    private static String openMark(String markName, String stackTrace) {
        Mark mark = new Mark();
        mark.name = markName;
        mark.stackTrace = stackTrace;
        mark.startedAt = System.currentTimeMillis();
        mark.spanId = TritonHelper.generateUUID4();
        mark.parentSpanId = ambientParentSpanId();

        // A mark filtered out by Log_Level__mdt must be transparent, not a phantom
        // parent: push the enclosing span so its children nest under it instead.
        mark.suppressed = !doLog(markBuilder(mark)
                                    .summary(TritonHelper.MARK_STARTED_PREFIX + markName)
                                    .withoutLimitInfo());
        mark.stackedSpanId = mark.suppressed ? spans.current() : mark.spanId;
        spans.push(mark.stackedSpanId);

        openMarks.add(mark);
        return markName;
    }

    /**
    * Closes the mark at the given position: pops its span, emits the completion record.
    * @param index -- position of the mark in the open mark list
    */
    private static void closeMark(Integer index) {
        Mark mark = openMarks.remove(index);
        spans.pop(mark.stackedSpanId);

        // The opening record was filtered out, so a completion record would be half a pair.
        if (mark.suppressed) return;

        Long elapsedMs = System.currentTimeMillis() - mark.startedAt;
        doLog(markBuilder(mark)
                .summary(TritonHelper.MARK_COMPLETED_PREFIX + mark.name)
                .details(TritonHelper.MARK_DURATION_PREFIX + elapsedMs + TritonHelper.MARK_DURATION_SUFFIX)
                .duration(Decimal.valueOf(elapsedMs)));
    }

    /**
    * Builds the fields both halves of a mark pair share. From the template, so an
    * entry point's Area survives onto its marks; Type and Action are the converter's
    * contract. Setting the captured stacktrace and operation here short-circuits
    * TritonBuilder.resolveStackTraceAndOperation on both records.
    * @param mark -- the mark being reported
    * @return a builder carrying the mark's shared fields
    */
    private static TritonBuilder markBuilder(Mark mark) {
        TritonBuilder builder = t
            .type(TritonTypes.Type.Performance)
            .action(mark.name)
            .operation(mark.name)
            .stackTrace(mark.stackTrace)
            .spanId(mark.spanId)
            .level(TritonTypes.Level.FINE);
        // Left unset rather than set to null when there is no ambient parent, so the
        // field is simply absent instead of explicitly empty.
        return String.isBlank(mark.parentSpanId) ? builder : builder.parentSpanId(mark.parentSpanId);
    }

    public static void error(TritonBuilder builder) { log(builder.error()); }
    public static void warning(TritonBuilder builder) { log(builder.warning()); }
    public static void info(TritonBuilder builder) { log(builder.info()); }
    public static void debug(TritonBuilder builder) { log(builder.debug()); }
    public static void fine(TritonBuilder builder) { log(builder.fine()); }
    public static void finer(TritonBuilder builder) { log(builder.finer()); }
    public static void finest(TritonBuilder builder) { log(builder.finest()); }

}
