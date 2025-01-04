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
 * TritonBuilder is a builder class for constructing and configuring log records within the Pharos Triton system.
 * It provides a fluent API for setting various attributes and properties of log entries, such as category, type, area,
 * level, and other metadata. This class integrates with the pharos.LogBuilder to create and manage log objects.
 */

 public with sharing virtual class TritonBuilder {

    private pharos.LogBuilder builder;

    /** Key field names for setting attributes on log records */
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

    /**
     * Default constructor initializing a new LogBuilder instance.
     */
    public TritonBuilder() {
        this.builder = new pharos.LogBuilder();
    }

    /**
     * Sets the log category using a Category enum value.
     * @param c the Category enum value
     * @return this builder instance
     */
    public TritonBuilder category(TritonTypes.Category c) {
        this.builder.category(c.name());
        return this;
    }

    /**
     * Sets the log type using a Type enum value.
     * @param t the Type enum value
     * @return this builder instance
     */
    public TritonBuilder type(TritonTypes.Type t) {
        this.builder.type(t.name());
        return this;
    }

    /**
     * Sets the log type using a String value.
     * This is typically used when creating a log from an Exception.
     * @param t the String value representing the log type
     * @return this builder instance
     */
    public TritonBuilder type(String t) {
        this.builder.type(t);
        return this;
    }

    /**
     * Sets the log functional area using an Area enum value.
     * @param a the Area enum value
     * @return this builder instance
     */
    public TritonBuilder area(TritonTypes.Area a) {
        this.builder.area(a.name());
        return this;
    }

    /**
     * Sets the log functional area using a String value.
     * @param a the String value representing the functional area
     * @return this builder instance
     */
    public TritonBuilder area(String a) {
        this.builder.area(a);
        return this;
    }

    /**
     * Sets the log level using a Level enum value.
     * @param l the Level enum value
     * @return this builder instance
     */
    public TritonBuilder level(TritonTypes.Level l) {
        this.builder.attribute(LOG_LEVEL, l.name());
        return this;
    }

    /**
     * Sets the operation name for the log.
     * @param operation the operation name as a String
     * @return this builder instance
     */
    public TritonBuilder operation(String operation) {
        this.builder.attribute(APEX_NAME, operation);
        return this;
    }

    /**
     * Sets the log summary.
     * @param value the summary String value
     * @return this builder instance
     */
    public TritonBuilder summary(String value) {
        this.builder.summary(value);
        return this;
    }

    /**
     * Sets the log details.
     * @param value the details String value
     * @return this builder instance
     */
    public TritonBuilder details(String value) {
        this.builder.details(value);
        return this;
    }

    /**
     * Sets the stack trace for the log.
     * @param stack the stack trace as a String
     * @return this builder instance
     */
    public TritonBuilder stackTrace(String stack) {
        this.builder.stackTrace(stack);
        return this;
    }

    /**
     * Sets post-processing metadata for the log.
     * @param postProcessingBuilder the PostProcessingControlsBuilder instance
     * @return this builder instance
     */
    public TritonBuilder postProcessing(TritonHelper.PostProcessingControlsBuilder postProcessingBuilder) {
        this.builder.postProcessing(postProcessingBuilder.build());
        return this;
    }

    /**
     * Sets the transaction ID for the log.
     * @param transactionId the transaction ID as a String
     * @return this builder instance
     */
    public TritonBuilder transactionId(String transactionId) {
        this.builder.transactionId(transactionId);
        return this;
    }

    /**
     * Adds a related object to the log using an Id value.
     * @param objectId the related object Id
     * @return this builder instance
     */
    public TritonBuilder relatedObject(Id objectId) {
        return relatedObjects(new Id[]{objectId});
    }

    /**
     * Adds a related object to the log using a String value.
     * If the string is not a valid Id, it is ignored.
     * @param objectId the related object as a String
     * @return this builder instance
     */
    public TritonBuilder relatedObject(String objectId) {
        try {
            return relatedObject(Id.valueOf(objectId));
        } catch(System.StringException e) {
            // invalid Id, ignore
        }
        return this;
    }

    /**
     * Adds multiple related objects to the log from a list of Ids.
     * @param relatedObjectIds the List of related object Ids
     * @return this builder instance
     */
    public TritonBuilder relatedObjects(List<Id> relatedObjectIds) {
        return relatedObjects(new Set<Id>(relatedObjectIds));
    }

    /**
     * Adds multiple related objects to the log from a set of String values.
     * Invalid Ids are ignored.
     * @param relatedObjectIds the Set of related object Strings
     * @return this builder instance
     */
    public TritonBuilder relatedObjects(Set<String> relatedObjectIds) {
        if (relatedObjectIds == null || relatedObjectIds.size() == 0) return this;

        Set<Id> ids = new Set<Id>();
        for (String obj : relatedObjectIds) {
            try {
                ids.add(Id.valueOf(obj));
            } catch (System.StringException e) {
                // invalid Id, ignore
            }
        }
        return relatedObjects(ids);
    }

    /**
     * Sets the created timestamp for the log.
     * @param timestamp the timestamp as a Double
     * @return this builder instance
     */
    public TritonBuilder createdTimestamp(Double timestamp) {
        this.builder.attribute(CREATED_TIMESTAMP, timestamp);
        return this;
    }

    /**
     * Sets the duration for the log.
     * @param duration the duration as a Decimal
     * @return this builder instance
     */
    public TritonBuilder duration(Decimal duration) {
        this.builder.attribute(DURATION, duration);
        return this;
    }

    /**
     * Sets integration payload using HTTP request and response.
     * @param request the HTTP request
     * @param response the HTTP response
     * @return this builder instance
     */
    public TritonBuilder integrationPayload(HttpRequest request, HttpResponse response) {
        this.builder.attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
        return this;
    }

    /**
     * Sets integration payload using REST request and response.
     * @param request the REST request
     * @param response the REST response
     * @return this builder instance
     */
    public TritonBuilder integrationPayload(RestRequest request, RestResponse response) {
        this.builder.attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
        return this;
    }

    /**
     * Sets the interview GUID for the log.
     * @param guid the interview GUID as a String
     * @return this builder instance
     */
    public TritonBuilder interviewGuid(String guid) {
        this.builder.attribute(INTERVIEW_GUID, guid);
        return this;
    }

    /**
     * Sets the Flow API name for the log.
     * @param apiName the Flow API name as a String
     * @return this builder instance
     */
    public TritonBuilder flowApiName(String apiName) {
        this.builder.attribute(FLOW_API_NAME, apiName);
        return this;
    }

    /**
     * Sets a custom attribute for the log.
     * @param name the name of the attribute
     * @param value the value of the attribute
     * @return this builder instance
     */
    public TritonBuilder attribute(String name, Object value) {
        this.builder.attribute(name, value);
        return this;
    }

    /**
     * Builds and returns the configured log record.
     * @return the constructed pharos__Log__c record
     */
    public pharos__Log__c build() {
        return this.builder.build();
    }
}
