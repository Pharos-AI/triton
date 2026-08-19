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

    // Packaged defaults for the operational knobs, used when the org-level value
    // (TritonSettings__c) is blank or unreadable. Referenced by TritonConfig.
    private static final Integer DEFAULT_CACHE_TTL_SECONDS = 300;
    private static final Integer DEFAULT_FLOW_FLUSH_BATCH_DELAY_MINUTES = 1;

    // ─── Configuration ───────────────────────────────────────────────

    /**
     * Single entry point for all metadata-backed Triton configuration: the
     * org-level feature switches (TritonSettings__c) and the log-level rules
     * (Log_Level__mdt). Lazily initialized once per transaction. Tests mutate
     * the instance's @TestVisible data rather than reading real org config.
     */
    public static TritonConfig Config {
        get {
            if (Config == null) {
                Config = new TritonConfig();
            }
            return Config;
        }
        private set;
    }
    
    /**
     * Generates a user-specific cache key
     * @return Cache key specific to current user
     */
    private static String getUserCacheKey() {
        return UserInfo.getUserId() + TRANSACTION_CACHE_KEY;
    }
    
    /**
     * Saves transaction ID to Org cache with user-specific key
     * @param transactionId Transaction ID to cache
     */
    public static void cacheTransactionId(String transactionId) {
        try {
            TritonCacheManager.put(getUserCacheKey(), transactionId, Config.getCacheTtlSeconds());
        } catch (Exception e) {
            // Silently handle cache failures - logging system should continue without cache
        }
    }

    /**
     * Retrieves transaction ID from Org cache using user-specific key
     * @return Cached transaction ID or null if not found
     */
    public static String getCachedTransactionId() {
        try {
            return (String) TritonCacheManager.get(getUserCacheKey());
        } catch (Exception e) {
            // Silently handle cache failures - logging system should continue without cache
            return null;
        }
    }

    /**
     * Clears transaction ID from Org cache
     */
    public static void clearCachedTransactionId() {
        TritonCacheManager.remove(getUserCacheKey());
    }

    // ─── Flow Log Org Cache helpers ───────────────────────────────────────

    private static final String FLOW_LOG_CACHE_PREFIX = 'flFlush';
    private static final String NON_ALPHANUMERIC_PATTERN = '[^a-zA-Z0-9]';

    /**
     * Builds a cache-safe key from a transaction ID by stripping non-alphanumeric characters.
     * Org Cache keys must be alphanumeric only.
     */
    private static String buildFlowCacheKey(String transactionId) {
        return FLOW_LOG_CACHE_PREFIX + transactionId.replaceAll(NON_ALPHANUMERIC_PATTERN, '');
    }

    /**
     * Saves flow logs to Org Cache keyed by transaction ID.
     * Stores SObjects directly — no JSON serialization.
     * Overwrites previous entry for the same transaction (last write wins).
     * @param transactionId The transaction ID used as cache key suffix
     * @param logs The list of log records to cache
     * @return true if cache write succeeded, false otherwise
     */
    public static Boolean cacheFlowLogs(String transactionId, List<pharos__Log__c> logs) {
        try {
            TritonCacheManager.put(buildFlowCacheKey(transactionId), logs, Config.getCacheTtlSeconds());
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Retrieves flow logs from Org Cache by key.
     * Casts directly from cached Object — no JSON deserialization.
     * @param key The full cache key (including prefix)
     * @return List of cached log records, or empty list on failure
     */
    public static List<pharos__Log__c> getCachedFlowLogs(String key) {
        try {
            Object data = TritonCacheManager.get(key);
            if (data != null) {
                return (List<pharos__Log__c>) data;
            }
        } catch (Exception e) {
            // Silently handle cache failures
        }
        return new List<pharos__Log__c>();
    }

    /**
     * Returns all Org Cache keys matching the flow log prefix.
     * Used by the flush batch to discover pending logs across transactions.
     * @return Set of cache keys for pending flow logs
     */
    public static Set<String> getFlowLogCacheKeys() {
        try {
            Set<String> allKeys = TritonCacheManager.getKeys();
            Set<String> flowKeys = new Set<String>();
            for (String key : allKeys) {
                if (key.startsWith(FLOW_LOG_CACHE_PREFIX)) {
                    flowKeys.add(key);
                }
            }
            return flowKeys;
        } catch (Exception e) {
            // Silently handle cache failures
        }
        return new Set<String>();
    }

    /**
     * Removes a flow log cache entry after processing.
     * @param key The full cache key to remove
     */
    public static void removeFlowLogCacheKey(String key) {
        try {
            TritonCacheManager.remove(key);
        } catch (Exception e) {
            // Silently handle cache failures
        }
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
     * The Triton framework's own runtime classes. Stack frames belonging to these
     * are dropped when filtering a trace or deriving an operation, so that a log
     * is always attributed to the calling application code rather than to Triton.
     *
     * Matched by exact class name rather than by looking for 'Triton' anywhere in
     * the frame, which would also swallow application classes whose names merely
     * contain the word (a customer's TritonWrapper, or this framework's own test
     * classes). Add an entry here when a new runtime class is introduced.
     */
    private static final Set<String> TRITON_FRAMEWORK_CLASSES = new Set<String>{
        'Triton',
        'TritonBuilder',
        'TritonCacheManager',
        'TritonFlow',
        'TritonFlowFlushBatch',
        'TritonHelper',
        'TritonLwc',
        // Defensive, as the comment above asks: TritonSpanContext never logs, and a
        // mark's trace is captured before any call into it, so no test can reach a
        // trace where this entry is what removes a frame.
        'TritonSpanContext',
        'TritonTypes'
    };

    private static final String CLASS_FRAME_PREFIX = 'Class.';

    /**
     * Returns the current stack trace as a string, excluding the Triton framework's
     * own entries. This method works by throwing and catching an exception to obtain
     * the stack trace, then filtering out framework frames to provide a clean trace
     * of the actual application code path.
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
     * Test-visible method that processes a stack trace string and filters out the
     * Triton framework's own entries.
     *
     * @param stackTraceString The raw stack trace string to process
     * @return String The filtered stack trace with lines joined by newline characters
     */
    @TestVisible
    private static String filterStackTrace(String stackTraceString) {
        List<String> stackLines = new List<String>();
        for(String line : stackTraceString.split('\n')) {
            String trimmedLine = line.trim();
            if (!isTritonFrame(trimmedLine)) {
                stackLines.add(trimmedLine);
            }
        }
        return String.join(stackLines, '\n');
    }

    /**
     * True when a stack trace frame belongs to a Triton framework class.
     *
     * Frames look like 'Class.[namespace.]MyClass[.InnerClass].method: line n, column m'.
     * Every segment except the trailing method name is checked against
     * TRITON_FRAMEWORK_CLASSES, so both namespaced and inner-class frames are
     * recognised while a caller's method that merely happens to be named after a
     * framework class is not. Triggers and anonymous blocks are always caller code.
     *
     * @param stackLine A single, trimmed stack trace line
     * @return true when the frame is Triton's own
     */
    @TestVisible
    private static Boolean isTritonFrame(String stackLine) {
        if (String.isBlank(stackLine) || !stackLine.startsWith(CLASS_FRAME_PREFIX)) return false;

        // Drop the 'Class.' prefix and the trailing ': line n, column m'.
        String frame = stackLine.substringAfter(CLASS_FRAME_PREFIX);
        Integer colonIndex = frame.indexOf(':');
        if (colonIndex != -1) frame = frame.substring(0, colonIndex);

        List<String> segments = frame.trim().split('\\.');
        // Stop before the last segment: that is the method name.
        for (Integer i = 0; i < segments.size() - 1; i++) {
            if (TRITON_FRAMEWORK_CLASSES.contains(segments.get(i))) return true;
        }
        return false;
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
     * Extracts the operation from a stack trace string.
     * Takes the topmost entry that does not belong to the Triton framework itself,
     * so the operation names the calling application code.
     *
     * @param stackTrace The stack trace string to parse
     * @return The frame text before the line/column suffix, retaining the stack's
     *         own 'Class.' prefix (for example 'Class.AccountService.update'), or
     *         an empty string when no suitable frame is found
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

            // Skip the Triton framework's own entries
            if (isTritonFrame(trimmedLine)) continue;

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

    /**
     * Detects and formats the current Salesforce execution context.
     * For triggers: captures operation type, sObject name, and record count.
     * For async contexts: labels the execution type.
     * Returns empty string for standard synchronous execution.
     */
    public static String formatExecutionContext() {
        List<String> parts = new List<String>();

        if(Trigger.isExecuting) {
            parts.add('Execution Context: Trigger');
            parts.add('Operation: ' + Trigger.operationType);
            String sObjectName = Trigger.new != null && !Trigger.new.isEmpty()
                ? Trigger.new[0].getSObjectType().getDescribe().getName()
                : Trigger.old != null && !Trigger.old.isEmpty()
                    ? Trigger.old[0].getSObjectType().getDescribe().getName()
                    : 'Unknown';
            parts.add('Object: ' + sObjectName);
            Integer batchSize = Trigger.new != null ? Trigger.new.size() : Trigger.old.size();
            parts.add('Batch Size: ' + batchSize);
        } else if(System.isBatch()) {
            parts.add('Execution Context: Batch');
        } else if(System.isQueueable()) {
            parts.add('Execution Context: Queueable');
        } else if(System.isScheduled()) {
            parts.add('Execution Context: Scheduled');
        } else if(System.isFuture()) {
            parts.add('Execution Context: Future');
        }

        return parts.isEmpty() ? '' : String.join(parts, '\n');
    }

    // ─── Configuration types ─────────────────────────────────────────

    /**
     * Holds all metadata-backed Triton configuration and the policy that
     * consumes it: the org-level feature switches (TritonSettings__c) and
     * log-level filtering (Log_Level__mdt). Reached via TritonHelper.Config.
     */
    public class TritonConfig {

        /**
         * Cached org-level Triton settings, read once per transaction.
         * @TestVisible so tests inject flag values without DML.
         */
        @TestVisible
        TritonSettings__c settings {
            get {
                if (settings == null) {
                    settings = TritonSettings__c.getOrgDefaults();
                }
                return settings;
            }
            set;
        }

        /**
         * Raw Log_Level__mdt records. @TestVisible so tests supply their own.
         *
         * Tests start from an empty set rather than the org's records: log level
         * metadata is deployed configuration, so inheriting it would make every
         * test that logs pass or fail depending on which levels happen to exist
         * in the target org. Tests that exercise filtering assign their own rules.
         */
        @TestVisible
        Log_Level__mdt[] logLevelsMdt = Test.isRunningTest()
            ? new Log_Level__mdt[]{}
            : Log_Level__mdt.getAll().values();

        /**
         * Cached, parsed Log_Level__mdt rules used to decide whether a log is
         * verbose enough to be persisted. Lazily built from logLevelsMdt and
         * reset by tests by assigning null.
         */
        @TestVisible
        List<LogLevelRule> logLevels {
            get {
                if (logLevels == null) {
                    logLevels = new List<LogLevelRule>();
                    componentScopedLevelsExist = false;
                    for (Log_Level__mdt ll : logLevelsMdt) {
                        LogLevelRule rule;
                        try {
                            rule = new LogLevelRule(ll);
                        } catch (Exception e) {
                            // Fail-safe: a malformed row (e.g. blank Level__c) becomes
                            // inert instead of throwing into the host transaction.
                            continue;
                        }
                        logLevels.add(rule);
                        componentScopedLevelsExist = componentScopedLevelsExist || rule.component != null;
                    }
                }
                return logLevels;
            }
            set;
        }

        /**
         * Whether any parsed rule is component-scoped. Computed once alongside
         * logLevels rather than rescanned per log.
         */
        private Boolean componentScopedLevelsExist = null;

        /**
         * True when at least one configured level is scoped to a component.
         * Resolving a log's component requires deriving the operation from the
         * stack trace, which is comparatively expensive; this lets callers pay
         * that cost only when a component-scoped rule could actually match.
         */
        public Boolean hasComponentScopedLevels() {
            // Touch the getter so the flag is populated on first use.
            if (logLevels.isEmpty()) return false;
            return componentScopedLevelsExist == true;
        }

        /**
         * True when all Triton logging is disabled via the org-level switch.
         * Fail-safe: any error resolves to false (logging enabled) so a config
         * read hiccup never silently drops logs.
         */
        public Boolean isLoggingDisabled() {
            try {
                return settings != null && settings.Disable_Logging__c == true;
            } catch (Exception e) {
                return false;
            }
        }

        /**
         * True when the deferred Flow flush batch is disabled. When disabled,
         * Flow logs are flushed immediately instead of via the batch.
         * Fail-safe: any error resolves to false (batch enabled).
         */
        public Boolean isFlowFlushBatchDisabled() {
            try {
                return settings != null && settings.Disable_Flow_Flush_Batch__c == true;
            } catch (Exception e) {
                return false;
            }
        }

        /**
         * Cache lifetime, in seconds, for Triton's Org Cache entries (the flow-log
         * buffer and the transaction-id key). Read live from Cache_TTL_Minutes__c
         * (org defaults) and converted to seconds. A blank/negative value
         * falls back to the packaged default. Fail-safe: any error resolves
         * to the default.
         */
        public Integer getCacheTtlSeconds() {
            try {
                Decimal minutes = TritonSettings__c.getOrgDefaults().Cache_TTL_Minutes__c;
                return minutes != null && minutes >= 0
                    ? (Integer) (minutes * 60)
                    : DEFAULT_CACHE_TTL_SECONDS;
            } catch (Exception e) {
                return DEFAULT_CACHE_TTL_SECONDS;
            }
        }

        /**
         * Delay, in minutes, before the deferred Flow flush batch runs. Read live
         * from Flow_Flush_Batch_Delay_Minutes__c (org defaults). A blank/negative
         * value falls back to the packaged default. Fail-safe: any error resolves
         * to the default.
         */
        public Integer getFlowFlushBatchDelayMinutes() {
            try {
                Decimal minutes = TritonSettings__c.getOrgDefaults().Flow_Flush_Batch_Delay_Minutes__c;
                return minutes != null && minutes >= 0
                    ? minutes.intValue()
                    : DEFAULT_FLOW_FLUSH_BATCH_DELAY_MINUTES;
            } catch (Exception e) {
                return DEFAULT_FLOW_FLUSH_BATCH_DELAY_MINUTES;
            }
        }

        /**
        * Checks if a log should be persisted based on the configured log levels.
        *
        * A Log_Level__mdt record "targets" a log when every attribute it specifies
        * (Category, Type, Area, User Id, Component Name) matches the log. Unspecified
        * (null) attributes act as wildcards, so a record can scope a level as broadly
        * (a global default) or as narrowly (a single user or component) as needed.
        *
        * Rules are resolved by specificity, not additively: among all rules that
        * target the log, the single most specific one decides, and it overrides
        * every less specific rule in both directions. A narrow rule can therefore
        * lower verbosity below a broader rule, not only raise it above -- which is
        * what makes it possible to silence one noisy component or user while a
        * permissive global default stays in place.
        *
        * Specificity is ranked by which attributes a rule names, from narrowest to
        * broadest scope: User Id > Component Name > Area > Type > Category. Each
        * attribute contributes a distinct weight, so any rule naming a User Id
        * outranks any rule that does not, and the ordering is total -- no two
        * different attribute combinations can tie. Rules that name the exact same
        * attributes are equally specific; those resolve to the most restrictive
        * (least verbose) level so that metadata order never changes the outcome.
        *
        * When no configured level targets the log at all, the log is allowed
        * through by default.
        * @param log -- Pharos log record to be saved
        */
        public Boolean isLogAllowed(pharos__Log__c log) {
            if (String.isBlank(log.Log_Level__c) || logLevels.isEmpty()) return true;

            TritonTypes.Level currentLevel;
            try {
                currentLevel = TritonTypes.Level.valueOf(log.Log_Level__c);
            } catch (Exception e) {
                // Fail open: an unparsable log level must never drop the log.
                return true;
            }

            String logUserId = normalizeUserId(log.pharos__User_Id__c);
            String logComponent = getComponentName(log);

            TritonTypes.Level effectiveLevel = null;
            Integer bestSpecificity = -1;
            for (LogLevelRule rule : logLevels) {
                if (!rule.targets(log, logUserId, logComponent)) continue;

                if (rule.specificity > bestSpecificity) {
                    // A strictly more specific rule replaces whatever we had.
                    bestSpecificity = rule.specificity;
                    effectiveLevel = rule.level;
                } else if (rule.specificity == bestSpecificity && rule.level.ordinal() < effectiveLevel.ordinal()) {
                    // Equally specific: keep the most restrictive level so that
                    // the outcome does not depend on metadata ordering.
                    effectiveLevel = rule.level;
                }
            }

            // No configured level targets this log -- allow it through by default.
            if (effectiveLevel == null) return true;

            return compareLevel(effectiveLevel, currentLevel);
        }
    }

    /**
    * Resolves the component name used for log level matching.
    * Flows are identified by their API name; Apex/LWC by the class/component
    * portion of the Apex Name (the text before the first '.').
    *
    * Stack-trace-derived Apex Names keep the frame's leading 'Class.' prefix
    * (for example 'Class.AccountService.updateAccounts'), which is the format
    * persisted on the log record. That prefix is stripped here so the component
    * resolves to the class name rather than the literal 'Class'. LWC names
    * ('myComponent.Proxy.method') and explicitly supplied operations have no
    * prefix and are unaffected.
    * @param log -- Pharos log record being evaluated
    * @return the component name, or null/blank when it cannot be determined
    */
    @TestVisible
    private static String getComponentName(pharos__Log__c log) {
        if (String.isNotBlank(log.pharos__Flow_API_Name__c)) return log.pharos__Flow_API_Name__c;

        String apexName = log.pharos__Apex_Name__c;
        if (String.isBlank(apexName)) return apexName;

        if (apexName.startsWith(CLASS_FRAME_PREFIX)) {
            apexName = apexName.substringAfter(CLASS_FRAME_PREFIX);
        }

        Integer dotIndex = apexName.indexOf('.');
        return dotIndex == -1 ? apexName : apexName.substring(0, dotIndex);
    }

    /**
    * Salesforce Ids are 18 characters in Apex, but Log Level metadata stores the
    * 15-character form. Matching is performed on the case-sensitive 15-character
    * prefix so both representations line up.
    * @param userId -- a 15 or 18 character user Id (or null)
    * @return the 15-character prefix, or the original value when shorter/blank
    */
    @TestVisible
    private static String normalizeUserId(String userId) {
        return String.isNotBlank(userId) && userId.length() > 15 ? userId.substring(0, 15) : userId;
    }

    /**
    * Normalizes a Log_Level__mdt scope field to the blank-as-wildcard contract:
    * rows can arrive with null or ''/whitespace blanks depending on the tooling
    * that created them, and all must behave the same.
    * @param value -- raw rule field value
    * @return null when blank, otherwise the trimmed value
    */
    @TestVisible
    private static String normalizeRuleValue(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    /**
    * Log level specificity weights, ordered from the narrowest scope to the
    * broadest: a User Id targets one person, a Component one class/flow/LWC,
    * while a Category covers an entire technology. Using distinct powers of two
    * makes a rule's score a bit set, so the ordering is total and any rule naming
    * a narrower attribute outranks every rule that does not -- for example a
    * User Id rule (16) beats Category + Type + Area (1 + 2 + 4 = 7).
    */
    private static final Integer LEVEL_WEIGHT_USER_ID = 16;
    private static final Integer LEVEL_WEIGHT_COMPONENT = 8;
    private static final Integer LEVEL_WEIGHT_AREA = 4;
    private static final Integer LEVEL_WEIGHT_TYPE = 2;
    private static final Integer LEVEL_WEIGHT_CATEGORY = 1;

    /**
    * In-memory representation of a Log_Level__mdt record, parsed once and cached
    * so that log level checks avoid re-reading and re-parsing metadata per log.
    */
    private class LogLevelRule {
        private final String category;
        private final String type;
        private final String area;
        private final String userId;
        private final String component;
        private final TritonTypes.Level level;

        /**
        * How narrowly this rule is scoped. Higher wins when several rules target
        * the same log. Computed once at parse time to keep the check allocation
        * free on the hot path.
        */
        private final Integer specificity;

        private LogLevelRule(Log_Level__mdt mdt) {
            this.category = normalizeRuleValue(mdt.Category__c);
            this.type = normalizeRuleValue(mdt.Type__c);
            this.area = normalizeRuleValue(mdt.Area__c);
            this.userId = normalizeUserId(normalizeRuleValue(mdt.User_Id__c));
            this.component = normalizeRuleValue(mdt.Component_Name__c);
            this.level = TritonTypes.Level.valueOf(mdt.Level__c);
            this.specificity =
                (this.userId != null ? LEVEL_WEIGHT_USER_ID : 0) +
                (this.component != null ? LEVEL_WEIGHT_COMPONENT : 0) +
                (this.area != null ? LEVEL_WEIGHT_AREA : 0) +
                (this.type != null ? LEVEL_WEIGHT_TYPE : 0) +
                (this.category != null ? LEVEL_WEIGHT_CATEGORY : 0);
        }

        /**
        * True when every attribute specified on this rule matches the log.
        * Null (unspecified) rule attributes are treated as wildcards.
        */
        private Boolean targets(pharos__Log__c log, String logUserId, String logComponent) {
            // User ids compare case-sensitively (15-char Ids are case-sensitive base 62).
            return matches(category, log.pharos__Category__c)
                && matches(type, log.pharos__Type__c)
                && matches(area, log.pharos__Area__c)
                && (userId == null || userId.equals(logUserId))
                && matches(component, logComponent);
        }

        // Case-insensitive, null-safe comparison: rule values are free text
        // authored in the console, so matching must be forgiving on case.
        private Boolean matches(String ruleValue, String logValue) {
            return ruleValue == null || ruleValue.equalsIgnoreCase(logValue);
        }
    }

    /**
     * ---------------------------
     * Performance mark support.
     * ---------------------------
     *
     * The stateless half of Triton's performance marks: the literals both paired
     * records are built from, the name derivation, and the request id the span stack
     * is rooted at. Triton keeps everything that is mark state -- the span stack, the
     * open mark list -- and reads its naming and its literals from here.
     */

    /**
     * Summary prefixes for a mark's two halves, matched verbatim by the span converter
     * and identical to the ones the LWC logger emits.
     */
    public static final String MARK_STARTED_PREFIX = 'Performance started: ';
    public static final String MARK_COMPLETED_PREFIX = 'Performance: ';
    public static final String MARK_DURATION_PREFIX = 'Duration: ';
    public static final String MARK_DURATION_SUFFIX = 'ms';

    /** Name given to a mark whose name cannot be derived from the stack trace. */
    private static final String ANONYMOUS_MARK_NAME = 'AnonymousMark';

    /**
     * Occurrence counter behind the anonymous mark name fallback. Static lifetime is
     * the execution context, so the numbering restarts with every request -- exactly
     * as it did while this lived on Triton, and nothing resets it explicitly.
     */
    private static Integer anonymousMarkCounter = 0;

    /**
    * Derives a mark name from a stack trace: the topmost application frame, minus the
    * 'Class.' prefix getOperation retains. Falls back to a counted anonymous name.
    * @param stackTrace -- trace captured at the call site
    * @return the derived mark name, never blank
    */
    public static String deriveMarkName(String stackTrace) {
        String operation = getOperation(stackTrace);
        if (String.isNotBlank(operation) && operation.startsWith(CLASS_FRAME_PREFIX)) {
            operation = operation.substringAfter(CLASS_FRAME_PREFIX);
        }
        if (String.isNotBlank(operation)) return operation;

        anonymousMarkCounter++;
        return ANONYMOUS_MARK_NAME + anonymousMarkCounter;
    }

    /** The request id -- the root sentinel of an execution context's span stack. */
    public static String requestId() {
        return System.Request.getCurrent().getRequestId();
    }
}
