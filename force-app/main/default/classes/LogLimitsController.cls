/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 *
 * The LogLimitsController class provides functionality to retrieve and display
 * Salesforce governor limit usage information from log records. It allows for
 * visualizing how close each limit is to its maximum value.
 */
public with sharing class LogLimitsController {
    /**
     * Inner class that represents a single governor limit usage.
     * Implements Comparable to allow sorting by percentage usage.
     */
    public class LimitUsage implements Comparable {
        @AuraEnabled public String name;
        @AuraEnabled public Decimal current;
        @AuraEnabled public Decimal max;
        @AuraEnabled public Decimal percentage;
        
        /**
         * Compares this LimitUsage with another based on percentage.
         * Used for sorting limits in descending order by percentage.
         * 
         * @param compareTo The object to compare with
         * @return -1 if this percentage is higher, 1 if lower, 0 if equal
         */
        public Integer compareTo(Object compareTo) {
            LimitUsage other = (LimitUsage)compareTo;
            if (this.percentage > other.percentage) return -1;
            if (this.percentage < other.percentage) return 1;
            return 0;
        }
    }
    
    /**
     * Retrieves governor limit usage information from a log record.
     * Calculates percentage usage for each limit and sorts them in descending order.
     * 
     * @param logId The ID of the log record to retrieve limit information from
     * @return List of LimitUsage objects containing limit information, sorted by percentage
     */
    @AuraEnabled(cacheable=true)
    public static List<LimitUsage> getLimitUsage(Id logId) {
        List<LimitUsage> limits = new List<LimitUsage>();
        pharos__Log__c log = [
            SELECT 
                Batch_Jobs__c, Batch_Jobs_Limit__c,
                Callouts__c, Callouts_Limit__c,
                CPU_Time__c, CPU_Time_Limit__c,
                DML_Rows__c, DML_Rows_Limit__c,
                DML_Statements__c, DML_Statements_Limit__c,
                Email_Invocations__c, Email_Invocations_Limit__c,
                Future_Calls__c, Future_Calls_Limit__c,
                Heap_Size__c, Heap_Size_Limit__c,
                Publish_Immediate_DML__c, Publish_Immediate_DML_Limit__c,
                Push_Notifications__c, Push_Notifications_Limit__c,
                Queueable_Jobs__c, Queueable_Jobs_Limit__c,
                SOQL_Aggregates__c, SOQL_Aggregates_Limit__c,
                SOQL_Queries__c, SOQL_Queries_Limit__c,
                SOQL_Rows__c, SOQL_Rows_Limit__c,
                SOSL_Queries__c, SOSL_Queries_Limit__c
            FROM pharos__Log__c 
            WHERE Id = :logId
        ];
        
        addLimit(limits, 'Batch Jobs', log.Batch_Jobs__c, log.Batch_Jobs_Limit__c);
        addLimit(limits, 'Callouts', log.Callouts__c, log.Callouts_Limit__c);
        addLimit(limits, 'CPU Time', log.CPU_Time__c, log.CPU_Time_Limit__c);
        addLimit(limits, 'DML Rows', log.DML_Rows__c, log.DML_Rows_Limit__c);
        addLimit(limits, 'DML Statements', log.DML_Statements__c, log.DML_Statements_Limit__c);
        addLimit(limits, 'Email Invocations', log.Email_Invocations__c, log.Email_Invocations_Limit__c);
        addLimit(limits, 'Future Calls', log.Future_Calls__c, log.Future_Calls_Limit__c);
        addLimit(limits, 'Heap Size', log.Heap_Size__c, log.Heap_Size_Limit__c);
        addLimit(limits, 'Publish Immediate DML', log.Publish_Immediate_DML__c, log.Publish_Immediate_DML_Limit__c);
        addLimit(limits, 'Push Notifications', log.Push_Notifications__c, log.Push_Notifications_Limit__c);
        addLimit(limits, 'Queueable Jobs', log.Queueable_Jobs__c, log.Queueable_Jobs_Limit__c);
        addLimit(limits, 'SOQL Aggregates', log.SOQL_Aggregates__c, log.SOQL_Aggregates_Limit__c);
        addLimit(limits, 'SOQL Queries', log.SOQL_Queries__c, log.SOQL_Queries_Limit__c);
        addLimit(limits, 'SOQL Rows', log.SOQL_Rows__c, log.SOQL_Rows_Limit__c);
        addLimit(limits, 'SOSL Queries', log.SOSL_Queries__c, log.SOSL_Queries_Limit__c);
        
        limits.sort();
        return limits;
    }
    
    /**
     * Helper method to add a limit to the list if both current and max values are valid.
     * Calculates the percentage usage of the limit.
     * 
     * @param limits The list to add the limit to
     * @param name The name of the limit
     * @param current The current value of the limit
     * @param max The maximum value of the limit
     */
    private static void addLimit(List<LimitUsage> limits, String name, Decimal current, Decimal max) {
        if (current != null && max != null && max > 0) {
            LimitUsage usage = new LimitUsage();
            usage.name = name;
            usage.current = current;
            usage.max = max;
            usage.percentage = (current / max) * 100;
            limits.add(usage);
        }
    }
}