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
 * Provides logging capabilities for Lightning Web Components (LWC).
 * This class exposes an AuraEnabled method that can be called from LWC to create log records
 * with customizable attributes like category, type, area, and level.
 * 
 * The class handles:
 * - Log creation with default INFO level if not specified
 * - Automatic transaction management
 * - Component context capture (name, function, action)
 * - Error details capture (message, stack trace, type)
 * - User and record ID validation
 * - Validation and fallback for the category and log level enums
 * - Functional areas: any non-blank area is kept as sent, a known one mapped to its
 *   TritonTypes.Area name (see resolveArea); a blank area lands as LWC
 * - Timestamp and duration tracking
 *
 * Never throws into the component: a log that fails to build is dropped and the
 * failure written to the debug log at ERROR, without costing the other logs.
 */
global with sharing class TritonLwc {

    /**
    * Create component logs from LWC
    * Use this method to persist logs generated from LWC components
    * @param componentLogs -- a collection of ComponentLog objects
    */
    @AuraEnabled
    public static void saveComponentLogs(List<ComponentLog> componentLogs) {
        try {
            if (componentLogs == null || TritonHelper.Config.isLoggingDisabled()) {
                return;
            }

            String transactionId = Triton.startTransaction();
            Triton.withCache();
            Boolean transactionIdFromCache = Triton.TRANSACTION_ID != transactionId;
            transactionId = Triton.TRANSACTION_ID;

            for (ComponentLog componentLog : componentLogs) {
                try {
                    // An unbound component sends no component info.
                    Component info = componentLog.componentInfo != null ? componentLog.componentInfo : new Component();
                    Id userId = null;
                    Id[] relatedIds = new Id[0];
                    TritonTypes.Category category = TritonTypes.Category.LWC;
                    TritonTypes.Level level = TritonTypes.Level.INFO;
                    String details = componentLog.details == null ? '' : componentLog.details;

                    //transaction was not resumed from cache
                    //transaction id was provided by the component
                    if(!transactionIdFromCache && String.isNotBlank(componentLog.transactionId)) {
                        transactionId = componentLog.transactionId;
                        Triton.resumeTransaction(transactionId);
                        transactionIdFromCache = true;
                    }
                    try {
                        userId = UserInfo.getUserId();
                        if(!String.isBlank(componentLog.userId)) {
                            userId = Id.valueOf(componentLog.userId);
                        }
                    } catch (Exception e) {
                        details += Triton.SPACE_SEP + TritonHelper.formatMessage('Invalid User Id: {0}. Context user will be used.', componentLog.userId);
                    }

                    if(componentLog.relatedObjectIds?.size() > 0) {
                        List<String> validIds = new List<String>();
                        for(String idStr : componentLog.relatedObjectIds) {
                            try {
                                // Attempt to convert to Id to validate
                                Id validId = Id.valueOf(idStr);
                                validIds.add(validId);
                            } catch (Exception e) {
                                details += Triton.SPACE_SEP + TritonHelper.formatMessage('Invalid Record Id: {0}. This ID will be skipped.', idStr);
                            }
                        }
                        relatedIds = validIds;
                    }

                    try {
                        category = TritonTypes.Category.valueOf(componentLog.category);
                    } catch(Exception e) {
                        //invalid category
                        details += Triton.SPACE_SEP + TritonHelper.formatMessage('Invalid Log Category: {0}. Default LWC category will be used.', componentLog.category);
                    }

                    // A blank level means "not set": it stays INFO, with no note.
                    String levelStr = componentLog.level;
                    if (String.isNotBlank(levelStr)) {
                        try {
                            level = TritonTypes.Level.valueOf(levelStr);
                        } catch(Exception e) {
                            //invalid log level
                            details += Triton.SPACE_SEP + TritonHelper.formatMessage('Invalid Log Level: {0}. Default INFO level will be used.', levelStr);
                        }
                    }

                    details += TritonHelper.formatLwcRuntimeInfo(componentLog.runtimeInfo);

                    TritonBuilder builder = Triton.makeBuilder();
                    if(level == TritonTypes.Level.ERROR) {
                        builder.createIssue();
                    }

                    Triton.log(builder
                                    //category will be fetched from the componentLog
                                    .category(category)
                                    //type will be fetched from the componentLog directly, of from the error. If neither are set, Frontend will be used
                                    .type(String.isNotBlank(componentLog.type) ? componentLog.type :
                                            componentLog.error != null ? componentLog.error.type : TritonTypes.Type.Frontend.name())
                                    //area is kept as sent, a known one under its TritonTypes.Area name; LWC when blank
                                    .area(resolveArea(componentLog.area))
                                    //summary will be fetched from the componentLog directly if set. Otherwise, error message will be used if provided.
                                    .summary(String.isNotBlank(componentLog.summary) ? componentLog.summary :
                                            componentLog.error != null ? componentLog.error.message : null)
                                    .stackTrace(componentLog.stack)
                                    .details(details)
                                    .transactionId(transactionId)
                                    .spanId(componentLog.spanId)
                                    .parentSpanId(componentLog.parentSpanId)
                                    .userId(userId)
                                    //apex name will be set to component.function, or whichever part is present
                                    .operation(operationName(info))
                                    .relatedObjects(relatedIds)
                                    //created timestamp will be either set from the componentLog if provided, otherwise current timestamp will be used
                                    .createdTimestamp(componentLog.createdTimestamp != null ? Double.valueOf(componentLog.createdTimestamp) : Double.valueOf(System.now().getTime()))
                                    //log level will be taken from the componentLog if provided, otherwise INFO will be used
                                    .level(level)
                                    .duration(componentLog.duration)
                                    .action(componentLog.action)
                                    .withoutLimitInfo()
                                    );
                } catch (Exception e) {
                    // One bad log never costs the others.
                    TritonHelper.recordFailure('LWC log', e, 1);
                }
            }

            Triton.flush(); // never throws
        } catch (Exception e) {
            TritonHelper.recordFailure('LWC save', e, componentLogs == null ? 0 : componentLogs.size());
        }
    }

    /**
     * The Area a browser log lands under. Any non-blank value is kept, as TritonBuilder.area(String)
     * and the Flow invocable keep it. A known TritonTypes.Area in any casing, with or without
     * underscores (the pre-2.0.0 JS constants were 'LEAD_CONVERSION' and so on), maps to the enum name,
     * so a feature's logs group together across tiers. Blank means "not set" and lands as LWC.
     * @param requested -- the area the component sent
     * @return the area to record
     */
    @TestVisible
    private static String resolveArea(String requested) {
        if (String.isBlank(requested)) return TritonTypes.Area.LWC.name();
        String trimmed = requested.trim();
        String folded = trimmed.remove('_');
        for (TritonTypes.Area known : TritonTypes.Area.values()) {
            if (known.name().equalsIgnoreCase(folded)) return known.name();
        }
        return trimmed;
    }

    /**
     * 'component.function', or whichever part is present; null when neither is.
     * Unbound components send no name.
     * @param info -- the component info the log carries, never null
     * @return the operation to record, or null
     */
    private static String operationName(Component info) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(info.name)) parts.add(info.name);
        if (String.isNotBlank(info.function)) parts.add(info.function);
        return parts.isEmpty() ? null : String.join(parts, '.');
    }

    /**
     * A wrapper class for passing component info data from LWC
     */
    public class Component {
        @AuraEnabled
        public String category { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String function { get; set; }
    }

    /**
     * A wrapper class for passing log data from LWC
     */
    public class ComponentLog {
        @AuraEnabled
        public String level { get; set; }
        @AuraEnabled
        public String category { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public String area { get; set; }
        @AuraEnabled
        public String summary { get; set; }
        @AuraEnabled
        public String details { get; set; }
        @AuraEnabled
        public String transactionId { get; set; }
        @AuraEnabled
        public Component componentInfo { get; set; }
        @AuraEnabled
        public Decimal duration { get; set; }
        @AuraEnabled
        public String action { get; set; }
        @AuraEnabled
        public Decimal createdTimestamp { get; set; }
        @AuraEnabled
        public Error error { get; set; }
        @AuraEnabled
        public String stack { get; set; }
        @AuraEnabled
        public String userId { get; set; }
        @AuraEnabled
        public RuntimeInfo runtimeInfo { get; set; }
        @AuraEnabled
        public List<String> relatedObjectIds { get; set; }
        @AuraEnabled
        public String spanId { get; set; }
        @AuraEnabled
        public String parentSpanId { get; set; }
    }

    /**
     * A wrapper class for passing error log data from LWC
     */
    public class Error {
        @AuraEnabled
        public String message { get; set; }
        @AuraEnabled
        public String stack { get; set; }
        @AuraEnabled
        public String type { get; set; }
    }

    public class RuntimeInfo {
        @AuraEnabled
        public String userAgent { get; set; }
        @AuraEnabled
        public String platform { get; set; }
        @AuraEnabled
        public String language { get; set; }
        @AuraEnabled
        public Boolean mobile { get; set; }
        @AuraEnabled
        public List<Object> brands { get; set; }
        @AuraEnabled
        public Integer viewportWidth { get; set; }
        @AuraEnabled
        public Integer viewportHeight { get; set; }
        @AuraEnabled
        public String theme { get; set; }
        @AuraEnabled
        public Double pageLoadTime { get; set; }
        @AuraEnabled
        public Double domInteractive { get; set; }
        @AuraEnabled
        public Double domContentLoaded { get; set; }
        @AuraEnabled
        public Double firstByte { get; set; }
        @AuraEnabled
        public Double serverTime { get; set; }
        @AuraEnabled
        public Double firstPaint { get; set; }
        @AuraEnabled
        public Double firstContentfulPaint { get; set; }
        @AuraEnabled
        public Double memoryUsage { get; set; }
        @AuraEnabled
        public Double memoryLimit { get; set; }
        @AuraEnabled
        public String connectionType { get; set; }
        @AuraEnabled
        public Double connectionSpeed { get; set; }
        @AuraEnabled
        public Double connectionRtt { get; set; }
        @AuraEnabled
        public Boolean saveData { get; set; }
        @AuraEnabled
        public String pathname { get; set; }
        @AuraEnabled
        public String hostname { get; set; }
        @AuraEnabled
        public Boolean isOnline { get; set; }
        @AuraEnabled
        public String formFactor { get; set; }
        @AuraEnabled
        public Integer screenWidth { get; set; }
        @AuraEnabled
        public Integer screenHeight { get; set; }
        @AuraEnabled
        public String orientation { get; set; }
    }
}