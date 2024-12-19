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

    public TritonBuilder() {

    }

    public TritonBuilder category(TritonTypes.Category c) {
        return category(c.name());
    }

    public TritonBuilder type(TritonTypes.Type t) {
        return type(t.name());
    }

    public TritonBuilder area(TritonTypes.Area a) {
        return area(a.name());
    }

    public TritonBuilder level(TritonTypes.Level l) {
        return attribute(LOG_LEVEL, l.name());
    }

    public TritonBuilder operation(String operation) {
        return attribute(APEX_NAME, operation);
    }

    public TritonBuilder userId(Id userId) {
        return attribute(USER_ID, userId);
    }

    public TritonBuilder relatedObject(Id objectId) {
        return relatedObjects(new Id[]{objectId});
    }

    public TritonBuilder createdTimestamp(Double timestamp) {
        return attribute(CREATED_TIMESTAMP, timestamp);
    }

    public TritonBuilder relatedObjects(Set<Id> relatedObjects) {
        return attribute(RELATED_OBJECTS, relatedObjectIds?.size() > 0 ? 
                                        JSON.serialize(relatedObjectIds) : null);
    }

    public TritonBuilder relatedObjects(Id[] relatedObjects) {
        return relatedObjects(new Set<Id>(relatedObjects));
    }

    public TritonBuilder duration(Decimal duration) {
        return attribute(DURATION, duration);
    }

    public TritonBuilder integrationPayload(HttpRequest request, HttpResponse response) {
        return attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
    }

    public TritonBuilder integrationPayload(RestRequest request, RestRequest response) {
        return attribute(STACKTRACE_PARSE_RESULT, TritonHelper.toJson(request, response));
    }


}