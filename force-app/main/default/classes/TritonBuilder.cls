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
    public static final String DO_NOT_CREATE_ISSUE = 'pharos__Do_Not_Create_Issue__c';
    public static final String REQUEST_ID = 'pharos__Request_Id_External__c';

    public TritonBuilder() {
        this.builder = pharos.LogBuilder.getInstance().clone();
        this.builder.attribute(CREATED_TIMESTAMP, Double.valueOf(System.now().getTime()));
        this.builder.attribute(DO_NOT_CREATE_ISSUE, true);
        this.builder.attribute(REQUEST_ID, System.Request.getCurrent().getRequestId());
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
		this.builder.summary(value);
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
    * Set duration for the log
    * @param duration -- Decimal value representing the duration
    * @return this builder instance
    */
    public TritonBuilder duration(Decimal duration) {
        this.builder.attribute(TritonBuilder.DURATION, duration);
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
    * Build and return the log record
    * @return pharos__Log__c instance
    */
    public pharos__Log__c build() {
		return this.builder.build();
	}
}