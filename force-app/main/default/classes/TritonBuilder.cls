/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

/**x
 * Builder class for creating and configuring Pharos log records.
 * Provides a fluent interface to set various attributes like category, type, area,
 * related objects, and other metadata for logging purposes. This class wraps the core
 * pharos.LogBuilder to provide a more user-friendly API for log creation.
 */
public with sharing class TritonBuilder {

    /** key field names for setting attributes on log records */
    public static final String APEX_NAME = 'pharos__Apex_Name__c';
    public static final String ACTION = 'Action__c';
    public static final String CREATED_TIMESTAMP = 'pharos__Created_Timestamp__c';
    public static final String DURATION = 'pharos__Duration__c';
    public static final String INTERVIEW_GUID = 'pharos__Interview_GUID_External__c';
    public static final String LOG_LEVEL = 'Log_Level__c';
    public static final String RELATED_ID = 'pharos__Related_Id__c';
    public static final String RELATED_OBJECTS = 'pharos__Related_Objects__c';
    public static final String STACKTRACE_PARSE_RESULT = 'pharos__Stacktrace_Parse_Result__c';
    public static final String USER_ID = 'pharos__User_Id__c';
    public static final String FLOW_API_NAME = 'pharos__Flow_API_Name__c';
    public static final String DO_NOT_CREATE_ISSUE = 'pharos__Do_Not_Create_Issue__c';
    public static final String REQUEST_ID = 'pharos__Request_Id_External__c';
    public static final String SPAN_ID = 'Span_Id__c';
    public static final String PARENT_SPAN_ID = 'Parent_Span_Id__c';

    /** transaction limit field names */
    @TestVisible
    private static final String SOQL_QUERIES = 'SOQL_Queries__c';
    @TestVisible
    private static final String SOQL_QUERIES_LIMIT = 'SOQL_Queries_Limit__c';
    @TestVisible
    private static final String SOQL_ROWS = 'SOQL_Rows__c';
    @TestVisible
    private static final String SOQL_ROWS_LIMIT = 'SOQL_Rows_Limit__c';
    @TestVisible
    private static final String SOQL_AGGREGATES = 'SOQL_Aggregates__c';
    @TestVisible
    private static final String SOQL_AGGREGATES_LIMIT = 'SOQL_Aggregates_Limit__c';
    @TestVisible
    private static final String DML_STATEMENTS = 'DML_Statements__c';
    @TestVisible
    private static final String DML_STATEMENTS_LIMIT = 'DML_Statements_Limit__c';
    @TestVisible
    private static final String DML_ROWS = 'DML_Rows__c';
    @TestVisible
    private static final String DML_ROWS_LIMIT = 'DML_Rows_Limit__c';
    @TestVisible
    private static final String CPU_TIME = 'CPU_Time__c';
    @TestVisible
    private static final String CPU_TIME_LIMIT = 'CPU_Time_Limit__c';
    @TestVisible
    private static final String HEAP_SIZE = 'Heap_Size__c';
    @TestVisible
    private static final String HEAP_SIZE_LIMIT = 'Heap_Size_Limit__c';
    @TestVisible
    private static final String CALLOUTS = 'Callouts__c';
    @TestVisible
    private static final String CALLOUTS_LIMIT = 'Callouts_Limit__c';
    @TestVisible
    private static final String SOSL_QUERIES = 'SOSL_Queries__c';
    @TestVisible
    private static final String SOSL_QUERIES_LIMIT = 'SOSL_Queries_Limit__c';
    @TestVisible
    private static final String FUTURE_CALLS = 'Future_Calls__c';
    @TestVisible
    private static final String FUTURE_CALLS_LIMIT = 'Future_Calls_Limit__c';
    @TestVisible
    private static final String QUEUEABLE_JOBS = 'Queueable_Jobs__c';
    @TestVisible
    private static final String QUEUEABLE_JOBS_LIMIT = 'Queueable_Jobs_Limit__c';
    @TestVisible
    private static final String EMAIL_INVOCATIONS = 'Email_Invocations__c';
    @TestVisible
    private static final String EMAIL_INVOCATIONS_LIMIT = 'Email_Invocations_Limit__c';
    @TestVisible
    private static final String PUSH_NOTIFICATIONS = 'Push_Notifications__c';
    @TestVisible
    private static final String PUSH_NOTIFICATIONS_LIMIT = 'Push_Notifications_Limit__c';
    @TestVisible
    private static final String BATCH_JOBS = 'Batch_Jobs__c';
    @TestVisible
    private static final String BATCH_JOBS_LIMIT = 'Batch_Jobs_Limit__c';
    @TestVisible
    private static final String PUBLISH_IMMEDIATE_DML = 'Publish_Immediate_DML__c';
    @TestVisible
    private static final String PUBLISH_IMMEDIATE_DML_LIMIT = 'Publish_Immediate_DML_Limit__c';

    @TestVisible
    private Boolean includeLimitInfo = true;
    @TestVisible
    private Boolean traceable = false;

    private pharos.LogBuilder builder;
    
    @TestVisible
    private Boolean fullLimitInfoRequested = false;

    private String fullSummary;
    @TestVisible
    private String executionContextDetails;
    private String categoryValue;
    @TestVisible
    private String currentSpanId;
    @TestVisible
    private String currentParentSpanId;

    public TritonBuilder cloneBuilder() {
        pharos__Log__c clonedLog = this.builder.build().clone(false, true, false, false);
        TritonBuilder cloned = new TritonBuilder();
        
        // Only iterate POPULATED fields (10-20, not all 50-100)
        for (String field : clonedLog.getPopulatedFieldsAsMap().keySet()) {
            cloned.builder.attribute(field, clonedLog.get(field));
        }
        
        cloned.includeLimitInfo = this.includeLimitInfo;
        cloned.fullLimitInfoRequested = this.fullLimitInfoRequested;
        cloned.traceable = this.traceable;
        cloned.categoryValue = this.categoryValue;
        cloned.currentSpanId = this.currentSpanId;
        cloned.currentParentSpanId = this.currentParentSpanId;
        // fullSummary and executionContextDetails are intentionally NOT cloned — per-log values
        cloned.initBuilder();
        return cloned;
    }

    public TritonBuilder() {
        this.builder = pharos.LogBuilder.getInstance();
        initBuilder();
    }

    private void initBuilder() {
        createdTimestamp();
        this.builder.attribute(DO_NOT_CREATE_ISSUE, true);
        this.builder.attribute(REQUEST_ID, System.Request.getCurrent().getRequestId());
    }

    /**
    * Set log category from Category enum.
    * @param c -- TritonTypes.Category enum value
    * @return this builder instance
    */
    public TritonBuilder category(TritonTypes.Category c) {
        this.categoryValue = c.name();
        this.builder.category(c.name());
        return this;
    }

    /**
    * Set log category from Category enum.
    * @param t -- TritonTypes.Type enum value
    * @return this builder instance
    */
    public TritonBuilder type(TritonTypes.Type t) {
        this.builder.type(t.name());
        return this;
    }

    /**
    * Set log type to a String value. To be used when creating a log from Exception
    * @param t -- String value
    * @return this builder instance
    */
    public TritonBuilder type(String t) {
        this.builder.type(t);
        return this;
    }

    /**
    * Set log functional are from Area enum.
    * @param a -- TritonTypes.Area value
    * @return this builder instance
    */
    public TritonBuilder area(TritonTypes.Area a) {
        this.builder.area(a.name());
        return this;
    }

    /**
    * Set log functional area to a String value. To be used from flows
    * @param a -- String value
    * @return this builder instance
    */
    public TritonBuilder area(String a) {
        this.builder.area(a);
        return this;
    }

    /**
    * Set log level from Level enum.
    * @param l -- TritonTypes.Level enum value
    * @return this builder instance
    */
    public TritonBuilder level(TritonTypes.Level l) {
        this.builder.attribute(LOG_LEVEL, l.name());
        return this;
    }

    /**
     * Convenience methods for setting common levels
     */
    public TritonBuilder error() {
        return this.level(TritonTypes.Level.ERROR).createIssue();
    }
    public TritonBuilder error(String summary) { return this.summary(summary).error(); }

    public TritonBuilder warning() {
        return this.level(TritonTypes.Level.WARNING);
    }
    public TritonBuilder warning(String summary) { return this.summary(summary).warning(); }

    public TritonBuilder info() {
        return this.level(TritonTypes.Level.INFO);
    }
    public TritonBuilder info(String summary) { return this.summary(summary).info(); }

    public TritonBuilder debug() {
        return this.level(TritonTypes.Level.DEBUG);
    }
    public TritonBuilder debug(String summary) { return this.summary(summary).debug(); }

    public TritonBuilder fine() {
        return this.level(TritonTypes.Level.FINE);
    }
    public TritonBuilder fine(String summary) { return this.summary(summary).fine(); }

    public TritonBuilder finer() {
        return this.level(TritonTypes.Level.FINER);
    }
    public TritonBuilder finer(String summary) { return this.summary(summary).finer(); }

    public TritonBuilder finest() {
        return this.level(TritonTypes.Level.FINEST);
    }
    public TritonBuilder finest(String summary) { return this.summary(summary).finest(); }

    /**
     * Captures the current Salesforce execution context.
     * For triggers: operation type, sObject, batch size.
     * For async contexts (batch, queueable, scheduled, future): labels the context type.
     * Appended to details at build time.
     */
    public TritonBuilder apexExecutionContext() {
        this.executionContextDetails = TritonHelper.formatExecutionContext();
        return this;
    }

    /**
    * Set operation from a String value
    * @param operation -- operation String value
    * @return this builder instance
    */
    public TritonBuilder operation(String operation) {
        this.builder.attribute(APEX_NAME, operation);
        return this;
    }

    /**
    * Set log summary from a String value
    * @param summary -- summary String value
    * @return this builder instance
    */
    public TritonBuilder summary(String value) {
        this.fullSummary = value;
        this.builder.summary(value != null && value.length() > 255 ? value.left(255) : value);
        return this;
    }

    /**
    * Set log details from a String value
    * @param details -- details String value
    * @return this builder instance
    */
    public TritonBuilder details(String value) {
		this.builder.details(value);
		return this;
	}

    /**
    * Set stack trace from a String value
    * @param stack -- stack trace String value
    * @return this builder instance
    */
    public TritonBuilder stackTrace(String stack) {
		this.builder.stackTrace(stack);
		return this;
	}

    /**
    * Set post processing metadata from a PostProcessingControlsBuilder instance
    * @param postProcessingBuilder -- instance of TritonHelper.PostProcessingControlsBuilder
    * @return this builder instance
    */
    public TritonBuilder postProcessing(TritonHelper.PostProcessingControlsBuilder postProcessingBuilder) {
        this.builder.postProcessing(postProcessingBuilder.build());
        return this;
    }

    /**
    * Set transaction Id from a String
    * @param transactionId -- desired transaction Id String value
    * @return this builder instance
    */
    public TritonBuilder transactionId(String transactionId) {
		this.builder.transactionId(transactionId);
        return this;
	}

    /**
    * Set issue creation flag
    * @return this builder instance
    */
    public TritonBuilder createIssue() {
		this.builder.createIssue();
		return this;
	}    

    /**
    * Set user Id for the log
    * @param userId -- Id of the user to associate with the log
    * @return this builder instance
    */
    public TritonBuilder userId(Id userId) {
        this.builder.attribute(USER_ID, userId);
        return this;
    }

    /**
    * Add a single related object Id to the log
    * @param objectId -- Id of the object to relate to the log
    * @return this builder instance
    */
    public TritonBuilder relatedObject(Id objectId) {
        if(objectId == null) return this;
        return relatedObjects(new Id[]{objectId});
    }

    /**
    * Add a single related object Id string to the log
    * @param objectId -- String representation of the Id to relate to the log
    * @return this builder instance
    */
    public TritonBuilder relatedObject(String objectId) {
        try {
            return relatedObject(Id.valueOf(objectId));
        } catch(System.StringException e) {
            //invalid Id, ignore
        }
        return this;
    }

    /**
    * Add multiple related object Ids to the log
    * @param relatedObjectIds -- List of Ids to relate to the log
    * @return this builder instance
    */
    public TritonBuilder relatedObjects(List<Id> relatedObjectIds) {
        return relatedObjects(new Set<Id>(relatedObjectIds));
    }

    /**
    * Add multiple related object Id strings to the log
    * @param relatedObjectIds -- List of Id strings to relate to the log
    * @return this builder instance
    */
    public TritonBuilder relatedObjects(List<String> relatedObjectIds) {       
        return relatedObjects(new Set<String>(relatedObjectIds));
    }


    /**
    * Add multiple related object Id strings to the log
    * @param relatedObjectIds -- Set of Id strings to relate to the log
    * @return this builder instance
    */
    public TritonBuilder relatedObjects(Set<String> relatedObjectIds) {
        if(relatedObjectIds == null || relatedObjectIds.size() == 0) return this;

        Set<Id> ids = new Set<Id>();
        for(String obj : relatedObjectIds) {
            try {
                ids.add(Id.valueOf(obj));
            } catch (Exception e) {
                //invalid Id, ignore
            }
        }
        return relatedObjects(ids);
    }

    /**
    * Add multiple related object Ids to the log
    * @param relatedObjectIds -- Set of Ids to relate to the log
    * @return this builder instance
    */
    public TritonBuilder relatedObjects(Set<Id> relatedObjectIds) {
        this.builder.attribute(RELATED_OBJECTS, relatedObjectIds?.size() > 0 ? 
                                        JSON.serialize(relatedObjectIds) : null);
        return this;                                        
    }

    /**
    * Set created timestamp for the log
    * @param timestamp -- Double value representing the creation timestamp
    * @return this builder instance
    */
    public TritonBuilder createdTimestamp(Double timestamp) {
        this.builder.attribute(CREATED_TIMESTAMP, timestamp);
        return this;
    }

    /**
    * Set created timestamp for the log to current time
    * @return this builder instance
    */
    public TritonBuilder createdTimestamp() {
        return createdTimestamp(Double.valueOf(System.now().getTime()));
    }

    /**
    * Set duration for the log
    * @param duration -- Decimal value representing the duration
    * @return this builder instance
    */
    public TritonBuilder duration(Decimal duration) {
        this.builder.attribute(TritonBuilder.DURATION, duration);
        return this;
    }

    /**
    * Set action name for the log
    * @param action -- String value representing the action name (e.g., performance mark, backend call, user interaction name)
    * @return this builder instance
    */
    public TritonBuilder action(String action) {
        this.builder.attribute(TritonBuilder.ACTION, action);
        return this;
    }

    /**
    * Set span ID for the log
    * @param spanId -- String value representing the span identifier
    * @return this builder instance
    */
    public TritonBuilder spanId(String spanId) {
        this.currentSpanId = spanId;
        this.builder.attribute(SPAN_ID, spanId);
        return this;
    }

    /**
    * Set parent span ID for the log
    * @param parentSpanId -- String value representing the parent span identifier
    * @return this builder instance
    */
    public TritonBuilder parentSpanId(String parentSpanId) {
        this.currentParentSpanId = parentSpanId;
        this.builder.attribute(PARENT_SPAN_ID, parentSpanId);
        return this;
    }

    /**
    * Set integration payload from HTTP request/response
    * @param request -- HttpRequest instance
    * @param response -- HttpResponse instance
    * @return this builder instance
    */
    public TritonBuilder integrationPayload(HttpRequest request, HttpResponse response) {
        this.builder.attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
        return this;
    }

    /**
    * Set integration payload from REST request/response
    * @param request -- RestRequest instance
    * @param response -- RestResponse instance
    * @return this builder instance
    */
    public TritonBuilder integrationPayload(RestRequest request, RestResponse response) {
        this.builder.attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
        return this;
    }

    /**
    * Set interview GUID for the log
    * @param guid -- String value of the interview GUID
    * @return this builder instance
    */
    public TritonBuilder interviewGuid(String guid) {
        this.builder.attribute(INTERVIEW_GUID, guid);
        return this;
    }

    /**
    * Set flow API name for the log
    * @param apiName -- String value of the flow API name
    * @return this builder instance
    */
    public TritonBuilder flowApiName(String apiName) {
        this.builder.attribute(FLOW_API_NAME, apiName);
        return this;
    }

    /**
    * Set to not include limit info in the log record
    * @return this builder instance
    */
    public TritonBuilder withoutLimitInfo() {
        this.includeLimitInfo = false;
        return this;
    }

    /**
    * Request full limit info (extended limits) in addition to essential limits when limitInfo() is called
    * @return this builder instance
    */
    public TritonBuilder withFullLimitInfo() {
        this.fullLimitInfoRequested = true;
        return this;
    }

    /**
    * Set a custom attribute on the log
    * @param name -- String name of the attribute
    * @param value -- Object value of the attribute
    * @return this builder instance
    */
    public TritonBuilder attribute(String name, Object value) {
        this.builder.attribute(name, value);
        return this;
    }

    /**
    * Set a trace point on the log
    * @return this builder instance
    */
    public TritonBuilder tracePoint() {
        if (this.traceable) {
            this.builder.tracePoint();
            System.debug('TRACEPOINT:'+ this.builder.getTraceId());
        }
        return this;
    }

    /**
    * Set traceable flag
    * @param traceable -- Boolean value to set the traceable flag
    * @return this builder instance
    */
    public TritonBuilder traceable(Boolean traceable) {
        this.traceable = traceable;
        if(traceable) {
            this.createIssue();
        }
        return this;
    }

    /**
    * Captures current transaction usage and limits from System.Limits and adds them as attributes on the log record.
    * When includeLimitInfo is true, captures essential limits (SOQL, DML, CPU, heap, callouts).
    * When fullLimitInfoRequested is also true, additionally captures extended limits (aggregates, SOSL, future calls, queueable jobs, email invocations, push notifications, batch jobs, publish immediate DML).
    * No-op when includeLimitInfo is false.
    * @return this builder instance
    */
    public TritonBuilder limitInfo() {
        if (this.includeLimitInfo) {
            TritonBuilder builder = this.limitInfoLite();
            if(this.fullLimitInfoRequested) {
                builder.attribute(SOQL_AGGREGATES, System.Limits.getAggregateQueries())
                        .attribute(SOQL_AGGREGATES_LIMIT, System.Limits.getLimitAggregateQueries())
                        .attribute(SOSL_QUERIES, System.Limits.getSoslQueries())
                        .attribute(SOSL_QUERIES_LIMIT, System.Limits.getLimitSoslQueries())
                        .attribute(FUTURE_CALLS, System.Limits.getFutureCalls())
                        .attribute(FUTURE_CALLS_LIMIT, System.Limits.getLimitFutureCalls())
                        .attribute(QUEUEABLE_JOBS, System.Limits.getQueueableJobs())
                        .attribute(QUEUEABLE_JOBS_LIMIT, System.Limits.getLimitQueueableJobs())
                        .attribute(EMAIL_INVOCATIONS, System.Limits.getEmailInvocations())
                        .attribute(EMAIL_INVOCATIONS_LIMIT, System.Limits.getLimitEmailInvocations())
                        .attribute(PUSH_NOTIFICATIONS, System.Limits.getMobilePushApexCalls())
                        .attribute(PUSH_NOTIFICATIONS_LIMIT, System.Limits.getLimitMobilePushApexCalls())
                        .attribute(BATCH_JOBS, System.Limits.getAsyncCalls())
                        .attribute(BATCH_JOBS_LIMIT, System.Limits.getLimitAsyncCalls())
                        .attribute(PUBLISH_IMMEDIATE_DML, System.Limits.getPublishImmediateDML())
                        .attribute(PUBLISH_IMMEDIATE_DML_LIMIT, System.Limits.getLimitPublishImmediateDML());
            }
            return builder;
        }
        return this;
    }

    /**
    * Captures and sets the essential transaction limits (CPU Time, Heap Size, DML Statements) on the log record
    * @return this builder instance
    */
    public TritonBuilder limitInfoLite() {
        return this
            .attribute(SOQL_QUERIES, System.Limits.getQueries())
            .attribute(SOQL_QUERIES_LIMIT, System.Limits.getLimitQueries())
            .attribute(SOQL_ROWS, System.Limits.getQueryRows())
            .attribute(SOQL_ROWS_LIMIT, System.Limits.getLimitQueryRows())
            .attribute(DML_STATEMENTS, System.Limits.getDMLStatements())
            .attribute(DML_STATEMENTS_LIMIT, System.Limits.getLimitDMLStatements())
            .attribute(DML_ROWS, System.Limits.getDMLRows())
            .attribute(DML_ROWS_LIMIT, System.Limits.getLimitDMLRows())
            .attribute(CPU_TIME, System.Limits.getCpuTime())
            .attribute(CPU_TIME_LIMIT, System.Limits.getLimitCpuTime())
            .attribute(HEAP_SIZE, System.Limits.getHeapSize())
            .attribute(HEAP_SIZE_LIMIT, System.Limits.getLimitHeapSize())
            .attribute(CALLOUTS, System.Limits.getCallouts())
            .attribute(CALLOUTS_LIMIT, System.Limits.getLimitCallouts());
    }

    /**
    * Configure builder for an exception
    * Sets type from exception type (or defaults to Backend), sets error level,
    * sets summary from exception message, sets details and stack trace from exception
    * @param e -- Exception to configure the builder with
    * @return this builder instance
    */
    public TritonBuilder exception(Exception e) {
        if (e == null) return this;

        // Use exception type, Backend if blank
        this.type(String.isBlank(e.getTypeName()) ?
            TritonTypes.Type.Backend.name() :
            e.getTypeName());

        this.level(TritonTypes.Level.ERROR)
            .summary(e.getMessage())
            .stackTrace(e.getStackTraceString())
            .details(String.valueOf(e) + Triton.SPACE_SEP + e.getStackTraceString())
            .createIssue();

        return this;
    }

    /**
     * Formats DML operation results and adds them to the log
     * Area should be set via template or explicitly before calling this method
     * @param dmlResults List of Database.SaveResult, DeleteResult, UpsertResult, UndeleteResult, or MergeResult
     * @return TritonBuilder for chaining
     */
    public TritonBuilder dmlResults(List<Object> dmlResults) {
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
                    if (sr.getId() != null) {
                        failedIds.add(sr.getId());
                    }
                    for(Database.Error err : sr.getErrors()) {
                        errorMessages.add(TritonHelper.formatDMLError(err, sr.getId()));
                    }
                }
            } else if(result instanceof Database.DeleteResult) {
                operation = 'Delete';
                Database.DeleteResult dr = (Database.DeleteResult)result;
                if(!dr.isSuccess()) {
                    failCount++;
                    if (dr.getId() != null) {
                        failedIds.add(dr.getId());
                    }
                    for(Database.Error err : dr.getErrors()) {
                        errorMessages.add(TritonHelper.formatDMLError(err, dr.getId()));
                    }
                }
            } else if(result instanceof Database.UndeleteResult) {
                operation = 'Undelete';
                Database.UndeleteResult ur = (Database.UndeleteResult)result;
                if(!ur.isSuccess()) {
                    failCount++;
                    if (ur.getId() != null) {
                        failedIds.add(ur.getId());
                    }
                    for(Database.Error err : ur.getErrors()) {
                        errorMessages.add(TritonHelper.formatDMLError(err, ur.getId()));
                    }
                }
            } else if(result instanceof Database.UpsertResult) {
                operation = 'Upsert';
                Database.UpsertResult ur = (Database.UpsertResult)result;
                if(!ur.isSuccess()) {
                    failCount++;
                    if (ur.getId() != null) {
                        failedIds.add(ur.getId());
                    }
                    for(Database.Error err : ur.getErrors()) {
                        errorMessages.add(TritonHelper.formatDMLError(err, ur.getId()));
                    }
                }
            } else if(result instanceof Database.MergeResult) {
                operation = 'Merge';
                Database.MergeResult mr = (Database.MergeResult)result;
                if(!mr.isSuccess()) {
                    failCount++;
                    if (mr.getId() != null) {
                        failedIds.add(mr.getId());
                    }
                    for(Database.Error err : mr.getErrors()) {
                        errorMessages.add(TritonHelper.formatDMLError(err, mr.getId()));
                    }
                }
            }
        }

        // Only log if there are errors
        if(!errorMessages.isEmpty()) {
            return this.type(TritonTypes.Type.DMLResult)
                .operation(operation)
                .summary(TritonHelper.formatMessage('DML Operation ({0}) Failed: {1} of {2} records failed.',
                                                    new String[]{operation,
                                                                String.valueOf(failCount),
                                                                String.valueOf(totalCount)}))
                .details(String.join(errorMessages, '\n\n'))
                .stackTrace(TritonHelper.getCurrentStackTrace())
                .relatedObjects(failedIds)
                .error();
        }

        return this;
    }

    /**
    * Ensures span IDs are populated with sensible defaults when not explicitly set.
    * Uses the request ID as span ID fallback for Apex-originated logs.
    */
    private void ensureSpanIds() {
        if (String.isBlank(this.currentSpanId)) {
            String requestId = System.Request.getCurrent().getRequestId();
            this.builder.attribute(SPAN_ID, requestId);
        }
    }

    /**
    * Captures the stacktrace and derives the operation from it when neither was
    * supplied explicitly. Idempotent: once a stacktrace is present this is a
    * no-op, so it is safe to call before the log level check and again from
    * prepareForLogging.
    *
    * Triton.log() calls this ahead of the log level check when component-scoped
    * log levels are configured, because matching on component name requires the
    * Apex Name to already be resolved. Throwing and filtering a stacktrace is
    * comparatively expensive, which is why the early call is gated rather than
    * unconditional.
    * @see TritonHelper.Config.hasComponentScopedLevels
    * @return this builder instance
    */
    public TritonBuilder resolveStackTraceAndOperation() {
        pharos__Log__c tempLog = this.builder.build();
        if(String.isBlank(tempLog.pharos__Stacktrace__c)) {
            String stackTrace = TritonHelper.getCurrentStackTrace();
            this.stackTrace(stackTrace);

            // Set operation from stacktrace if not provided
            if(String.isBlank(tempLog.pharos__Apex_Name__c)) {
                this.operation(TritonHelper.getOperation(stackTrace));
            }
        }
        return this;
    }

    /**
    * Prepares the builder for logging by auto-enriching with runtime context.
    * Called by Triton.log() to add stacktrace, operation, tracepoint, and limits.
    * @param transactionId -- Transaction ID to associate with this log
    * @return this builder instance
    */
    public TritonBuilder prepareForLogging(String transactionId) {
        // Set transaction ID
        this.transactionId(transactionId);

        resolveStackTraceAndOperation();

        // Add tracepoint and limits
        this.tracePoint().limitInfo();

        // Capture execution context for Apex logs only
        if (this.categoryValue == TritonTypes.Category.Apex.name()) {
            this.apexExecutionContext();
        }

        return this;
    }

    /**
    * Build and return the log record
    * @return pharos__Log__c instance
    */
    public pharos__Log__c build() {
        ensureSpanIds();
        // Defensive shallow clone: the underlying managed builder returns the
        // same sObject instance from every build(). Without a clone, reusing a
        // TritonBuilder across multiple log() calls makes every buffered record
        // alias the latest build — later logs silently overwrite earlier ones.
        // Shallow suffices (pharos__Log__c is a flat record) and is negligible
        // next to builder construction.
        pharos__Log__c log = this.builder.build().clone(false, false, false, false);

        // Default category to Apex when not explicitly set
        if(String.isNotBlank(categoryValue)) {
            log.pharos__Category__c = categoryValue;
        } else if(String.isBlank(log.pharos__Category__c)) {
            log.pharos__Category__c = TritonTypes.Category.Apex.name();
        }

        // Auto-carryover: if summary was truncated, append full text to details
        if(String.isNotBlank(fullSummary) && fullSummary.length() > 255) {
            log.pharos__Details__c = (String.isNotBlank(log.pharos__Details__c) ?
                log.pharos__Details__c + Triton.SPACE_SEP : '') + fullSummary;
        }

        // Append execution context if captured
        if(String.isNotBlank(executionContextDetails)) {
            log.pharos__Details__c = (String.isNotBlank(log.pharos__Details__c) ?
                log.pharos__Details__c + Triton.SPACE_SEP : '') + executionContextDetails;
        }

        return log;
    }
}