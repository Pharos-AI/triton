/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
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
            logInstance.add(
                    Triton.makeBuilder()
                            //category will be fetched from the componentLog
                            .category(String.isNotBlank(componentLog.category) ? componentLog.category : componentLog.component.category)
                            //type will be fetched from the componentLog directly, of from the error. If neither are set, Frontend will be used
                            .type(String.isNotBlank(componentLog.type) ? componentLog.type :
                                    componentLog.error != null ? componentLog.error.type : TritonTypes.Type.Frontend.name())
                            //area will be fetched from the componentLog directly if set. Otherwise component name will be used
                            .area(String.isNotBlank(componentLog.area) ? componentLog.area : componentLog.component.name)
                            //summary will be fetched from the componentLog directly if set. Otherwise, error message will be used if provided.
                            .summary(String.isNotBlank(componentLog.summary) ? componentLog.summary :
                                    componentLog.error != null ? componentLog.error.message : null)
                            .stackTrace(componentLog.stack)
                            .details(componentLog.details)
                            //transaction id will be used from the componentLog, or a new transaction id will be generated
                            .transactionId(String.isNotBlank(componentLog.transactionId) ? componentLog.transactionId : logInstance.TRANSACTION_ID)
                            .attribute(Triton.USER_ID, componentLog.userId)
                            //apex name will be set to component.function or component.action
                            .attribute(Triton.APEX_NAME, componentLog.component.name + '.' +
                                    (String.isNotBlank(componentLog.component.function) ? componentLog.component.function : componentLog.component.action))
                            .attribute(Triton.RELATED_ID, componentLog.recordId)
                            //created timestamp will be either set from the componentLog if provided, otherwise current timestamp will be used
                            .attribute(Triton.CREATED_TIMESTAMP, componentLog.createdTimestamp != null ? Double.valueOf(componentLog.createdTimestamp) : Double.valueOf(System.now().getTime()))
                            //log level will be taken from the componentLog if provided, otherwise INFO will be used
                            .attribute(Triton.LOG_LEVEL, String.isNotBlank(componentLog.level) ? componentLog.level : TritonTypes.Level.INFO.name())
                            .attribute(Triton.DURATION, componentLog.duration)
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
