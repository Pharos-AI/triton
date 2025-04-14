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
 * TritonHelper provides utility methods and builder classes for the Triton logging framework.
 * This class includes functionality for:
 * - Log level management and comparison
 * - UUID generation for transaction tracking
 * - HTTP request/response JSON serialization for integration logging
 * - Pre and post-processing controls for Pharos logging configuration
 * - Message formatting utilities
 * 
 * The class serves as a central utility hub for the Triton logging system, offering
 * helper methods and builder patterns to configure and enhance logging capabilities.
 */
public with sharing class TritonHelper {

    private static final String TRANSACTION_CACHE_KEY = 'tritonTransactionId';
    private static final Integer DEFAULT_TRANSACTION_CACHE_DURATION = 300;
    
    /**
     * Generates a user-specific cache key
     * @return Cache key specific to current user
     */
    private static String getUserCacheKey() {
        return UserInfo.getUserId() + TRANSACTION_CACHE_KEY;
    }
    
    /**
     * Saves transaction ID to platform cache with user-specific key
     * @param transactionId Transaction ID to cache
     */
    public static void cacheTransactionId(String transactionId) {
        try {
            Cache.Session.put(getUserCacheKey(), transactionId, DEFAULT_TRANSACTION_CACHE_DURATION);
        } catch (Exception e) {
            // Silently handle cache failures - logging system should continue without cache
        }
    }

    /**
     * Retrieves transaction ID from platform cache using user-specific key
     * @return Cached transaction ID or null if not found
     */
    public static String getCachedTransactionId() {
        try {
            return (String)Cache.Session.get(getUserCacheKey());
        } catch (Exception e) {
            // Silently handle cache failures - logging system should continue without cache
            return null;
        }
    }

    /**
     * Clears transaction ID from platform cache
     */
    public static void clearCachedTransactionId() {
        Cache.Session.remove(getUserCacheKey());
    }

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
     * Returns the current stack trace as a string, excluding any Triton-related entries.
     * This method works by throwing and catching an exception to obtain the stack trace,
     * then filtering out any lines containing 'Triton' to provide a clean trace of the
     * actual application code path.
     * 
     * @return String The filtered stack trace with lines joined by newline characters
     */
    public static String getCurrentStackTrace() {
        try {
            throw new DmlException();
        } catch (Exception e) {
            return Test.isRunningTest() ? e.getStackTraceString() : filterStackTrace(e.getStackTraceString());
        }
    }

    /**
     * Test-visible method that processes a stack trace string and filters out Triton-related entries.
     * 
     * @param stackTraceString The raw stack trace string to process
     * @return String The filtered stack trace with lines joined by newline characters
     */
    @TestVisible
    private static String filterStackTrace(String stackTraceString) {
        List<String> stackLines = new List<String>();
        for(String line : stackTraceString.split('\n')) {
            String trimmedLine = line.trim();
            if (!trimmedLine.contains('Triton')) {
                stackLines.add(trimmedLine);
            }
        }
        return String.join(stackLines, '\n');
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

    /**
     * Formats a message by replacing {0} placeholder with the provided parameter
     * @param template The message template containing {0} placeholder
     * @param param The parameter to replace the placeholder with
     * @return Formatted message
     */
    public static String formatMessage(String template, String param) {
        return String.format(template, new List<String>{param});
    }

    /**
     * Formats a message by replacing {0}, {1}, etc. placeholders with the provided parameters
     * @param template The message template containing numbered placeholders
     * @param params The list of parameters to replace the placeholders with
     * @return Formatted message
     */
    public static String formatMessage(String template, List<String> params) {
        return String.format(template, params);
    }

    /**
     * Extracts the operation (Class.Method) from a stack trace string
     * Takes the topmost non-Triton entry from the stack trace
     * 
     * @param stackTrace The stack trace string to parse
     * @return String in format "ClassName.MethodName"
     */
    public static String getOperation(String stackTrace) {
        if (String.isBlank(stackTrace)) return '';
        
        // Split the stack trace into lines
        List<String> stackLines = stackTrace.split('\n');
        
        for (String line : stackLines) {
            // Skip empty lines
            if (String.isBlank(line)) continue;
            
            // Line format is typically: Class.Method: line n, column m
            String trimmedLine = line.trim();
            
            // Skip Triton-related entries
            if (trimmedLine.contains('Triton')) continue;
            
            // Extract the Class.Method part (everything before the first colon)
            Integer colonIndex = trimmedLine.indexOf(':');
            if (colonIndex == -1) continue;
            
            String operation = trimmedLine.substring(0, colonIndex).trim();
            
            // Validate that we have both class and method (contains a dot)
            if (operation.contains('.')) {
                return operation;
            }
        }
        
        return '';
    }

    /**
     * Formats runtime information into a readable string
     * @param {TritonLwc.RuntimeInfo} runtime The runtime info object to format
     * @return Formatted string with all runtime details
     */
    public static String formatLwcRuntimeInfo(TritonLwc.RuntimeInfo runtime) {
        if (runtime == null) return '';
        
        final String HEADER = Triton.SPACE_SEP + 'Runtime Info:';
        final String MB_TEMPLATE = '{0}MB';
        final String MS_TEMPLATE = '{0}ms';
        final String MBPS_TEMPLATE = '{0}Mbps';
        final String DIMENSION_TEMPLATE = '{0}x{1}';
        
        String details = HEADER;
        
        // Environment
        details += Triton.SPACE_SEP + '=== Environment ===';
        details += formatMessage('\nUser Agent: {0}', runtime.userAgent);
        details += formatMessage('\nPlatform: {0}', runtime.platform);
        details += formatMessage('\nLanguage: {0}', runtime.language);
        details += formatMessage('\nMobile: {0}', String.valueOf(runtime.mobile));
        details += runtime.viewportWidth != null ? formatMessage('\nViewport: ' + DIMENSION_TEMPLATE, 
            new String[]{String.valueOf(runtime.viewportWidth), String.valueOf(runtime.viewportHeight)}) : '';
        details += formatMessage('\nTheme: {0}', runtime.theme);
        
        // Performance
        details += Triton.SPACE_SEP + '=== Performance ===';
        details += runtime.pageLoadTime != null ? formatMessage('\nPage Load Time: ' + MS_TEMPLATE, 
            String.valueOf(Decimal.valueOf(runtime.pageLoadTime).setScale(2))) : '';
        details += runtime.domInteractive != null ? formatMessage('\nDOM Interactive: ' + MS_TEMPLATE, 
            String.valueOf(Decimal.valueOf(runtime.domInteractive).setScale(2))) : '';
        details += runtime.domContentLoaded != null ? formatMessage('\nDOM Content Loaded: ' + MS_TEMPLATE, 
            String.valueOf(Decimal.valueOf(runtime.domContentLoaded).setScale(2))) : '';
        details += runtime.firstByte != null ? formatMessage('\nTime to First Byte: ' + MS_TEMPLATE, 
            String.valueOf(Decimal.valueOf(runtime.firstByte).setScale(2))) : '';
        details += runtime.serverTime != null ? formatMessage('\nServer Time: ' + MS_TEMPLATE, 
            String.valueOf(Decimal.valueOf(runtime.serverTime).setScale(2))) : '';
        details += runtime.firstPaint != null ? formatMessage('\nFirst Paint: ' + MS_TEMPLATE, 
            String.valueOf(Decimal.valueOf(runtime.firstPaint).setScale(2))) : '';
        details += runtime.firstContentfulPaint != null ? formatMessage('\nFirst Contentful Paint: ' + MS_TEMPLATE, 
            String.valueOf(Decimal.valueOf(runtime.firstContentfulPaint).setScale(2))) : '';
        
        // Memory
        details += Triton.SPACE_SEP + '=== Memory ===';
        if (runtime.memoryUsage != null) {
            Decimal memoryUsageMB = Decimal.valueOf(runtime.memoryUsage / 1048576).setScale(2);
            details += formatMessage('\nMemory Usage: ' + MB_TEMPLATE, String.valueOf(memoryUsageMB));
        }
        if (runtime.memoryLimit != null) {
            Decimal memoryLimitMB = Decimal.valueOf(runtime.memoryLimit / 1048576).setScale(2);
            details += formatMessage('\nMemory Limit: ' + MB_TEMPLATE, String.valueOf(memoryLimitMB));
        }
        
        // Network
        details += Triton.SPACE_SEP + '=== Network ===';
        details += formatMessage('\nConnection Type: {0}', runtime.connectionType);
        details += runtime.connectionSpeed != null ? formatMessage('\nConnection Speed: ' + MBPS_TEMPLATE, 
            String.valueOf(runtime.connectionSpeed)) : '';
        details += runtime.connectionRtt != null ? formatMessage('\nConnection RTT: ' + MS_TEMPLATE, 
            String.valueOf(Decimal.valueOf(runtime.connectionRtt).setScale(2))) : '';
        details += formatMessage('\nSave Data: {0}', String.valueOf(runtime.saveData));
        details += formatMessage('\nPath: {0}', runtime.pathname);
        details += formatMessage('\nHost: {0}', runtime.hostname);
        details += formatMessage('\nOnline: {0}', String.valueOf(runtime.isOnline));
        
        // Device
        details += Triton.SPACE_SEP + '=== Device ===';
        details += formatMessage('\nForm Factor: {0}', runtime.formFactor);
        details += runtime.screenWidth != null ? formatMessage('\nScreen: ' + DIMENSION_TEMPLATE, 
            new String[]{String.valueOf(runtime.screenWidth), String.valueOf(runtime.screenHeight)}) : '';
        details += formatMessage('\nOrientation: {0}', runtime.orientation);
        
        return details;
    }

    /**
    * Format a DML error message including field-level information
    * @param err -- Database.Error instance
    * @param recordId -- ID of the record that caused the error
    * @return -- Formatted error message string
    */
    public static String formatDMLError(Database.Error err, Id recordId) {
        String errorMsg = 'Error: ' + err.getMessage();
        
        // Add status code
        errorMsg += ' (Status Code: ' + err.getStatusCode() + ')';
        
        // Add record ID if available
        if (recordId != null) {
            errorMsg += ' on record: ' + recordId;
        }
        
        // Add field information if available
        List<String> fields = err.getFields();
        if (fields != null && !fields.isEmpty()) {
            errorMsg += ' | Fields: ' + String.join(fields, ', ');
        }
        
        return errorMsg;
    }
}