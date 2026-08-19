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
     * Literal prefix Apex puts in front of every class frame in a stack trace, and
     * which TritonHelper.getOperation retains. Stripped from derived mark names so a
     * span is named 'MyClass.myMethod' rather than 'Class.MyClass.myMethod'.
     */
    private static final String CLASS_FRAME_PREFIX = 'Class.';

    /** Name given to a mark whose name cannot be derived from the stack trace. */
    private static final String ANONYMOUS_MARK_NAME = 'AnonymousMark';

    /**
     * Summary prefixes for the two halves of a mark. They are matched verbatim by the
     * span converter and are identical to the ones the LWC logger emits.
     */
    private static final String MARK_STARTED_PREFIX = 'Performance started: ';
    private static final String MARK_COMPLETED_PREFIX = 'Performance: ';
    private static final String MARK_DURATION_PREFIX = 'Duration: ';
    private static final String MARK_DURATION_SUFFIX = 'ms';

    /**
     * Span stack for the current execution context, seeded with the request id.
     *
     * The request id rather than the transaction id, deliberately: it is already what
     * ensureSpanIds stamps today, it never changes mid-request (resumeTransaction can
     * reassign the transaction id partway through, which would silently re-root an
     * already-built subtree), and it exists in every execution context including
     * batch and future, where a transaction may never have been started.
     */
    private static TritonSpanContext spans {
        get {
            if (spans == null) {
                spans = new TritonSpanContext();
                spans.reset(requestId());
            }
            return spans;
        }
        set;
    }

    /**
     * Open marks, innermost last. A list keyed by position rather than a map keyed by
     * name: two same-named marks (a loop, a recursive call) are then two distinct
     * spans, and neither can orphan the other.
     */
    private static List<Mark> openMarks = new List<Mark>();

    /**
     * Whether a mark has already claimed the request node in this execution context.
     * Claiming happens at most once so that two boundaries cannot share a span id.
     */
    private static Boolean requestNodeClaimed = false;

    /** Occurrence counter behind the anonymous mark name fallback. */
    private static Integer anonymousMarkCounter = 0;

    /**
     * A single open mark. Everything both paired records need is captured once, when
     * the mark opens, so the two halves cannot disagree and neither has to re-derive
     * a name or re-capture a stack trace.
     */
    private class Mark {
        String name;
        String stackTrace;
        String spanId;
        String parentSpanId;
        // What was actually pushed onto the span stack: the mark's own span id, or the
        // enclosing span when the opening record was filtered out (see openMark).
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
    * Adds a log to the buffer and reports whether it was buffered.
    *
    * The body of log(), with the outcome returned rather than discarded. Marks need
    * to know whether their opening record survived the log level check: a mark whose
    * record was filtered out must not push a span id that no record will ever carry.
    * @param builder TritonBuilder instance containing log details
    * @return true when the log was buffered, false when logging is disabled or the
    *         configured log level filtered the record out
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
     * A mark is a timed span. Opening one emits a "Performance started" record right
     * away and pushes the mark's span id, so every log emitted until the mark closes
     * is ambiently parented to it (see TritonBuilder.prepareForLogging). Closing one
     * emits the matching "Performance" record carrying the duration. Both halves
     * share a span id, so the pair describes a single span.
     *
     * The canonical idiom names nothing -- the name is derived from the stack trace:
     *
     *   Triton.startMark();
     *   try {
     *       // work being measured
     *   } finally {
     *       Triton.endMark();
     *   }
     *
     * Marks are buffered like any other log: no mark method ever flushes, because
     * flushing is a program-visible action that belongs to the caller.
     */

    /**
    * Opens a mark whose name is derived from the stack trace ('MyClass.myMethod').
    * The trace is captured once here and reused three ways -- to derive the name and
    * as the stacktrace of both paired records -- so a mark pair costs a single stack
    * capture rather than three.
    * @return the mark name, which can be passed to endMark(String) for an
    *         out-of-order close
    */
    public static String startMark() {
        String stackTrace = TritonHelper.getCurrentStackTrace();
        return openMark(deriveMarkName(stackTrace), stackTrace);
    }

    /**
    * Opens a mark with an explicit name, for spans whose meaningful name is not a
    * method name ('nightly-reconcile', 'chunk-3-of-40'). A blank name falls back to
    * derivation. This is not a performance shortcut: the stack trace is captured
    * either way, because both paired records carry it.
    * @param markName -- name for the mark
    * @return the mark name actually used
    */
    public static String startMark(String markName) {
        String stackTrace = TritonHelper.getCurrentStackTrace();
        return openMark(String.isBlank(markName) ? deriveMarkName(stackTrace) : markName, stackTrace);
    }

    /**
    * Opens a mark named '<Handler>.<TriggerOperation>'. The trigger context is the
    * one piece of naming information a stack trace cannot carry -- BEFORE_UPDATE and
    * AFTER_UPDATE run the same method from the same frame, so a derived name alone
    * would collapse two distinct spans into one. Outside trigger context this
    * behaves exactly like startMark().
    * @return the mark name
    */
    public static String startTriggerMark() {
        String stackTrace = TritonHelper.getCurrentStackTrace();
        String markName = deriveMarkName(stackTrace);
        if (Trigger.isExecuting && Trigger.operationType != null) {
            markName = markName.substringBefore('.') + '.' + Trigger.operationType.name();
        }
        return openMark(markName, stackTrace);
    }

    /**
    * Closes the innermost open mark, whatever it is called. A no-op when no mark is
    * open: instrumentation never throws into business logic.
    */
    public static void endMark() {
        if (openMarks.isEmpty()) return;
        closeMark(openMarks.size() - 1);
    }

    /**
    * Closes the newest open mark with the given name, so a loop or a recursive call
    * closes its own span rather than an outer one. An unknown name is ignored.
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
    * Discards all open marks and resets the span stack to the request root.
    * Called automatically by startTransaction(). Exposed so a caller can deliberately
    * recover a known-good state -- it is not needed at the start of a batch chunk, a
    * queueable or a future, because a fresh execution context already starts with
    * empty statics and re-seeds itself from that context's own request id.
    */
    public static void clearMarks() {
        openMarks.clear();
        spans.reset(requestId());
    }

    /**
    * True when at least one mark is open.
    * Internal: TritonBuilder uses this to decide whether ambient span stamping
    * applies. Not part of the supported API surface and deliberately not global.
    * @return whether a mark is currently open
    */
    public static Boolean hasOpenMark() {
        return !openMarks.isEmpty();
    }

    /**
    * The innermost span id on the span stack, or null when the stack is empty.
    * Internal: TritonBuilder uses this for ambient parenting. Not part of the
    * supported API surface and deliberately not global.
    * @return the current span id
    */
    public static String currentSpanId() {
        return spans.current();
    }

    /**
    * Opens a mark: mints its span id, emits the opening record, and pushes the span
    * so that everything logged until the mark closes nests under it.
    * @param markName -- resolved mark name, shared by both paired records
    * @param stackTrace -- trace captured by the caller, set on both paired records
    * @return the mark name
    */
    private static String openMark(String markName, String stackTrace) {
        Mark mark = new Mark();
        mark.name = markName;
        mark.stackTrace = stackTrace;
        mark.startedAt = System.currentTimeMillis();
        mark.parentSpanId = spans.current();

        // Structural request-node claiming: the first mark opened at stack depth 0 is
        // the request node itself, so marks opened later in the request nest under the
        // named boundary instead of under a generic wrapper. Claimed at most once per
        // request, so two boundaries can never end up sharing one span id.
        if (!requestNodeClaimed && openMarks.isEmpty() && spans.depth() <= 1) {
            mark.spanId = requestId();
            mark.parentSpanId = spans.parent();
            requestNodeClaimed = true;
        } else {
            mark.spanId = TritonHelper.generateUUID4();
        }

        // A mark filtered out by Log_Level__mdt must be transparent rather than a
        // phantom parent: push the enclosing span, so logs inside it nest under the
        // nearest surviving ancestor.
        mark.suppressed = !doLog(markBuilder(mark)
                                    .summary(MARK_STARTED_PREFIX + markName)
                                    .withoutLimitInfo());
        mark.stackedSpanId = mark.suppressed ? spans.current() : mark.spanId;
        spans.push(mark.stackedSpanId);

        openMarks.add(mark);
        return markName;
    }

    /**
    * Closes the mark at the given position: pops its span and emits the completion
    * record with the elapsed time.
    * @param index -- position of the mark in the open mark list
    */
    private static void closeMark(Integer index) {
        Mark mark = openMarks.remove(index);
        spans.pop(mark.stackedSpanId);

        // The opening record never made it past the log level check, so a completion
        // record would be a span with only half a pair.
        if (mark.suppressed) return;

        Long elapsedMs = System.currentTimeMillis() - mark.startedAt;
        doLog(markBuilder(mark)
                .summary(MARK_COMPLETED_PREFIX + mark.name)
                .details(MARK_DURATION_PREFIX + elapsedMs + MARK_DURATION_SUFFIX)
                .duration(Decimal.valueOf(elapsedMs)));
    }

    /**
    * Builds the half of a paired mark record that both halves share. Built from the
    * template, so an entry point's template Area survives onto its marks; Type and
    * Action are set unconditionally because they are the span converter's contract.
    * The stacktrace and operation are set explicitly from the values captured when
    * the mark opened, which short-circuits the stack capture in
    * TritonBuilder.resolveStackTraceAndOperation for both records.
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
        // Left unset rather than set to null when the mark is the request node itself,
        // so the field is simply absent instead of explicitly empty.
        return String.isBlank(mark.parentSpanId) ? builder : builder.parentSpanId(mark.parentSpanId);
    }

    /**
    * Derives a mark name from a stack trace: the topmost application frame, minus the
    * literal 'Class.' prefix Apex puts on every frame and which getOperation retains.
    * Falls back to a request-scoped anonymous name when no application frame is
    * available, so a span is still nested and identifiable rather than nameless.
    * @param stackTrace -- trace captured at the call site
    * @return the derived mark name, never blank
    */
    @TestVisible
    private static String deriveMarkName(String stackTrace) {
        String operation = TritonHelper.getOperation(stackTrace);
        if (String.isNotBlank(operation) && operation.startsWith(CLASS_FRAME_PREFIX)) {
            operation = operation.substringAfter(CLASS_FRAME_PREFIX);
        }
        if (String.isNotBlank(operation)) return operation;

        anonymousMarkCounter++;
        return ANONYMOUS_MARK_NAME + anonymousMarkCounter;
    }

    /**
    * The current request id -- the root of the span tree for this execution context.
    * @return the request id
    */
    private static String requestId() {
        return System.Request.getCurrent().getRequestId();
    }

    public static void error(TritonBuilder builder) { log(builder.error()); }
    public static void warning(TritonBuilder builder) { log(builder.warning()); }
    public static void info(TritonBuilder builder) { log(builder.info()); }
    public static void debug(TritonBuilder builder) { log(builder.debug()); }
    public static void fine(TritonBuilder builder) { log(builder.fine()); }
    public static void finer(TritonBuilder builder) { log(builder.finer()); }
    public static void finest(TritonBuilder builder) { log(builder.finest()); }

}
