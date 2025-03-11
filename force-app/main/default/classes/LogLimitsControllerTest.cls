/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 *
 * Test class for LogLimitsController. Verifies the functionality for retrieving
 * and displaying Salesforce governor limit usage information from log records.
 */
@isTest
private class LogLimitsControllerTest {
    
    /**
     * Tests the getLimitUsage method with a complete set of limit values.
     * Verifies that:
     * 1. Results are returned and not empty
     * 2. Results are sorted by percentage in descending order
     * 3. Specific limit values are correctly calculated
     */
    @isTest
    static void testGetLimitUsage() {
        // Start test context
        Test.startTest();
        
        // Create a log with Triton
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.Debug)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.OpportunityManagement)
            .summary('Test Log with Limits')
            .details('Test log created for limit usage testing')
            .level(TritonTypes.Level.DEBUG)
            // Set all the limit values manually
            .attribute(TritonBuilder.BATCH_JOBS, 2)
            .attribute(TritonBuilder.BATCH_JOBS_LIMIT, 5)
            .attribute(TritonBuilder.CALLOUTS, 10)
            .attribute(TritonBuilder.CALLOUTS_LIMIT, 100)
            .attribute(TritonBuilder.CPU_TIME, 5000)
            .attribute(TritonBuilder.CPU_TIME_LIMIT, 10000)
            .attribute(TritonBuilder.DML_ROWS, 50)
            .attribute(TritonBuilder.DML_ROWS_LIMIT, 10000)
            .attribute(TritonBuilder.DML_STATEMENTS, 20)
            .attribute(TritonBuilder.DML_STATEMENTS_LIMIT, 150)
            .attribute(TritonBuilder.EMAIL_INVOCATIONS, 5)
            .attribute(TritonBuilder.EMAIL_INVOCATIONS_LIMIT, 10)
            .attribute(TritonBuilder.FUTURE_CALLS, 3)
            .attribute(TritonBuilder.FUTURE_CALLS_LIMIT, 50)
            .attribute(TritonBuilder.HEAP_SIZE, 2000)
            .attribute(TritonBuilder.HEAP_SIZE_LIMIT, 6000)
            .attribute(TritonBuilder.PUBLISH_IMMEDIATE_DML, 0)
            .attribute(TritonBuilder.PUBLISH_IMMEDIATE_DML_LIMIT, 150)
            .attribute(TritonBuilder.PUSH_NOTIFICATIONS, 0)
            .attribute(TritonBuilder.PUSH_NOTIFICATIONS_LIMIT, 10)
            .attribute(TritonBuilder.QUEUEABLE_JOBS, 1)
            .attribute(TritonBuilder.QUEUEABLE_JOBS_LIMIT, 50)
            .attribute(TritonBuilder.SOQL_AGGREGATES, 10)
            .attribute(TritonBuilder.SOQL_AGGREGATES_LIMIT, 300)
            .attribute(TritonBuilder.SOQL_QUERIES, 30)
            .attribute(TritonBuilder.SOQL_QUERIES_LIMIT, 100)
            .attribute(TritonBuilder.SOQL_ROWS, 500)
            .attribute(TritonBuilder.SOQL_ROWS_LIMIT, 50000)
            .attribute(TritonBuilder.SOSL_QUERIES, 2)
            .attribute(TritonBuilder.SOSL_QUERIES_LIMIT, 20);
        
        // Log the entry
        Triton.instance.logs.add(builder.build());
        Triton.instance.flushTop();
        
        // Stop test to process platform events
        Test.stopTest();
        
        // Query for the log ID after platform events are processed
        pharos__Log__c log = [SELECT Id FROM pharos__Log__c WHERE pharos__Summary__c = 'Test Log with Limits' LIMIT 1];
        
        // Call the method to test
        List<LogLimitsController.LimitUsage> results = LogLimitsController.getLimitUsage(log.Id);
        
        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertNotEquals(0, results.size(), 'Results should not be empty');
        
        // Verify the results are sorted by percentage in descending order
        for (Integer i = 0; i < results.size() - 1; i++) {
            System.assert(results[i].percentage >= results[i+1].percentage, 
                          'Results should be sorted by percentage in descending order');
        }
        
        // Verify specific values
        Map<String, LogLimitsController.LimitUsage> limitsByName = new Map<String, LogLimitsController.LimitUsage>();
        for (LogLimitsController.LimitUsage usage : results) {
            limitsByName.put(usage.name, usage);
        }
        
        // Check Email Invocations (should be highest percentage at 50%)
        LogLimitsController.LimitUsage emailUsage = limitsByName.get('Email Invocations');
        System.assertNotEquals(null, emailUsage, 'Email Invocations limit should be present');
        System.assertEquals(5, emailUsage.current, 'Email Invocations current value incorrect');
        System.assertEquals(10, emailUsage.max, 'Email Invocations max value incorrect');
        System.assertEquals(50, emailUsage.percentage, 'Email Invocations percentage incorrect');
        
        // Check SOQL Queries
        LogLimitsController.LimitUsage soqlUsage = limitsByName.get('SOQL Queries');
        System.assertNotEquals(null, soqlUsage, 'SOQL Queries limit should be present');
        System.assertEquals(30, soqlUsage.current, 'SOQL Queries current value incorrect');
        System.assertEquals(100, soqlUsage.max, 'SOQL Queries max value incorrect');
        System.assertEquals(30, soqlUsage.percentage, 'SOQL Queries percentage incorrect');
        
        // Verify that the first result has the highest percentage
        System.assertEquals(results[0].percentage, 
                           Math.max(emailUsage.percentage, 
                                   Math.max(soqlUsage.percentage, results[0].percentage)), 
                           'First result should have highest percentage');
    }
    
    /**
     * Tests the getLimitUsage method with partial limit values.
     * Verifies that:
     * 1. Only limits with both valid current and max values are included
     * 2. Limits with null values are properly excluded
     */
    @isTest
    static void testGetLimitUsageWithNullValues() {
        // Start test context
        Test.startTest();
        
        // Create a log with partial data using Triton
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.Debug)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.OpportunityManagement)
            .summary('Test Log with Partial Limits')
            .details('Test log created for partial limit usage testing')
            .level(TritonTypes.Level.DEBUG)
            // Set only some limit values
            .attribute(TritonBuilder.BATCH_JOBS, 2)
            .attribute(TritonBuilder.BATCH_JOBS_LIMIT, 5)
            .attribute(TritonBuilder.CALLOUTS, null)  // Null current value
            .attribute(TritonBuilder.CALLOUTS_LIMIT, 100)
            .attribute(TritonBuilder.CPU_TIME, 5000)
            .attribute(TritonBuilder.CPU_TIME_LIMIT, null)  // Null limit value
            .attribute(TritonBuilder.DML_ROWS, 50)
            .attribute(TritonBuilder.DML_ROWS_LIMIT, 10000);
        
        // Log the entry
        Triton.instance.logs.add(builder.build());
        Triton.instance.flushTop();
        // Stop test to process platform events
        Test.stopTest();
        
        // Query for the log ID after platform events are processed
        pharos__Log__c log = [SELECT Id FROM pharos__Log__c WHERE pharos__Summary__c = 'Test Log with Partial Limits' LIMIT 1];
        
        // Call the method to test
        List<LogLimitsController.LimitUsage> results = LogLimitsController.getLimitUsage(log.Id);
        
        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        
        // Only two limits should be included (Batch Jobs and DML Rows)
        // CPU Time should be excluded because max is null
        // Callouts should be excluded because current is null
        System.assertEquals(2, results.size(), 'Only two limits should be included');
        
        // Verify the limits included are the correct ones
        Set<String> expectedLimitNames = new Set<String>{'Batch Jobs', 'DML Rows'};
        Set<String> actualLimitNames = new Set<String>();
        for (LogLimitsController.LimitUsage usage : results) {
            actualLimitNames.add(usage.name);
        }
        
        System.assertEquals(expectedLimitNames, actualLimitNames, 
                           'Only Batch Jobs and DML Rows should be included');
    }
    
    /**
     * Tests the Comparable implementation of the LimitUsage class.
     * Verifies that:
     * 1. The compareTo method correctly compares percentages
     * 2. Sorting works as expected (descending by percentage)
     */
    @isTest
    static void testLimitUsageComparable() {
        // Create test LimitUsage objects
        LogLimitsController.LimitUsage usage1 = new LogLimitsController.LimitUsage();
        usage1.name = 'Test 1';
        usage1.current = 50;
        usage1.max = 100;
        usage1.percentage = 50;
        
        LogLimitsController.LimitUsage usage2 = new LogLimitsController.LimitUsage();
        usage2.name = 'Test 2';
        usage2.current = 75;
        usage2.max = 100;
        usage2.percentage = 75;
        
        LogLimitsController.LimitUsage usage3 = new LogLimitsController.LimitUsage();
        usage3.name = 'Test 3';
        usage3.current = 25;
        usage3.max = 100;
        usage3.percentage = 25;
        
        // Test compareTo method
        System.assertEquals(-1, usage2.compareTo(usage1), 
                           'Higher percentage should return -1');
        System.assertEquals(1, usage1.compareTo(usage2), 
                           'Lower percentage should return 1');
        System.assertEquals(0, usage1.compareTo(usage1), 
                           'Equal percentage should return 0');
        
        // Test sorting
        List<LogLimitsController.LimitUsage> usages = new List<LogLimitsController.LimitUsage>{
            usage1, usage2, usage3
        };
        usages.sort();
        
        // Verify sort order (descending by percentage)
        System.assertEquals('Test 2', usages[0].name, 'Highest percentage should be first');
        System.assertEquals('Test 1', usages[1].name, 'Middle percentage should be second');
        System.assertEquals('Test 3', usages[2].name, 'Lowest percentage should be last');
    }
} 