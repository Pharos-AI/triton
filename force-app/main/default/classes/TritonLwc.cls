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
    @description Class used to log LWC errors
 */
public with sharing class TritonLwc {

    /**
    * Create component logs from LWC
    * Use this method to persist logs generated from LWC components
    * @param componentLogs -- a collection of ComponentLog objects
    */
    @AuraEnabled
    public static void saveComponentLogs(List<ComponentLog> componentLogs) {
        Triton logInstance = Triton.instance;
        for (ComponentLog componentLog : componentLogs) {
            Id userId = null;
            Id relatedId = null;
            TritonTypes.Category category = null;
            TritonTypes.Area area = null;
            TritonTypes.Level level = null;
            String details = componentLog.details == null ? '' : componentLog.details;

            try {
                userId = Id.valueOf(componentLog.userId);
            } catch (System.StringException e) {
                //invalid user id
                details += '\nInvalid User Id: ' + componentLog.userId + '. This log will not be linked to a user.';
            }

            try {
                relatedId = Id.valueOf(componentLog.recordId);
            } catch (System.StringException e) {
                //invalid record id
                details += '\nInvalid Record Id: ' + componentLog.recordId + '. This log will not be linked to a record.';
            }

            String categoryStr = String.isNotBlank(componentLog.category) ? componentLog.category : componentLog.component.category;

            try {
                category = TritonTypes.Category.valueOf(categoryStr);
            } catch(System.NoSuchElementException e) {
                //invalid category
                details += '\nInvalid Log Category: ' + categoryStr + '. Default LWC category will be used.';                 
            }

            String areaStr = String.isNotBlank(componentLog.area) ? componentLog.area : componentLog.component.name;

            try {
                area = TritonTypes.Area.valueOf(areaStr);
            } catch(System.NoSuchElementException e) {
                //invalid area
                details += '\nInvalid Log Functional Area: ' + areaStr + '. Default LWC area will be used.';                 
            }

            String levelStr = componentLog.level;

            try {   
                level = TritonTypes.Level.valueOf(levelStr);
            } catch(System.NoSuchElementException e) {
                //invalid log level
                details += '\nInvalid Log Level: ' + levelStr + '. Default INFO level will be used.';                                 
            }

            logInstance.add(
                    Triton.makeBuilder()
                            //category will be fetched from the componentLog
                            .category(category == null ? TritonTypes.Category.LWC : category)
                            //type will be fetched from the componentLog directly, of from the error. If neither are set, Frontend will be used
                            .type(String.isNotBlank(componentLog.type) ? componentLog.type :
                                    componentLog.error != null ? componentLog.error.type : TritonTypes.Type.Frontend.name())
                            //area will be fetched from the componentLog directly if set. Otherwise component name will be used
                            .area(area == null ? TritonTypes.Area.LWC : area)
                            //summary will be fetched from the componentLog directly if set. Otherwise, error message will be used if provided.
                            .summary(String.isNotBlank(componentLog.summary) ? componentLog.summary :
                                    componentLog.error != null ? componentLog.error.message : null)
                            .stackTrace(componentLog.stack)
                            .details(details)
                            //transaction id will be used from the componentLog, or a new transaction id will be generated
                            .transactionId(String.isNotBlank(componentLog.transactionId) ? componentLog.transactionId : logInstance.TRANSACTION_ID)
                            .userId(userId)
                            //apex name will be set to component.function or component.action
                            .operation(componentLog.component.name + '.' +
                                    (String.isNotBlank(componentLog.component.function) ? componentLog.component.function : componentLog.component.action))
                            .relatedObject(relatedId)
                            //created timestamp will be either set from the componentLog if provided, otherwise current timestamp will be used
                            .createdTimestamp(componentLog.createdTimestamp != null ? Double.valueOf(componentLog.createdTimestamp) : Double.valueOf(System.now().getTime()))
                            //log level will be taken from the componentLog if provided, otherwise INFO will be used
                            .level(level == null ? TritonTypes.Level.INFO : level)
                            .duration(componentLog.duration)
                            .build());
        }
        logInstance.flush();
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
        @AuraEnabled
        public String action { get; set; }
    }

    /**
     * A wrapper class for passing log data from LWC
     */
    public class ComponentLog {
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
        public Decimal totalTime { get; set; }
        @AuraEnabled
        public String userId { get; set; }
        @AuraEnabled
        public String recordId { get; set; }
        @AuraEnabled
        public String objectApiName { get; set; }
        @AuraEnabled
        public String stack { get; set; }
        @AuraEnabled
        public Error error { get; set; }
        @AuraEnabled
        public Component component { get; set; }
        @AuraEnabled
        public String transactionId { get; set; }
        @AuraEnabled
        public Decimal createdTimestamp { get; set; }
        @AuraEnabled
        public String level { get; set; }
        @AuraEnabled
        public Decimal duration { get; set; }
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
}
