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
    @description helper class for the Triton Logger project
 */
public with sharing class TritonHelper {

    public static final Map<String, TritonTypes.Level> NEBULA_LEVEL_MAP = new Map<String, TritonTypes.Level> {
        'ERROR' => TritonTypes.Level.ERROR,
        'WARNING' => TritonTypes.Level.WARNING,
        'INFO' => TritonTypes.Level.INFO,
        'DEBUG' => TritonTypes.Level.DEBUG,
        'FINE' => TritonTypes.Level.FINE,
        'FINER' => TritonTypes.Level.FINER,
        'FINEST' => TritonTypes.Level.FINEST
    };

    /**
    * Creates a key for log level based on:
    * @param category -- log category field
    * @param tye -- log type field
    * @param area -- log functional area field
    * @return -- a string with values in the following format: Category:{0};Type:{1};Area:{2}
    */
    public static String buildLogLevelKey(String category, String type, String area) {
        return String.format('Category:{0};Type:{1};Area:{2}', new String[]{category, type, area});
    }

    /**
    * Compares 2 log levels.
    * @param value -- this is the value compared against
    * @param toCompare -- comparison performed against this value
    * @return -- if value is higher than toCompare returns false, otherwise true
    */
    public static Boolean compareLevel(TritonTypes.Level value, TritonTypes.Level toCompare) {
        return value.ordinal() >= toCompare.ordinal();
    }

    /**
     * Generates a UUID.
     * Used to create a transaction Id
     */
    public static String generateUUID4() {
        String h = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        return 
            h.substring(0,8) +
            '-' +
            h.substring(8,12) +
            '-' +
            h.substring(12,16) +
            '-' +
            h.substring(16,20) +
            '-' +
            h.substring(20);
    }

    /**
    * Json serialization for http request and response objects.
    * Used by integration logs.
    */
    public static String toJson(RestRequest request, RestResponse response) {
        return JSON.serialize(new TritonHelper.IntegrationWrapper(
            new pharos.HttpRequestWrapper(request).formatRequest(),
            new pharos.HttpResponseWrapper(response).formatResponse()
        ));
    }

    public static String toJson(HttpRequest request, HttpResponse response) {
        return JSON.serialize(new TritonHelper.IntegrationWrapper(
            new pharos.HttpRequestWrapper(request).formatRequest(),
            new pharos.HttpResponseWrapper(response).formatResponse()
        ));
    }

    /**
    * Wrapper class for integration logs
    * Used to create the Json structure that combines http objects
    */
    public class IntegrationWrapper {
        public Map<String, Object> request;
        public Map<String, Object> response;
        public IntegrationWrapper(Map<String, Object> request, Map<String, Object> response) {
            this.request = request;
            this.response = response;
        }
    }

    /**
     * Builder class for constructing Pharos pre processing settings
     */
    public class PreProcessingControlsBuilder {
    }


    /**
     * Builder class for constructing Pharos post processing settings
     */
    public class PostProcessingControlsBuilder {

        private final Map<String, Boolean> controls;

        private final String AUDIT_TRAIL_KEY = 'auditTrail';
        private final String DEPLOY_RESULT_KEY = 'deployResult';
        private final String INSTALLED_PACKAGES_KEY = 'installedPackages';
        private final String AREA_KEY = 'objectInfo';
        private final String PENDING_JOBS_KEY = 'pendingJobs';
        private final String RELATED_OBJECTS_KEY = 'relatedObjects';
        private final String STACK_TRACE_KEY = 'stackTrace';
        private final String TOTAL_ACTIVE_SESSION_KEY = 'totalActiveSession';
        private final String USER_INFO_KEY = 'userInfo';
        

        public PostProcessingControlsBuilder() {
            controls = new Map<String, Boolean>{
                    AUDIT_TRAIL_KEY => false,
                    DEPLOY_RESULT_KEY => false,
                    INSTALLED_PACKAGES_KEY => false,
                    AREA_KEY => false,
                    PENDING_JOBS_KEY => false,
                    RELATED_OBJECTS_KEY => false,
                    STACK_TRACE_KEY => false,
                    TOTAL_ACTIVE_SESSION_KEY => false,
                    USER_INFO_KEY => false
            };
        }

        /**
         * Controls whether Pharos fetches recent audit trail
         */
        public PostProcessingControlsBuilder auditTrail(Boolean value) {
            controls.put(AUDIT_TRAIL_KEY, value);
            return this;
        }

        /**
         * Returns a Json version of the settings
         */
        public String build() {
            return JSON.serialize(controls);
        }

        /**
         * Controls whether Pharos fetches recent deployments
         */
        public PostProcessingControlsBuilder deployResult(Boolean value) {
            controls.put(DEPLOY_RESULT_KEY, value);
            return this;
        }

        /**
         * Controls whether Pharos fetches the number of currently installed packages
         */
        public PostProcessingControlsBuilder installedPackages(Boolean value) {
            controls.put(INSTALLED_PACKAGES_KEY, value);
            return this;
        }
        
        /**
         * Controls whether Pharos automatically sets functional area
         */
        public PostProcessingControlsBuilder area(Boolean value) {
            controls.put(AREA_KEY, value);
            return this;
        }

        /**
         * Controls whether Pharos fetches jobs currently in the flox queue
         */
        public PostProcessingControlsBuilder pendingJobs(Boolean value) {
            controls.put(PENDING_JOBS_KEY, value);
            return this;
        }

        /**
         * Controls whether Pharos fetches related objects names
         */
        public PostProcessingControlsBuilder relatedObjects(Boolean value) {
            controls.put(RELATED_OBJECTS_KEY, value);
            return this;
        }

        /**
         * Sets all flags to the value provided
         */
        public PostProcessingControlsBuilder setAll(Boolean value) {
            for (String key : controls.keySet()) {
                controls.put(key, value);
            }
            return this;
        }

        /**
         * Controls whether stack trace is enhanced by Pharos
         * Only applicable to Apex and Integration logs
         */
        public PostProcessingControlsBuilder stackTrace(Boolean value) {
            controls.put(STACK_TRACE_KEY, value);
            return this;
        }
        
        /**
         * Controls whether Pharos fetches User name
         */
        public PostProcessingControlsBuilder userInfo(Boolean value) {
            controls.put(USER_INFO_KEY, value);
            return this;
        }

        /**
         * Controls whether Pharos fetches the number of currently logged in users
         */
        public PostProcessingControlsBuilder totalActiveSession(Boolean value) {
            controls.put(TOTAL_ACTIVE_SESSION_KEY, value);
            return this;
        }
    }

    /*
    {
        "attributes": {
            "type": "LogEntryEvent__e"
        },
        "LoggingLevel__c": "ERROR",
        "LoggingLevelOrdinal__c": 8,
        "OriginType__c": "Apex",
        "TriggerIsExecuting__c": false,
        "TriggerOperationType__c": null,
        "TriggerSObjectType__c": null,
        "LimitsAggregateQueriesMax__c": 300,
        "LimitsAsyncCallsMax__c": 200,
        "LimitsCalloutsMax__c": 100,
        "LimitsCpuTimeMax__c": 10000,
        "LimitsDmlRowsMax__c": 10000,
        "LimitsDmlStatementsMax__c": 150,
        "LimitsEmailInvocationsMax__c": 10,
        "LimitsFutureCallsMax__c": 50,
        "LimitsHeapSizeMax__c": 6000000,
        "LimitsMobilePushApexCallsMax__c": 10,
        "LimitsPublishImmediateDmlStatementsMax__c": 150,
        "LimitsQueueableJobsMax__c": 50,
        "LimitsSoqlQueriesMax__c": 100,
        "LimitsSoqlQueryLocatorRowsMax__c": 10000,
        "LimitsSoqlQueryRowsMax__c": 50000,
        "LimitsSoslSearchesMax__c": 20,
        "LimitsAggregateQueriesUsed__c": 0,
        "LimitsAsyncCallsUsed__c": 0,
        "LimitsCalloutsUsed__c": 0,
        "LimitsCpuTimeUsed__c": 15,
        "LimitsDmlRowsUsed__c": 0,
        "LimitsDmlStatementsUsed__c": 0,
        "LimitsEmailInvocationsUsed__c": 0,
        "LimitsFutureCallsUsed__c": 0,
        "LimitsMobilePushApexCallsUsed__c": 0,
        "LimitsQueueableJobsUsed__c": 0,
        "LimitsPublishImmediateDmlStatementsUsed__c": 0,
        "LimitsSoqlQueriesUsed__c": 0,
        "LimitsSoqlQueryLocatorRowsUsed__c": 0,
        "LimitsSoqlQueryRowsUsed__c": 0,
        "LimitsSoslSearchesUsed__c": 0,
        "LimitsHeapSizeUsed__c": 11096,
        "EpochTimestamp__c": 1729808545107,
        "Timestamp__c": "2024-10-24T22:22:25.107+0000",
        "TimestampString__c": "1729808545107",
        "OriginLocation__c": "AnonymousBlock",
        "OriginSourceActionName__c": null,
        "OriginSourceApiName__c": null,
        "OriginSourceMetadataType__c": "AnonymousBlock",
        "StackTrace__c": "AnonymousBlock: line 1, column 1",
        "ApiVersion__c": "v62.0",
        "EntryScenario__c": null,
        "LoggerVersionNumber__c": "v4.14.14",
        "OrganizationApiVersion__c": "v62.0",
        "OrganizationDomainUrl__c": "https://onepagecom-dev-ed.develop.my.salesforce.com",
        "RequestId__c": "SLB:82a3dd3d1b131f12001ebe3d2ec20012",
        "SystemMode__c": "ANONYMOUS",
        "TransactionEntryNumber__c": 1,
        "TransactionId__c": "04584565-91f3-489c-9106-629b45ce1bfb",
        "UserLoggingLevel__c": "FINEST",
        "UserLoggingLevelOrdinal__c": 2,
        "Message__c": "error message",
        "MessageMasked__c": false,
        "MessageTruncated__c": false,
        "Locale__c": "en_US",
        "LoggedById__c": "005ak000002TGoDAAW",
        "LoggedByUsername__c": "mike@onepage.com",
        "ProfileId__c": "00eak000002XMLbAAO",
        "ThemeDisplayed__c": "Theme3",
        "TimeZoneId__c": "America/Los_Angeles",
        "TimeZoneName__c": "(GMT-07:00) Pacific Daylight Time (America/Los_Angeles)",
        "UserRoleId__c": null,
        "UserType__c": "Standard",
        "LoginApplication__c": "Browser",
        "LoginBrowser__c": "Chrome 129",
        "LoginHistoryId__c": "0Yaak00000BbJ3SCAV",
        "LoginPlatform__c": "Mac OSX",
        "LoginType__c": "Application",
        "LogoutUrl__c": null,
        "ParentSessionId__c": "0Akak00000EegmPCAR",
        "SessionId__c": "0Akak00000EjZI0CAN",
        "SessionSecurityLevel__c": "STANDARD",
        "SessionType__c": "UI",
        "SourceIp__c": "107.141.175.191",
        "LoggedByFederationIdentifier__c": null,
        "ProfileName__c": "System Administrator",
        "UserLicenseDefinitionKey__c": "SFDC",
        "UserLicenseId__c": "100ak000005YRSjAAO",
        "UserLicenseName__c": "Salesforce",
        "UserRoleName__c": null,
        "OrganizationEnvironmentType__c": "Production",
        "OrganizationId__c": "00Dak000003lUSLEA2",
        "OrganizationInstanceName__c": "USA840",
        "OrganizationName__c": "N/A",
        "OrganizationNamespacePrefix__c": null,
        "OrganizationType__c": "Developer Edition"
    }

    code sample:
    public static void saveLog(String saveMethodName) {
  
   
        for (LogEntryEventBuilder logEntryEventBuilder : LOG_ENTRIES_BUFFER) {
            if (logEntryEventBuilder.shouldSave()) {
                Triton.addNebulaLog(JSON.serialize(logEntryEventBuilder.getLogEntryEvent()));
            }
        } 
        
        if (Triton_Nebula_Integration__mdt.getInstance('Triton').Deactivate_Nebula__c) {
            return;
        }
    */
}
