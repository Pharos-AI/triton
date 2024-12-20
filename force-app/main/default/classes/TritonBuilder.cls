/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

public with sharing class TritonBuilder extends pharos.LogBuilder {

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

    public static TritonBuilder getInstance() {
		return new TritonBuilder();
	}

    protected TritonBuilder() {
        super();
    }

    public TritonBuilder category(TritonTypes.Category c) {
        return (TritonBuilder)category(c.name());
    }

    public TritonBuilder type(TritonTypes.Type t) {
        return (TritonBuilder)type(t.name());
    }

    public TritonBuilder area(TritonTypes.Area a) {
        return (TritonBuilder)area(a.name());
    }

    public TritonBuilder level(TritonTypes.Level l) {
        return (TritonBuilder)attribute(LOG_LEVEL, l.name());
    }

    public TritonBuilder operation(String operation) {
        return (TritonBuilder)attribute(APEX_NAME, operation);
    }

    public TritonBuilder userId(Id userId) {
        return (TritonBuilder)attribute(USER_ID, userId);
    }

    public TritonBuilder relatedObject(Id objectId) {
        return (TritonBuilder)relatedObjects(new Id[]{objectId});
    }

    public TritonBuilder createdTimestamp(Double timestamp) {
        return (TritonBuilder)attribute(CREATED_TIMESTAMP, timestamp);
    }

    public TritonBuilder relatedObjects(Set<Id> relatedObjectIds) {
        return (TritonBuilder)attribute(RELATED_OBJECTS, relatedObjectIds?.size() > 0 ? 
                                        JSON.serialize(relatedObjectIds) : null);
    }

    public TritonBuilder relatedObjects(Id[] relatedObjects) {
        return (TritonBuilder)relatedObjects(new Set<Id>(relatedObjects));
    }

    public TritonBuilder duration(Decimal duration) {
        return (TritonBuilder)attribute(TritonBuilder.DURATION, duration);
    }

    public TritonBuilder integrationPayload(HttpRequest request, HttpResponse response) {
        return (TritonBuilder)attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
    }

    public TritonBuilder integrationPayload(RestRequest request, RestResponse response) {
        return (TritonBuilder)attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
    }


}