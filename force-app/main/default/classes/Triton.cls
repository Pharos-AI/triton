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
 * It enables structured logging with different severity levels (ERROR, WARNING, DEBUG, INFO),
 * categories (Apex, Integration, Event, Debug), and functional areas.
 * 
 * Key features:
 * - Buffered and immediate logging options
 * - Automatic stack trace capture
 * - Transaction tracking across multiple Salesforce contexts
 * - Integration error logging with HTTP request/response details
 * - Configurable log levels via Custom Metadata
 * - Builder pattern for constructing log entries
 * 
 */

public without sharing class Triton {

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

    // Constructor
    private Triton(pharos.Logger logger) {
        this.logger = logger;
        this.template = makeBuilder();
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
        return (TritonBuilder)this.template.clone().transactionId(TRANSACTION_ID);
    }

    /**
    * Adds a log to the buffer.
    * Performs a check on current log level prior
    * @param log -- Pharos log record
    */
    public void add(pharos__Log__c log) {
        if (isLogAllowedForLogLevel(log)) {
            this.logs.add(log);
        }
    }

    /**
    * Persist Log records immediately.
    * Use this method to persist logs to the database right away.
    */
    public void flush() {
        for(pharos__Log__c log : logs) {
            this.logger.add(log);
        }
        this.logger.flush();
        this.logs.clear();
    }

    /**
    * Persist the last Log in the queue only, immediately.
    * Use this method to persist a single log to the database right away.
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
    * Stack trace offset.
    * In case no stack is provided, it will be obtained automatically for error and debug logs.
    * Use the offset to remove unwanted lines from top of the stack trace
    * such as util method invocations.
    */
    private Integer stackOffset = 0;
    private void incStackOffset() {
        stackOffset++;
    }
    private void resetStackOffset() {
        stackOffset = 0;
    }

    /**
    * Shorthand method for creating a new builder
    */
    public static TritonBuilder makeBuilder() {
        return new TritonBuilder();
    }

    /**
    * Shorthand method for creating a new post processing controls builder
    */
    public static TritonHelper.PostProcessingControlsBuilder makePostProcessingBuilder() {
        return new TritonHelper.PostProcessingControlsBuilder();
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
        return TRANSACTION_ID;
    }

    /**
     * Resumes a transaction
     * Assumes an existing transaction id
     * Use this method to tie together different Salesforce transactions.
     */
    public void resumeTransaction(String transactionId) {
        TRANSACTION_ID = transactionId;
    }

    /**
     * Stops a transaction
     * Resets the current transaction Id
     * Use this method to marking tracking logs with the current transaction Id
     */
    public void stopTransaction() {
        TRANSACTION_ID = null;
    }

    /**
    * ---------------------------
    * Log methods.
    * ---------------------------
    *
    * There are 2 types of log methods per each category: buffered and immediate
    * Buffered methods will add to the log collection without flush()'ing
    * Immediate methods will add to the log collection and call flush()
    *
    */

    /**
    * Add Log from builder
    * This method will automatically get the stacktrace and save it on the log record.
    * @param builder -- Pharos builder 
    */
    public void addLog(TritonBuilder builder) {
        //get the stacktrace if one isn't provided
        if(String.isBlank(builder.build().pharos__Stacktrace__c)) {
            builder.stackTrace(this.logger.getCurrentStackTrace(stackOffset));
        }
        add(builder.build());
    }

    /**
    * Immediate
    */
    public void log(TritonBuilder builder) {
        incStackOffset();
        addLog(builder);
        flush();
    }    

    /**
    * Add Log with Error Category.
    * This method will automatically get the stacktrace and save it on the log record.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addError(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Apex)
                        .type(type)
                        .area(area)
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .transactionId(TRANSACTION_ID)
                        .level(TritonTypes.Level.ERROR)
                        .createIssue()
                        .build());
    }

    /**
    * Immediate
    */
    public void error(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        incStackOffset();
        addError(type, area, summary, details);
        resetStackOffset();
        flushTop();
    }


    /**
    * Add Log with Error Category and related records.
    * This method will automatically get the stacktrace from Exception.
    * Type will be obtained from Exception. If blank, a default Backend Type will be saved
    * Summary is the Exception message.
    * Details will be a combination of Exception String and stacktrace
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param e -- instance of an Exception
    * @param relatedObjectIds -- a set of related records to associate with this log
    */
    public void addError(TritonTypes.Area area, Exception e, Set<String> relatedObjectIds) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Apex)
                        //use exception type, Backend if blank
                        .type(String.isBlank(e.getTypeName()) ? TritonTypes.Type.Backend.name() : e.getTypeName())
                        .area(area)
                        .summary(e.getMessage())
                        .stackTrace(e.getStackTraceString())
                        .details(String.valueOf(e) + SPACE_SEP + e.getStackTraceString())
                        .transactionId(TRANSACTION_ID)
                        .relatedObjects(relatedObjectIds)
                        .level(TritonTypes.Level.ERROR)
                        .createIssue()
                        .build());
    }

    /**
    * Add Log with Error Category.
    * This method will automatically get the stacktrace from Exception.
    * Type will be obtained from Exception. If blank, a default Backend Type will be saved
    * Summary is the Exception message.
    * Details will be a combination of Exception String and stacktrace
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param e -- instance of an Exception
    */
    public void addError(TritonTypes.Area area, Exception e) {
        incStackOffset();
        addError(area, e, null);
        resetStackOffset();
    }

    /**
    * Immediate
    */
    public void error(TritonTypes.Area area, Exception e, Set<String> relatedObjectIds) {
        incStackOffset();
        addError(area, e, relatedObjectIds);
        resetStackOffset();
        flushTop();
    }

    public void error(TritonTypes.Area area, Exception e) {
        incStackOffset();
        error(area, e, null);
        resetStackOffset();
    }


    /**
    * Add Log with Warning Category.
    * This method will not save a stacktrace.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addWarning(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Warning)
                        .type(type)
                        .area(area)
                        .summary(summary)
                        .details(details)
                        .postProcessing(
                                makePostProcessingBuilder()
                                    .stackTrace(true)
                                    .userInfo(true)
                                    .relatedObjects(true))
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .transactionId(TRANSACTION_ID)
                        .level(TritonTypes.Level.WARNING)
                        .build());
    }

    /**
    * Immediate
    */
    public void warning(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        incStackOffset();
        addWarning(type, area, summary, details);
        resetStackOffset();
        flushTop();
    }


    /**
    * Add Log with Debug Category.
    * This method will automatically get the stacktrace.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addDebug(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Debug)
                        .type(type)
                        .area(area)
                        .summary(summary)
                        .details(details)
                        .postProcessing(
                                makePostProcessingBuilder()
                                    .stackTrace(true)
                                    .userInfo(true)
                                    .relatedObjects(true))
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .transactionId(TRANSACTION_ID)
                        .level(TritonTypes.Level.DEBUG)
                        .build());
    }

    /**
    * Immediate
    */
    public void debug(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        incStackOffset();
        addDebug(type, area, summary, details);
        resetStackOffset();
        flushTop();
    }

    /**
    * Add Log with Debug Category with duration.
    * This method will automatically get the stacktrace.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    * @param duration -- duration of the operation in milliseconds
    */
    public void addDebug(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        Decimal duration
    ) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Debug)
                        .type(type)
                        .area(area)
                        .summary(summary)
                        .details(details)
                        .postProcessing(
                                makePostProcessingBuilder()
                                    .stackTrace(true)
                                    .userInfo(true)
                                    .relatedObjects(true))
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .transactionId(TRANSACTION_ID)
                        .level(TritonTypes.Level.DEBUG)
                        .duration(duration)
                        .build());
    }

    /**
    * Immediate
    */
    public void debug(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        Decimal duration
    ) {
        incStackOffset();
        addDebug(type, area, summary, details, duration);
        resetStackOffset();
        flushTop();
    }

    /**
    * Add Log with Event Category.
    * @param level -- log TritonTypes.Level (see Level enum)
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addEvent(
        TritonTypes.Level level,
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details
    ) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Event)
                        .type(type)
                        .area(area)
                        .summary(summary)
                        .details(details)
                        .postProcessing(
                                makePostProcessingBuilder()
                                    .stackTrace(true)
                                    .userInfo(true)
                                    .relatedObjects(true))
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .transactionId(TRANSACTION_ID)
                        .level(level)
                        .build());
    }

    /**
    * Immediate
    */
    public void event(
        TritonTypes.Level level,
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details
    ) {
        incStackOffset();
        addEvent(level, type, area, summary, details);
        resetStackOffset();
        flushTop();
    }


    /**
    * Add Log with Event Category.
    * Default INFO log level
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addEvent(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        incStackOffset();
        addEvent(TritonTypes.Level.INFO, type, area, summary, details);
        resetStackOffset();
    }

    /**
    * Immediate
    */
    public void event(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        incStackOffset();
        event(TritonTypes.Level.INFO, type, area, summary, details);
        resetStackOffset();
    }


    /**
    * Add Log with Integration Category.
    * This method will automatically get the stacktrace from Exception.
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param e -- instance of an Exception
    * @param request -- HttpRequest of the issue. Saves to log record Details field
    * @param response -- HttpResponse of the issue. Saves to log record Details field
    */
    public void addIntegrationError(TritonTypes.Area area, Exception e, HttpRequest request, HttpResponse response) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Integration)
                        //Use Backend as default type
                        .type(String.isBlank(e.getTypeName()) ? TritonTypes.Type.Backend.name() : e.getTypeName())
                        .area(area)
                        .summary(e.getMessage())
                        .details(String.valueOf(e) + SPACE_SEP + e.getStackTraceString())
                        .stackTrace(e.getStackTraceString())
                        .createIssue()
                        .integrationPayload(request, response)
                        .transactionId(TRANSACTION_ID)                        
                        .level(TritonTypes.Level.ERROR)
                        .build());
    }

    /**
    * Immediate
    */
    public void integrationError(TritonTypes.Area area, Exception e, HttpRequest request, HttpResponse response) {
        incStackOffset();
        addIntegrationError(area, e, request, response);
        resetStackOffset();
        flushTop();
    }

    /**
    * Add Log with Integration Category.
    * This method will automatically get the stacktrace from Exception.
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param e -- instance of an Exception
    * @param request -- RestRequest of the issue. Saves to log record Details field
    * @param response -- RestResponse of the issue. Saves to log record Details field
    */
    public void addIntegrationError(TritonTypes.Area area, Exception e, RestRequest request, RestResponse response) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Integration)
                        .type(String.isBlank(e.getTypeName()) ? TritonTypes.Type.Backend.name() : e.getTypeName())
                        .area(area)
                        .summary(e.getMessage())
                        .details(String.valueOf(e) + SPACE_SEP + e.getStackTraceString())
                        .stackTrace(e.getStackTraceString())
                        .createIssue()
                        .integrationPayload(request, response)
                        .transactionId(TRANSACTION_ID)                        
                        .level(TritonTypes.Level.ERROR)
                        .build());
    }

    /**
    * Immediate
    */
    public void integrationError(TritonTypes.Area area, Exception e, RestRequest request, RestResponse response) {
        incStackOffset();
        addIntegrationError(area, e, request, response);
        resetStackOffset();
        flushTop();
    }

    /**
    * Add Log with Integration Category.
    * This method will automatically get the stacktrace.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    * @param request -- HttpRequest of the issue. Saves to log record Details field
    * @param response -- HttpResponse of the issue. Saves to log record Details field
    */
    public void addIntegrationError(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        HttpRequest request,
        HttpResponse response
    ) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Integration)
                        .type(type)
                        .area(area)
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .createIssue()
                        .integrationPayload(request,response)
                        .transactionId(TRANSACTION_ID)                        
                        .level(TritonTypes.Level.ERROR)
                        .build());
    }

    /**
    * Immediate
    */
    public void integrationError(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        HttpRequest request,
        HttpResponse response
    ) {
        incStackOffset();
        addIntegrationError(type, area, summary, details, request, response);
        flush();
    }

    /**
    * Add Log with Integration Category.
    * This method will automatically get the stacktrace.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    * @param request -- RestRequest of the issue. Saves to log record Details field
    * @param response -- RestResponse of the issue. Saves to log record Details field
    */
    public void addIntegrationError(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        RestRequest request,
        RestResponse response
    ) {
        add(
                fromTemplate()
                        .category(TritonTypes.Category.Integration)
                        .type(type)
                        .area(area)
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .createIssue()
                        .integrationPayload(request, response)
                        .transactionId(TRANSACTION_ID)                        
                        .level(TritonTypes.Level.ERROR)
                        .build());
    }

    /**
    * Immediate
    */
    public void integrationError(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        RestRequest request,
        RestResponse response
    ) {
        incStackOffset();
        addIntegrationError(type, area, summary, details, request, response);
        flush();
    }

    /**
    * Add Log with DML results.
    * This method will automatically get the stacktrace and save it on the log record.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param dmlResults -- Array of Database.SaveResult, Database.DeleteResult, etc
    */
    public void addDMLResult(TritonTypes.Area area, List<Object> dmlResults) {
        Set<String> failedIds = new Set<String>();
        List<String> errorMessages = new List<String>();
        String operation;
        Integer failCount = 0;
        Integer totalCount = dmlResults.size();

        for(Object result : dmlResults) {
            if(result instanceof Database.SaveResult) {
                operation = 'Save';
                Database.SaveResult sr = (Database.SaveResult)result;
                if(!sr.isSuccess()) {
                    failCount++;
                    failedIds.add(sr.getId());
                    for(Database.Error err : sr.getErrors()) {
                        errorMessages.add(err.getMessage());
                    }
                }
            } else if(result instanceof Database.DeleteResult) {
                operation = 'Delete';
                Database.DeleteResult dr = (Database.DeleteResult)result;
                if(!dr.isSuccess()) {
                    failCount++;
                    failedIds.add(dr.getId());
                    for(Database.Error err : dr.getErrors()) {
                        errorMessages.add(err.getMessage());
                    }
                }
            } else if(result instanceof Database.UndeleteResult) {
                operation = 'Undelete';
                Database.UndeleteResult ur = (Database.UndeleteResult)result;
                if(!ur.isSuccess()) {
                    failCount++;
                    failedIds.add(ur.getId());
                    for(Database.Error err : ur.getErrors()) {
                        errorMessages.add(err.getMessage());
                    }
                }
            } else if(result instanceof Database.UpsertResult) {
                operation = 'Upsert';
                Database.UpsertResult ur = (Database.UpsertResult)result;
                if(!ur.isSuccess()) {
                    failCount++;
                    failedIds.add(ur.getId());
                    for(Database.Error err : ur.getErrors()) {
                        errorMessages.add(err.getMessage());
                    }
                }
            } else if(result instanceof Database.MergeResult) {
                operation = 'Merge';
                Database.MergeResult mr = (Database.MergeResult)result;
                if(!mr.isSuccess()) {
                    failCount++;
                    failedIds.add(mr.getId());
                    for(Database.Error err : mr.getErrors()) {
                        errorMessages.add(err.getMessage());
                    }
                }
            }
        }

        if(!errorMessages.isEmpty()) {
            add(
                fromTemplate()
                    .category(TritonTypes.Category.Apex)
                    .type(TritonTypes.Type.DMLResult)
                    .area(area)
                    .operation(operation)
                    .summary(TritonHelper.formatMessage('DML Operation ({0}) Failed: {1} of {2} records failed.', 
                                                            new String[]{operation, 
                                                                        String.valueOf(failCount), 
                                                                        String.valueOf(totalCount)}))
                    .details(String.join(errorMessages, SPACE_SEP))
                    .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                    .relatedObjects(failedIds)
                    .transactionId(TRANSACTION_ID)
                    .level(TritonTypes.Level.ERROR)
                    .createIssue()
                    .build());
        }
    }

    /**
    * Immediate version of addDMLResult
    * Logs DML operation results and immediately flushes to database
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param dmlResults -- Array of Database.SaveResult, Database.DeleteResult, etc
    */
    public void dmlResult(TritonTypes.Area area, List<Object> dmlResults) {
        incStackOffset();
        addDMLResult(area, dmlResults);
        resetStackOffset();
        flushTop();
    }

    /**
    * Checks if a log should be persisted based on the current log level
    * @param log -- Pharos log record to be saved
    * @return -- true if current log's level is below the level set in the settings, false otherwise
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
        for (String key : permutations) {
            if (LOG_LEVELS.containsKey(key)) {
                if (TritonHelper.compareLevel(LOG_LEVELS.get(key), currentLevel)) return true;
            }
        }

        return false;
    }
}
