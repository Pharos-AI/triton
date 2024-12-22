/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

public with sharing virtual class TritonBuilder {

    private pharos.LogBuilder builder;

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

    public TritonBuilder() {
        this.builder = new pharos.LogBuilder();
    }

    /**
    * Set log category from Category enum.
    * @param c -- TritonTypes.Category enum value
    * @return this builder instance
    */
    public TritonBuilder category(TritonTypes.Category c) {
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

    public TritonBuilder type(String t) {
        this.builder.type(t);
        return this;
    }

    public TritonBuilder area(TritonTypes.Area a) {
        this.builder.area(a.name());
        return this;
    }

    public TritonBuilder area(String a) {
        this.builder.area(a);
        return this;
    }

    public TritonBuilder level(TritonTypes.Level l) {
        this.builder.attribute(LOG_LEVEL, l.name());
        return this;
    }

    public TritonBuilder operation(String operation) {
        this.builder.attribute(APEX_NAME, operation);
        return this;
    }

    public TritonBuilder summary(String value) {
		this.builder.summary(value);
        return this;
	}

    public TritonBuilder details(String value) {
		this.builder.details(value);
		return this;
	}

    public TritonBuilder stackTrace(String value) {
		this.builder.stackTrace(value);
		return this;
	}

    public TritonBuilder postProcessing(TritonHelper.PostProcessingControlsBuilder postProcessingBuilder) {
        this.builder.postProcessing(postProcessingBuilder.build());
        return this;
    }

    public TritonBuilder transactionId(String value) {
		this.builder.transactionId(value);
        return this;
	}

    public TritonBuilder createIssue() {
		this.builder.createIssue();
		return this;
	}    

    public TritonBuilder userId(Id userId) {
        this.builder.attribute(USER_ID, userId);
        return this;
    }

    public TritonBuilder relatedObject(Id objectId) {
        return relatedObjects(new Id[]{objectId});
    }

    public TritonBuilder relatedObject(String objectId) {
        try {
            return relatedObject(Id.valueOf(objectId));
        } catch(System.StringException e) {
            //invalid Id, ignore
        }
        return this;
    }

    public TritonBuilder relatedObjects(List<Id> relatedObjectIds) {
        return relatedObjects(new Set<Id>(relatedObjectIds));
    }

    public TritonBuilder relatedObjects(Set<String> relatedObjectIds) {
        if(relatedObjectIds == null || relatedObjectIds.size() == 0) return this;

        Set<Id> ids = new Set<Id>();
        for(String obj : relatedObjectIds) {
            try {
                ids.add(Id.valueOf(obj));
            } catch (System.StringException e) {
                //invalid Id, ignore
            }
        }
        return relatedObjects(ids);
    }

    public TritonBuilder relatedObjects(Set<Id> relatedObjectIds) {
        this.builder.attribute(RELATED_OBJECTS, relatedObjectIds?.size() > 0 ? 
                                        JSON.serialize(relatedObjectIds) : null);
        return this;                                        
    }

    public TritonBuilder createdTimestamp(Double timestamp) {
        this.builder.attribute(CREATED_TIMESTAMP, timestamp);
        return this;
    }

    public TritonBuilder duration(Decimal duration) {
        this.builder.attribute(TritonBuilder.DURATION, duration);
        return this;
    }

    public TritonBuilder integrationPayload(HttpRequest request, HttpResponse response) {
        this.builder.attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
        return this;
    }

    public TritonBuilder integrationPayload(RestRequest request, RestResponse response) {
        this.builder.attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
        return this;
    }

    public TritonBuilder interviewGuid(String guid) {
        this.builder.attribute(INTERVIEW_GUID, guid);
        return this;
    }

    public TritonBuilder flowApiName(String apiName) {
        this.builder.attribute(FLOW_API_NAME, apiName);
        return this;
    }


    public TritonBuilder attribute(String name, Object value) {
        this.builder.attribute(name, value);
        return this;
    }

    public pharos__Log__c build() {
		return this.builder.build();
	}
}