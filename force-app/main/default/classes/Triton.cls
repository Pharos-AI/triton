/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

public without sharing class Triton {

    /** key field names for setting attributes on log records */
    public static final String APEX_NAME = 'pharos__Apex_Name__c';
    public static final String CREATED_TIMESTAMP = 'pharos__Created_Timestamp__c';
    public static final String DURATION = 'pharos__Duration__c';
    public static final String INTERVIEW_GUID = 'pharos__Interview_GUID_External__c';
    public static final String LOG_LEVEL = 'Log_Level__c';
    public static final String RELATED_ID = 'pharos__Related_Id__c';
    public static final String RELATED_OBJECTS = 'pharos__Related_Objects__c';
    public static final String STACKTRACE_PARSE_RESULT = 'pharos__Stacktrace_Parse_Result__c';
    public static final String USER_ID = 'pharos__User_Id__c';
    public static final String FLOW_API_NAME = 'pharos__Flow_API_Name__c';

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


    // Constructor
    private Triton(pharos.Logger logger) {
        this.logger = logger;
    }


    /**
    * Adds a log to the buffer.
    * Performs a check on current log level prior
    * @param log -- Pharos log record
    */
    public void add(pharos__Log__c log) {
        if (isLogAllowedForLogLevel(log)) {
            this.logger.add(log);
        }
    }

    /**
    * Persist Log records immediately.
    * Use this method to persist logs to the database right away.
    */
    public void flush() {
        this.logger.flush();
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
    public static pharos.LogBuilder makeBuilder() {
        return pharos.LogBuilder.getInstance();
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
    * Add Log with Error Category.
    * This method will automatically get the stacktrace and save it on the log record.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addError(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        add(
                makeBuilder()
                        .category(TritonTypes.Category.Apex.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .transactionId(TRANSACTION_ID)
                        .createIssue()
                        .attribute(LOG_LEVEL, TritonTypes.Level.ERROR.name())
                        .build());
    }

    /**
    * Immediate
    */
    public void error(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        incStackOffset();
        addError(type, area, summary, details);
        flush();
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
                makeBuilder()
                        .category(TritonTypes.Category.Apex.name())
                        //use exception type, Backend if blank
                        .type(String.isBlank(e.getTypeName()) ? TritonTypes.Type.Backend.name() : e.getTypeName())
                        .area(area.name())
                        .summary(e.getMessage())
                        .stackTrace(e.getStackTraceString())
                        .details(String.valueOf(e) + SPACE_SEP + e.getStackTraceString())
                        .transactionId(TRANSACTION_ID)
                        .attribute(RELATED_OBJECTS, relatedObjectIds?.size() > 0 ? 
                                        JSON.serialize(relatedObjectIds) : null)
                        .attribute(LOG_LEVEL, TritonTypes.Level.ERROR.name())
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
        flush();
        resetStackOffset();
    }

    public void error(TritonTypes.Area area, Exception e) {
        incStackOffset();
        error(area, e, null);
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
                makeBuilder()
                        .category(TritonTypes.Category.Warning.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .postProcessing(
                                new TritonHelper.PostProcessingControlsBuilder()
                                        .stackTrace(true)
                                        .userInfo(true)
                                        .objectInfo(true)
                                        .build())
                        .transactionId(TRANSACTION_ID)
                        .attribute(LOG_LEVEL, TritonTypes.Level.WARNING.name())
                        .build());
    }

    /**
    * Immediate
    */
    public void warning(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        incStackOffset();
        addWarning(type, area, summary, details);
        flush();
        resetStackOffset();
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
                makeBuilder()
                        .category(TritonTypes.Category.Debug.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .postProcessing(
                                new TritonHelper.PostProcessingControlsBuilder()
                                        .stackTrace(true)
                                        .userInfo(true)
                                        .objectInfo(true)
                                        .build())
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .transactionId(TRANSACTION_ID)
                        .attribute(LOG_LEVEL, TritonTypes.Level.DEBUG.name())
                        .build());
    }

    /**
    * Immediate
    */
    public void debug(TritonTypes.Type type, TritonTypes.Area area, String summary, String details) {
        incStackOffset();
        addDebug(type, area, summary, details);
        flush();
        resetStackOffset();
    }

    /**
    * Add Log with Debug Category.
    * This method will automatically get the stacktrace.
    * @param type -- log record TritonTypes.Type (see Type enum)
    * @param area -- log record Functional TritonTypes.Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addDebug(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        Decimal duration
    ) {
        add(
                makeBuilder()
                        .category(TritonTypes.Category.Debug.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .postProcessing(
                                new TritonHelper.PostProcessingControlsBuilder()
                                        .stackTrace(true)
                                        .userInfo(true)
                                        .objectInfo(true)
                                        .build())
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .transactionId(TRANSACTION_ID)
                        .attribute(LOG_LEVEL, TritonTypes.Level.DEBUG.name())
                        .attribute(Triton.DURATION, duration)
                        .build());
    }

    /**
    * Immediate
    */
    public void debug(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, Decimal duration) {
        incStackOffset();
        addDebug(type, area, summary, details, duration);
        flush();
        resetStackOffset();
    }

    /**
    * Add Log with Event Category.
    * Default INFO log level
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
                makeBuilder()
                        .category(TritonTypes.Category.Event.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .postProcessing(
                                new TritonHelper.PostProcessingControlsBuilder()
                                        .stackTrace(true)
                                        .userInfo(true)
                                        .objectInfo(true)
                                        .build())
                        .transactionId(TRANSACTION_ID)
                        .attribute(LOG_LEVEL, level.name())
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
        flush();
        resetStackOffset();
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
                makeBuilder()
                        .category(TritonTypes.Category.Integration.name())
                        //Use Backend as default type
                        .type(String.isBlank(e.getTypeName()) ? TritonTypes.Type.Backend.name() : e.getTypeName())
                        .area(area.name())
                        .summary(e.getMessage())
                        .details(String.valueOf(e) + SPACE_SEP + e.getStackTraceString())
                        .stackTrace(e.getStackTraceString())
                        .createIssue()
                        //Set the system field with a json serialized request/response value
                        .attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response))
                        .attribute(LOG_LEVEL, TritonTypes.Level.ERROR.name())
                        .build());
    }

    /**
    * Immediate
    */
    public void integrationError(TritonTypes.Area area, Exception e, HttpRequest request, HttpResponse response) {
        incStackOffset();
        addIntegrationError(area, e, request, response);
        flush();
        resetStackOffset();
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
                makeBuilder()
                        .category(TritonTypes.Category.Integration.name())
                        .type(String.isBlank(e.getTypeName()) ? TritonTypes.Type.Backend.name() : e.getTypeName())
                        .area(area.name())
                        .summary(e.getMessage())
                        .details(String.valueOf(e) + SPACE_SEP + e.getStackTraceString())
                        .stackTrace(e.getStackTraceString())
                        .createIssue()
                        .attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response))
                        .attribute(LOG_LEVEL, TritonTypes.Level.ERROR.name())
                        .build());
    }

    /**
    * Immediate
    */
    public void integrationError(TritonTypes.Area area, Exception e, RestRequest request, RestResponse response) {
        incStackOffset();
        addIntegrationError(area, e, request, response);
        flush();
        resetStackOffset();
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
        incStackOffset();
        add(
                makeBuilder()
                        .category(TritonTypes.Category.Integration.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .createIssue()
                        .attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request,response))
                        .attribute(LOG_LEVEL, TritonTypes.Level.ERROR.name())
                        .build());
        resetStackOffset();
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
                makeBuilder()
                        .category(TritonTypes.Category.Integration.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .createIssue()
                        .attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response))
                        .attribute(LOG_LEVEL, TritonTypes.Level.ERROR.name())
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
