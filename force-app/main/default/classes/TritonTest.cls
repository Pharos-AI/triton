/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

@IsTest
private class TritonTest {

    private static void assertCreatedLog(TritonTypes.Category logCategory) {
        List<pharos__Log__c> logs = [SELECT Id, pharos__Category__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    private static void assertCreatedIntegrationLog() {
        List<pharos__Log__c> logs = [SELECT Id, pharos__Category__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertNotEquals(1, logs.size());
        System.assertEquals(TritonTypes.Category.Integration.name(), logs.get(0).pharos__Category__c);
        System.assertEquals(TritonTypes.Category.Integration.name(), logs.get(1).pharos__Category__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
        System.assertNotEquals(null, logs.get(1).pharos__Hash__c);
    }

    private static void assertBefore() {
        Integer countBefore = [SELECT COUNT() FROM pharos__Log__c];
        System.assertEquals(0, countBefore);
    }

    @TestSetup
    private static void testSetup() {
        pharos.Test_Logger.initSettings();
        // Clear out any existing log level metadata to ensure clean test environment
        Triton.LOG_LEVELS_MDT = new Log_Level__mdt[]{};
        Triton.LOG_LEVELS = null;
    }

    @IsTest
    private static void test_log_levels() {
        assertBefore();

        Log_Level__mdt ll = new Log_Level__mdt();
        ll.Level__c = TritonTypes.Level.DEBUG.name();
        Triton.LOG_LEVELS_MDT = new Log_Level__mdt[]{ll};

        System.assertEquals(1, Triton.LOG_LEVELS.size());
        System.assertEquals('Category:null;Type:null;Area:null', new List<String>(Triton.LOG_LEVELS.keySet())[0]);
        System.assertEquals(TritonTypes.Level.DEBUG, Triton.LOG_LEVELS.get('Category:null;Type:null;Area:null'));
    }

    @IsTest
    private static void test_log_levels_positive() {
        assertBefore();

        Log_Level__mdt ll = new Log_Level__mdt();
        ll.Level__c = TritonTypes.Level.DEBUG.name();
        Triton.LOG_LEVELS_MDT = new Log_Level__mdt[]{ll};

        Test.startTest();
        Triton.instance.event(TritonTypes.Level.DEBUG, TritonTypes.Type.Backend, TritonTypes.Area.Community, 'some event', 'error details');
        Test.stopTest();

        assertCreatedLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_log_levels_negative() {
        assertBefore();

        Log_Level__mdt ll = new Log_Level__mdt();
        ll.Level__c = TritonTypes.Level.DEBUG.name();
        Triton.LOG_LEVELS_MDT = new Log_Level__mdt[]{ll};

        Test.startTest();
        Triton.instance.event(TritonTypes.Level.FINE, TritonTypes.Type.Backend, TritonTypes.Area.Community, 'some event', 'error details');
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM pharos__Log__c where pharos__Category__c=:TritonTypes.Category.Event.name()]);
    }

    private static void setupLogLevelsMap() {
        Log_Level__mdt globalLevel = new Log_Level__mdt();
        globalLevel.Level__c = TritonTypes.Level.DEBUG.name();

        Log_Level__mdt categoryLevel = new Log_Level__mdt();
        categoryLevel.Level__c = TritonTypes.Level.FINE.name();
        categoryLevel.Category__c = TritonTypes.Category.Event.name();

        Log_Level__mdt categoryAndAreaLevel = new Log_Level__mdt();
        categoryAndAreaLevel.Level__c = TritonTypes.Level.FINEST.name();
        categoryAndAreaLevel.Category__c = TritonTypes.Category.Event.name();
        categoryAndAreaLevel.Area__c = TritonTypes.Area.Community.name();

        Triton.LOG_LEVELS_MDT = new Log_Level__mdt[]{globalLevel, categoryLevel, categoryAndAreaLevel};
    }

    @IsTest
    private static void test_log_levels_mapping() {
        assertBefore();

        setupLogLevelsMap();

        System.assertEquals(3, Triton.LOG_LEVELS.size());
        System.assertEquals(TritonTypes.Level.DEBUG, Triton.LOG_LEVELS.get('Category:null;Type:null;Area:null'));
        System.assertEquals(TritonTypes.Level.FINE, Triton.LOG_LEVELS.get('Category:Event;Type:null;Area:null'));
        System.assertEquals(TritonTypes.Level.FINEST, Triton.LOG_LEVELS.get('Category:Event;Type:null;Area:Community'));



        Test.startTest();
        Triton.instance.event(TritonTypes.Level.FINEST, TritonTypes.Type.Backend, TritonTypes.Area.Community, 'some event', 'error details');
        Test.stopTest();

        assertCreatedLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_log_levels_mapping_negative() {
        assertBefore();

        setupLogLevelsMap();

        Test.startTest();
        Triton.instance.event(TritonTypes.Level.FINEST, TritonTypes.Type.Backend, TritonTypes.Area.OpportunityManagement, 'some event', 'error details');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c WHERE pharos__Category__c = :TritonTypes.Category.Event.name()]);
    }

    @IsTest
    private static void test_sync_event() {
        assertBefore();

        Test.startTest();
        Triton.instance.event(TritonTypes.Type.Backend, TritonTypes.Area.Community, 'some event', 'error details');
        Test.stopTest();

        assertCreatedLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_sync_debug() {
        assertBefore();

        Test.startTest();
        Triton.instance.debug(TritonTypes.Type.Backend, TritonTypes.Area.Community, 'some debug', 'error details');
        Test.stopTest();

        assertCreatedLog(TritonTypes.Category.Debug);
    }

    @IsTest
    private static void test_sync_warning() {
        assertBefore();

        Test.startTest();
        Triton.instance.warning(TritonTypes.Type.Backend, TritonTypes.Area.Community, 'some warning', 'error details');
        Test.stopTest();

        assertCreatedLog(TritonTypes.Category.Warning);
    }

    @IsTest
    private static void test_sync_error() {
        assertBefore();

        Test.startTest();
        Triton.instance.error(TritonTypes.Type.Backend, TritonTypes.Area.Community, 'some error', 'error details');
        Test.stopTest();

        assertCreatedLog(TritonTypes.Category.Apex);
    }

    @IsTest
    private static void test_sync_error_from_exception() {
        assertBefore();

        Test.startTest();
        try {
            Integer i = 2/0;
        }
        catch(Exception e) {
            Triton.instance.error(TritonTypes.Area.Community, e);
        }
        Test.stopTest();

        assertCreatedLog(TritonTypes.Category.Apex);
    }

    @IsTest
    private static void test_sync_integration_from_exception() {
        assertBefore();

        Test.startTest();
        HttpCalloutMock multiCalloutMock = new MultiRequestMock(createEndpoint2TestResp());
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        testHttpRequest();
        Contact contact = new Contact();
        contact.LastName = 'Test';
        insert contact;
        testHttpRequest();
        Test.stopTest();

        assertCreatedIntegrationLog();
    }

    @IsTest
    private static void test_integration_error_sync() {
        assertBefore();

        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/Account/testId';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Triton.instance.integrationError(TritonTypes.Type.Backend, TritonTypes.Area.Community, 'test summary', 'test details', req, res);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    @IsTest
    private static void test_save_component_log() {
        assertBefore();

        Test.startTest();
        List<TritonLwc.ComponentLog> componentLogs = new List<TritonLwc.ComponentLog>();
        TritonLwc.ComponentLog componentLog = new TritonLwc.ComponentLog();
        componentLog.category = 'test category';
        componentLog.type = 'test type';
        componentLog.area = 'test area';
        componentLog.level = TritonTypes.Level.ERROR.name();
        componentLog.transactionId = TritonHelper.generateUUID4();
        componentLog.summary = 'test summary';
        componentLog.details = 'test details';
        componentLog.relatedObjectIds = new List<String>{'recordId'};
        TritonLwc.Component component = new TritonLwc.Component();
        component.category = 'test category';
        component.name = 'test name';
        component.function = 'test function';
        
        componentLog.componentInfo = component;
        componentLogs.add(componentLog);
        TritonLwc.saveComponentLogs(componentLogs);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Do_Not_Create_Issue__c, pharos__Transaction_Id_External__c, pharos__Summary__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals(componentLog.transactionId, logs.get(0).pharos__Transaction_Id_External__c);
        System.assertEquals(false, logs.get(0).pharos__Do_Not_Create_Issue__c);
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    @IsTest
    private static void test_lwc_runtime_info() {
        assertBefore();
        
        Test.startTest();
        
        // Create a mock ComponentLog with RuntimeInfo
        TritonLwc.ComponentLog componentLog = new TritonLwc.ComponentLog();
        componentLog.category = TritonTypes.Category.LWC.name();
        componentLog.type = 'test type';
        componentLog.area = 'test area';
        componentLog.summary = 'Runtime Info Test';
        componentLog.details = 'Initial details';
        
        // Add component info
        TritonLwc.Component component = new TritonLwc.Component();
        component.name = 'TestComponent';
        component.function = 'testFunction';
        componentLog.componentInfo = component;
        
        // Create and populate RuntimeInfo
        TritonLwc.RuntimeInfo runtimeInfo = new TritonLwc.RuntimeInfo();
        runtimeInfo.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
        runtimeInfo.platform = 'Windows';
        runtimeInfo.language = 'en-US';
        runtimeInfo.mobile = false;
        runtimeInfo.viewportWidth = 1920;
        runtimeInfo.viewportHeight = 1080;
        runtimeInfo.theme = 'Light';
        runtimeInfo.pageLoadTime = 1234.56;
        runtimeInfo.domInteractive = 800.12;
        runtimeInfo.domContentLoaded = 900.34;
        runtimeInfo.firstByte = 200.0;
        runtimeInfo.serverTime = 150.0;
        runtimeInfo.firstPaint = 850.0;
        runtimeInfo.firstContentfulPaint = 900.0;
        runtimeInfo.memoryUsage = 50 * 1024 * 1024; // 50MB in bytes
        runtimeInfo.memoryLimit = 100 * 1024 * 1024; // 100MB in bytes
        runtimeInfo.connectionType = '4g';
        runtimeInfo.connectionSpeed = 10.5;
        runtimeInfo.connectionRtt = 50.0;
        runtimeInfo.saveData = false;
        runtimeInfo.pathname = '/lightning/page/home';
        runtimeInfo.hostname = 'myorg.lightning.force.com';
        runtimeInfo.isOnline = true;
        runtimeInfo.formFactor = 'Large';
        runtimeInfo.screenWidth = 1920;
        runtimeInfo.screenHeight = 1080;
        runtimeInfo.orientation = 'landscape';
        
        componentLog.runtimeInfo = runtimeInfo;
        
        // Save the component log
        TritonLwc.saveComponentLogs(new List<TritonLwc.ComponentLog>{componentLog});
        
        Test.stopTest();
        
        // Verify the log was created with runtime info
        List<pharos__Log__c> logs = [
            SELECT Id, 
                   pharos__Category__c,
                   pharos__Type__c,
                   pharos__Area__c,
                   pharos__Details__c,
                   pharos__Summary__c,
                   pharos__Apex_Name__c
            FROM pharos__Log__c
        ];
        
        System.assertEquals(1, logs.size(), 'One log should be created');
        pharos__Log__c log = logs[0];
        
        // Verify log properties
        System.assertEquals(TritonTypes.Category.LWC.name(), log.pharos__Category__c);
        System.assertEquals('test type', log.pharos__Type__c);
        System.assertEquals(TritonTypes.Area.LWC.name(), log.pharos__Area__c);
        System.assertEquals('Runtime Info Test', log.pharos__Summary__c);
        System.assertEquals('TestComponent.testFunction', log.pharos__Apex_Name__c);
        
        // Verify runtime info in details
        String details = log.pharos__Details__c;
        System.assert(details.contains('Initial details'), 'Original details should be preserved');
        System.assert(details.contains('Runtime Info:'), 'Runtime info header should be present');
        
        // Verify environment section
        System.assert(details.contains('=== Environment ==='), 'Environment section should be present');
        System.assert(details.contains('User Agent: Mozilla/5.0'), 'User agent should be present');
        System.assert(details.contains('Platform: Windows'), 'Platform should be present');
        System.assert(details.contains('Language: en-US'), 'Language should be present');
        System.assert(details.contains('Mobile: false'), 'Mobile status should be present and false');
        System.assert(details.contains('Viewport: 1920x1080'), 'Viewport dimensions should be present');
        System.assert(details.contains('Theme: Light'), 'Theme should be present');
        
        // Verify performance section
        System.assert(details.contains('=== Performance ==='), 'Performance section should be present');
        System.assert(details.contains('Page Load Time: 1234.56ms'), 'Page load time should be present');
        System.assert(details.contains('DOM Interactive: 800.12ms'), 'DOM interactive time should be present');
        System.assert(details.contains('First Paint: 850.00ms'), 'First paint time should be present');
        
        // Verify memory section
        System.assert(details.contains('=== Memory ==='), 'Memory section should be present');
        System.assert(details.contains('Memory Usage: 50.00MB'), 'Memory usage should be present');
        System.assert(details.contains('Memory Limit: 100.00MB'), 'Memory limit should be present');
        
        // Verify network section
        System.assert(details.contains('=== Network ==='), 'Network section should be present');
        System.assert(details.contains('Connection Type: 4g'), 'Connection type should be present');
        System.assert(details.contains('Connection Speed: 10.5Mbps'), 'Connection speed should be present');
        System.assert(details.contains('Connection RTT: 50.00ms'), 'Connection RTT should be present');
        System.assert(details.contains('Path: /lightning/page/home'), 'Path should be present');
        
        // Verify device section
        System.assert(details.contains('=== Device ==='), 'Device section should be present');
        System.assert(details.contains('Form Factor: Large'), 'Form factor should be present');
        System.assert(details.contains('Screen: 1920x1080'), 'Screen dimensions should be present');
        System.assert(details.contains('Orientation: landscape'), 'Orientation should be present');
    }

    @IsTest
    private static void test_save_component_log_negative() {
        assertBefore();

        Test.startTest();
        List<TritonLwc.ComponentLog> componentLogs = new List<TritonLwc.ComponentLog>();
        TritonLwc.ComponentLog componentLog = new TritonLwc.ComponentLog();
        
        // Set mixed valid and invalid record IDs
        componentLog.relatedObjectIds = new List<String>{
            UserInfo.getUserId(),
            'invalid-record-id'
        };
        componentLog.category = 'InvalidCategory';
        componentLog.area = 'InvalidArea';
        componentLog.level = 'InvalidLevel';
        componentLog.details = 'Initial details';
        componentLog.userId = 'invalid-user-id';
        //blank summary
        componentLog.summary = '';
        
        // Test error object handling
        TritonLwc.Error error = new TritonLwc.Error();
        error.message = 'Error message';
        error.type = 'Error type';
        error.stack = 'Error stack';
        componentLog.error = error;
        
        // Test component object with invalid category
        TritonLwc.Component component = new TritonLwc.Component();
        component.category = 'InvalidComponentCategory';
        component.name = 'TestComponent';
        component.function = 'testFunction';
        componentLog.componentInfo = component;
        
        componentLogs.add(componentLog);
        TritonLwc.saveComponentLogs(componentLogs);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, 
                                       pharos__Category__c,
                                       pharos__Type__c,
                                       pharos__Area__c,
                                       Log_Level__c,
                                       pharos__Details__c,
                                       pharos__Summary__c,
                                       pharos__User_Id__c,
                                       pharos__Related_Objects__c,
                                       pharos__Apex_Name__c
                                FROM pharos__Log__c];
        
        System.assertEquals(1, logs.size(), 'One log should be created');
        pharos__Log__c log = logs[0];
        
        // Verify default/fallback values are used
        System.assertEquals(TritonTypes.Category.LWC.name(), log.pharos__Category__c, 'Should fall back to LWC category');
        System.assertEquals(TritonTypes.Area.LWC.name(), log.pharos__Area__c, 'Should fall back to LWC area');
        System.assertEquals(TritonTypes.Level.INFO.name(), log.Log_Level__c, 'Should fall back to INFO level');
        System.assertEquals('Error type', log.pharos__Type__c, 'Should use error type');
        System.assertEquals('TestComponent.testFunction', log.pharos__Apex_Name__c, 'Should combine component name and function');
        System.assertEquals(error.message, log.pharos__Summary__c, 'Should use error message as summary');
        // Verify error messages in details
        String details = log.pharos__Details__c;
        System.assert(details.contains('Invalid User Id'), 'Should contain user ID error message');
        System.assert(details.contains('Invalid Record Id'), 'Should contain record ID error message');
        System.assert(details.contains('Invalid Log Category'), 'Should contain category error message');
        System.assert(details.contains('Invalid Log Functional Area'), 'Should contain area error message');
        System.assert(details.contains('Invalid Log Level'), 'Should contain level error message');
        
        // Verify null values for invalid IDs
        System.assertEquals(UserInfo.getUserId(), log.pharos__User_Id__c, 'User ID should be current user for invalid');
        System.assertEquals(
            JSON.serialize(new List<String>{UserInfo.getUserId()}), 
            log.pharos__Related_Objects__c, 
            'Related objects should only contain the valid ID'
        );
    }

    @IsTest
    private static void test_flow() {
        assertBefore();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        
        // Test 1: Basic flow log with valid category
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog);
        
        // Test 2: Flow log with invalid category
        TritonFlow.FlowLog invalidCategoryLog = new TritonFlow.FlowLog();
        invalidCategoryLog.category = 'InvalidCategory';
        invalidCategoryLog.type = 'type';
        invalidCategoryLog.area = 'area';
        invalidCategoryLog.summary = 'test invalid';
        invalidCategoryLog.details = 'test invalid';
        flowLogs.add(invalidCategoryLog);
        
        // Test 3: Flow log with transaction ID
        TritonFlow.FlowLog transactionLog = new TritonFlow.FlowLog();
        transactionLog.category = TritonTypes.Category.Flow.name();
        transactionLog.type = 'type';
        transactionLog.area = 'area';
        transactionLog.summary = 'test transaction';
        transactionLog.details = 'test transaction';
        transactionLog.transactionId = 'test-transaction-id';
        flowLogs.add(transactionLog);
        
        // Test 4: Flow log with empty category
        TritonFlow.FlowLog emptyCategoryLog = new TritonFlow.FlowLog();
        emptyCategoryLog.category = '';
        emptyCategoryLog.type = 'type';
        emptyCategoryLog.area = 'area';
        emptyCategoryLog.summary = 'test empty';
        emptyCategoryLog.details = 'test empty';
        flowLogs.add(emptyCategoryLog);
        
        TritonFlow.log(flowLogs);
        Test.stopTest();

        // Verify logs were created with correct properties
        List<pharos__Log__c> logs = [
            SELECT Id, 
                   pharos__Category__c, 
                   pharos__Summary__c, 
                   pharos__Details__c,
                   pharos__Transaction_Id_External__c,
                   pharos__Hash__c 
            FROM pharos__Log__c 
            ORDER BY CreatedDate
        ];
        
        System.assertEquals(4, logs.size(), 'Should have created 4 logs');
        
        // Verify first log (valid category)
        System.assertEquals(TritonTypes.Category.Flow.name(), logs[0].pharos__Category__c);
        System.assertEquals('test summary', logs[0].pharos__Summary__c);
        
        // Verify second log (invalid category)
        System.assertEquals(TritonTypes.Category.Flow.name(), logs[1].pharos__Category__c);
        System.assert(logs[1].pharos__Details__c.contains('Unable to locate category: InvalidCategory'));
        
        // Verify third log (with transaction ID)
        System.assertEquals('test-transaction-id', logs[2].pharos__Transaction_Id_External__c);
        
        // Verify fourth log (empty category)
        System.assertEquals(TritonTypes.Category.Flow.name(), logs[3].pharos__Category__c);
        System.assert(!logs[3].pharos__Details__c.contains('Unable to locate category'));
        
    }

    @IsTest
    private static void test_flow_with_stacktrace() {
        assertBefore();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.stacktrace = 'test stacktrace';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog);
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(flowLogs);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('test stacktrace', results.get(0).fullStacktrace);

        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    @IsTest
    private static void test_flow_with_stacktrace_multiple_logs() {
        assertBefore();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog1 = new TritonFlow.FlowLog();
        flowLog1.category = TritonTypes.Category.Flow.name();
        flowLog1.type = 'type';
        flowLog1.area = 'area';
        flowLog1.summary = 'test';
        flowLog1.details = 'test';
        flowLog1.stacktrace = 'teststacktrace1';
        flowLog1.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog1);
        TritonFlow.FlowLog flowLog2 = new TritonFlow.FlowLog();
        flowLog2.category = TritonTypes.Category.Flow.name();
        flowLog2.type = 'type';
        flowLog2.area = 'area';
        flowLog2.summary = 'test';
        flowLog2.details = 'test';
        flowLog2.fullStacktrace = flowLog1.stacktrace;
        flowLog2.stacktrace = 'teststacktrace2';
        flowLog2.additionalFields = '{"pharos__Summary__c":"test summary 2","pharos__Details__c":"test Details 2"}';
        flowLogs.add(flowLog2);
        List<TritonFlow.FlowLogOutput> results = TritonFlow.log(flowLogs);
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals('teststacktrace1', results.get(0).fullStacktrace);
        System.assertEquals('teststacktrace1teststacktrace2', results.get(1).fullStacktrace);

        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c, pharos__Stacktrace__c FROM pharos__Log__c];
        System.assertEquals(2, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertEquals('test summary 2', logs.get(1).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
        System.assertNotEquals(null, logs.get(1).pharos__Hash__c);
        System.assertEquals('teststacktrace1', logs.get(0).pharos__Stacktrace__c);
        System.assertEquals('teststacktrace1teststacktrace2', logs.get(1).pharos__Stacktrace__c);
    }

    @IsTest
    private static void test_flow_wrong_category() {
        assertBefore();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = 'InvalidCategory';
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog);
        TritonFlow.log(flowLogs);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Category__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals(TritonTypes.Category.Flow.name(), logs.get(0).pharos__Category__c);
    }

    @IsTest
    private static void test_flow_create_issue() {
        assertBefore();

        Test.startTest();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.level = 'ERROR';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        TritonFlow.processFlowLog(flowLog);
        Test.stopTest();
        System.assertEquals(1, Triton.instance.logs.size());
        System.assertEquals(false, Triton.instance.logs.get(0).pharos__Do_Not_Create_Issue__c);
    }    

    @IsTest
    private static void test_flow_bad_additional_fields_json() {
        assertBefore();
        
        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'test type';
        flowLog.area = 'test area';
        flowLog.summary = 'test summary';
        flowLog.details = 'test';
        flowLog.level = 'level';
        flowLog.additionalFields = '{bad_json "test"}';
        flowLogs.add(flowLog);
        TritonFlow.log(flowLogs);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, 
                                       pharos__Details__c, 
                                       pharos__Summary__c, 
                                       pharos__Hash__c 
                                FROM pharos__Log__c];
        pharos__Log__c log = logs.get(0);
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', log.pharos__Summary__c);
        System.assert(log.pharos__Details__c.contains('Unable to locate log level'), 'Log level error should be present');
        System.assert(log.pharos__Details__c.contains('failed to parse json input'), 'Additional fields parse error should be present');
    }

    @IsTest
    private static void test_triton_builder() {
        assertBefore();

        Test.startTest();
        Triton.instance.event(TritonTypes.Level.INFO, TritonTypes.Type.Backend, TritonTypes.Area.Community, 'some event', 'error details');
        Test.stopTest();

        pharos__Log__c log = [select Id from pharos__Log__c limit 1];
        TritonBuilder builder = new TritonBuilder();
        
        builder.category(TritonTypes.Category.Apex);
        System.assertEquals(TritonTypes.Category.Apex.name(), builder.build().pharos__Category__c);

        builder.type(TritonTypes.Type.Backend);
        System.assertEquals(TritonTypes.Type.Backend.name(), builder.build().pharos__Type__c);

        builder.area(TritonTypes.Area.Community);
        System.assertEquals(TritonTypes.Area.Community.name(), builder.build().pharos__Area__c);

        builder.level(TritonTypes.Level.FINE);
        System.assertEquals(TritonTypes.Level.FINE.name(), builder.build().Log_Level__c);

        builder.operation('Operation');
        System.assertEquals('Operation', builder.build().pharos__Apex_Name__c);

        builder.userId(UserInfo.getUserId());
        System.assertEquals(UserInfo.getUserId(), builder.build().pharos__User_Id__c);

        builder.relatedObject(log.Id);
        System.assertEquals(JSON.serialize(new String[]{log.Id}), builder.build().pharos__Related_Objects__c);

        builder.duration(1);
        System.assertEquals(1, builder.build().pharos__Duration__c);

        builder.summary('Test Summary');
        System.assertEquals('Test Summary', builder.build().pharos__Summary__c);

        builder.details('Test Details');
        System.assertEquals('Test Details', builder.build().pharos__Details__c);

        builder.stackTrace('Test Stack Trace');
        System.assertEquals('Test Stack Trace', builder.build().pharos__Stacktrace__c);

        builder.transactionId('test-transaction-id');
        System.assertEquals('test-transaction-id', builder.build().pharos__Transaction_Id_External__c);

        builder.createIssue();
        System.assertEquals(false, builder.build().pharos__Do_Not_Create_Issue__c);

        builder.type('CustomType');
        System.assertEquals('CustomType', builder.build().pharos__Type__c);

        builder.area('CustomArea');
        System.assertEquals('CustomArea', builder.build().pharos__Area__c);

        Set<Id> relatedIds = new Set<Id>{log.Id};
        builder.relatedObjects(relatedIds);
        System.assertEquals(JSON.serialize(relatedIds), builder.build().pharos__Related_Objects__c);

        builder.relatedObjects(new List<Id>{log.Id});
        System.assertEquals(JSON.serialize(relatedIds), builder.build().pharos__Related_Objects__c);

        Set<String> relatedStringIds = new Set<String>{log.Id};
        builder.relatedObjects(relatedStringIds);
        System.assertEquals(JSON.serialize(relatedIds), builder.build().pharos__Related_Objects__c);

        builder.relatedObject(log.Id.toString());
        System.assertEquals(JSON.serialize(new String[]{log.Id}), builder.build().pharos__Related_Objects__c);

        Double timestamp = System.now().getTime();
        builder.createdTimestamp(timestamp);
        System.assertEquals(timestamp, builder.build().pharos__Created_Timestamp__c);

        builder.interviewGuid('test-guid');
        System.assertEquals('test-guid', builder.build().pharos__Interview_GUID_External__c);

        builder.flowApiName('Test_Flow');
        System.assertEquals('Test_Flow', builder.build().pharos__Flow_API_Name__c);

        builder.attribute(TritonBuilder.LOG_LEVEL, 'Custom Value');
        System.assertEquals('Custom Value', builder.build().get(TritonBuilder.LOG_LEVEL));

        RestRequest restReq = new RestRequest();
        RestResponse restRes = new RestResponse();
        restReq.requestURI = '/services/apexrest/Account/testId';
        restReq.httpMethod = 'GET';

        builder.integrationPayload(restReq, restRes);
        System.assertEquals(TritonHelper.toJson(restReq, restRes), builder.build().pharos__Stacktrace_Parse_Result__c);

        HttpRequest httpReq = new HttpRequest();
        HttpResponse httpRes = new HttpResponse();

        builder.integrationPayload(httpReq, httpRes);
        System.assertEquals(TritonHelper.toJson(httpReq, httpRes), builder.build().pharos__Stacktrace_Parse_Result__c);
    }

    @IsTest
    private static void test_template() {
        assertBefore();
        
        TritonBuilder template = Triton.makeBuilder();
        template.category(TritonTypes.Category.Apex);
        template.type(TritonTypes.Type.Backend);
        template.area(TritonTypes.Area.Community);
        template.level(TritonTypes.Level.INFO);
        Triton.instance.setTemplate(template);
        Test.startTest();
        Triton.instance.log(Triton.instance.fromTemplate()
                                .summary('some event')
                                .details('error details'));
        Test.stopTest();
        pharos__Log__c[] logs = [SELECT Id, 
                                        pharos__Category__c, 
                                        pharos__Type__c, 
                                        pharos__Area__c, 
                                        Log_Level__c, 
                                        pharos__Details__c, 
                                        pharos__Summary__c,
                                        pharos__Stacktrace__c 
                                        FROM pharos__Log__c];
        pharos__Log__c log = logs.get(0);
        System.assertEquals(1, logs.size());
        System.assertEquals(TritonTypes.Category.Apex.name(), log.pharos__Category__c);
        System.assertEquals(TritonTypes.Type.Backend.name(), log.pharos__Type__c);
        System.assertEquals(TritonTypes.Area.Community.name(), log.pharos__Area__c);
        System.assertEquals(TritonTypes.Level.INFO.name(), log.Log_Level__c);
        System.assert(!String.isBlank(log.pharos__Stacktrace__c));
        System.assertEquals('some event', log.pharos__Summary__c);
        System.assertEquals('error details', log.pharos__Details__c);
    }


    public static final String TEST_ENDPOINT = 'https://test.endpoint';

    public static Map<String, HttpCalloutMock> createEndpoint2TestResp() {
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(TEST_ENDPOINT, new SingleRequestMock(
                403,
                'Forbidden',
                'Bad_OAuth_Token'
        ));
        endpoint2TestResp.put(TEST_ENDPOINT, new SingleRequestMock(
                200,
                'OK',
                'Done'
        ));
        return endpoint2TestResp;
    }

    public static void testHttpRequest() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TEST_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{}');
        req.setTimeout(120000);
        Http h = new Http();
        HttpResponse res;
        try {
            res = h.send(req);
            if (res.getStatusCode() != 200 || res.getStatusCode() != 201) {
                Triton.instance.integrationError(TritonTypes.Type.Backend, TritonTypes.Area.Community, 'test integration', 'test error details', req, res);
            }
        } catch (Exception e) {
            Triton.instance.integrationError(TritonTypes.Area.Community, e, req, res);
        }
    }

    public class MultiRequestMock implements HttpCalloutMock {

        Map<String, HttpCalloutMock> requests;

        public MultiRequestMock(Map<String, HttpCalloutMock> requests) {
            this.requests = requests;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpCalloutMock mock = requests.get(req.getEndpoint());
            if (mock != null) {
                return mock.respond(req);
            }
            else {
                throw new MultiRequestMockException('HTTP callout not supported for test methods');
            }
        }

        public void addRequestMock(String url, HttpCalloutMock mock) {
            requests.put(url, mock);
        }
    }

    public class MultiRequestMockException extends Exception {}

    public class SingleRequestMock implements HttpCalloutMock {

        protected Integer code;
        protected String status;
        protected String body;
        protected String reqBody;

        public SingleRequestMock(Integer code, String status, String body) {
            this.code = code;
            this.status = status;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody(this.body);
            res.setStatusCode(this.code);
            res.setStatus(this.status);
            this.reqBody = req.getBody();
            return res;
        }

        public String getBodyRequest() {
            return this.reqBody;
        }
    }

    @IsTest
    private static void testDMLErrorLogging() {
        Test.startTest();
        
        // 1. Test SaveResult - Invalid account without required Name field
        Account invalidAcc = new Account();
        Database.SaveResult[] srList = Database.insert(new List<Account>{invalidAcc}, false);
        System.assert(!srList[0].isSuccess(), 'Insert should fail');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, srList);
        
        // 2. Create a Contact with missing required field (LastName) to test field-specific errors
        Contact invalidContact = new Contact();
        // FirstName is optional, but LastName is required
        invalidContact.FirstName = 'Test';
        // Deliberately omit LastName to cause a field-specific error
        Database.SaveResult[] contactSrList = Database.insert(new List<Contact>{invalidContact}, false);
        System.assert(!contactSrList[0].isSuccess(), 'Contact insert should fail due to missing LastName');
        Triton.instance.dmlResult(TritonTypes.Area.Community, contactSrList);
        
        // 3. Test DeleteResult - Try to delete non-existent record
        Id fakeId = '001000000000000AAA';
        Database.DeleteResult[] drList = Database.delete(new List<Id>{fakeId}, false);
        System.assert(!drList[0].isSuccess(), 'Delete should fail');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, drList);
        
        // 4. Test UndeleteResult - Try to undelete non-existent record
        Database.UndeleteResult[] urList = Database.undelete(new List<Id>{fakeId}, false);
        System.assert(!urList[0].isSuccess(), 'Undelete should fail');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, urList);
        
        // 5. Test UpsertResult - Try to update non-existent record
        Account invalidUpsertAcc = new Account(Id = fakeId);
        Database.UpsertResult[] urList2 = Database.upsert(new List<Account>{invalidUpsertAcc}, false);
        System.assert(!urList2[0].isSuccess(), 'Upsert should fail');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, urList2);
        
        // 6. Test MergeResult - Try to merge with invalid record
        Account masterAcc = new Account(Name = 'Master');
        insert masterAcc;
        Database.MergeResult[] mergeList = Database.merge(masterAcc, new List<Id>{fakeId}, false);
        System.assert(!mergeList[0].isSuccess(), 'Merge should fail');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, mergeList);
        
        Test.stopTest();
        
        // Verify logs were created
        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Category__c, pharos__Type__c, pharos__Area__c, 
                   pharos__Summary__c, pharos__Details__c, Log_Level__c,
                   pharos__Apex_Name__c
            FROM pharos__Log__c
            WHERE pharos__Type__c = :TritonTypes.Type.DMLResult.name()
            ORDER BY CreatedDate
        ];
                
        System.assertEquals(6, logs.size(), 'Expected 6 DML error logs to be created (one for each DML operation)');
        
        Set<String> expectedOperations = new Set<String>{'Save', 'Delete', 'Undelete', 'Upsert', 'Merge'};
        Set<String> foundOperations = new Set<String>();
        
        // Find the Contact error log
        pharos__Log__c contactErrorLog = null;
        for(pharos__Log__c log : logs) {
            System.assertEquals(TritonTypes.Type.DMLResult.name(), log.pharos__Type__c);
            System.assertEquals(TritonTypes.Level.ERROR.name(), log.Log_Level__c);
            System.assert(log.pharos__Summary__c.contains('DML Operation'));
            
            // Store the operation type
            foundOperations.add(log.pharos__Apex_Name__c);
            
            // Find the Contact error log
            if(log.pharos__Area__c == TritonTypes.Area.Community.name()) {
                contactErrorLog = log;
            }
        }
        
        // Verify all expected operations are found
        System.assertEquals(expectedOperations, foundOperations);
        
        // Verify field-level error information is included in the Contact error log
        System.assertNotEquals(null, contactErrorLog, 'Contact error log should be created');
        System.assert(contactErrorLog.pharos__Details__c.contains('Fields:'), 
            'Contact error log should include field information');
        System.assert(contactErrorLog.pharos__Details__c.contains('LastName'), 
            'Contact error log should mention LastName field');
        System.assert(contactErrorLog.pharos__Details__c.contains('Status Code:'), 
            'Contact error log should include status code');
    }

    @IsTest
    private static void testDMLErrorLogging_NoErrors() {
        // Setup
        Account validAcc = new Account(Name = 'Test Account');
        insert validAcc;
        
        Test.startTest();
        
        // 1. Test SaveResult with valid data
        Account newAcc = new Account(Name = 'Valid Account');
        Database.SaveResult[] srList = Database.insert(new List<Account>{newAcc}, false);
        System.assert(srList[0].isSuccess(), 'Insert should succeed');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, srList);
        
        // 2. Test UpsertResult with valid data
        newAcc.Name = 'Updated Name';
        Database.UpsertResult[] upsertList = Database.upsert(new List<Account>{newAcc}, false);
        System.assert(upsertList[0].isSuccess(), 'Upsert should succeed');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, upsertList);
        
        // 3. Test DeleteResult with valid data
        Database.DeleteResult[] drList = Database.delete(new List<Id>{newAcc.Id}, false);
        System.assert(drList[0].isSuccess(), 'Delete should succeed');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, drList);
        
        // 4. Test UndeleteResult with valid data
        Database.UndeleteResult[] urList = Database.undelete(new List<Id>{newAcc.Id}, false);
        System.assert(urList[0].isSuccess(), 'Undelete should succeed');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, urList);
        
        Test.stopTest();
        
        // Verify no logs were created since operations were successful
        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Apex_Name__c, pharos__Summary__c, pharos__Details__c
            FROM pharos__Log__c 
            WHERE pharos__Type__c = :TritonTypes.Type.DMLResult.name()
        ];
                
        System.assertEquals(0, logs.size(), 'No logs should be created for successful DML operations');
    }

    @IsTest
    private static void test_triton_builder_negative() {
        TritonBuilder builder = new TritonBuilder();
        
        // Test invalid Id for relatedObject(String)
        builder.relatedObject('invalid-id');
        System.assertEquals(null, builder.build().pharos__Related_Objects__c);
        
        // Test invalid Ids in relatedObjects(Set<String>)
        Set<String> invalidIds = new Set<String>{'invalid-id-1', 'invalid-id-2'};
        builder.relatedObjects(invalidIds);
        System.assertEquals(null, builder.build().pharos__Related_Objects__c);
        
        // Test null and empty sets for relatedObjects
        builder.relatedObjects((Set<String>)null);
        System.assertEquals(null, builder.build().pharos__Related_Objects__c);
        
        builder.relatedObjects(new Set<String>());
        System.assertEquals(null, builder.build().pharos__Related_Objects__c);
        
        // Test mixed valid and invalid Ids
        Id validId = UserInfo.getUserId();
        Set<String> mixedIds = new Set<String>{validId, 'invalid-id'};
        builder.relatedObjects(mixedIds);
        System.assertEquals(JSON.serialize(new Set<Id>{validId}), builder.build().pharos__Related_Objects__c);
    }

    @IsTest
    private static void test_flush_top_buffer() {
        assertBefore();
        
        Test.startTest();
        
        // Add multiple logs to buffer without flushing
        Triton.instance.addError(
            TritonTypes.Type.Backend, 
            TritonTypes.Area.Community, 
            'first error', 
            'first details'
        );
        Triton.instance.addError(
            TritonTypes.Type.Backend, 
            TritonTypes.Area.Community, 
            'second error', 
            'second details'
        );
        Triton.instance.addError(
            TritonTypes.Type.Backend, 
            TritonTypes.Area.Community, 
            'third error', 
            'third details'
        );
        
        // Test flushTop with populated buffer
        Triton.instance.flushTop();
        Test.stopTest();
        
        // Verify only last log was persisted
        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Summary__c 
            FROM pharos__Log__c 
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(1, logs.size(), 'Only one log should be persisted');
        System.assertEquals('third error', logs[0].pharos__Summary__c, 'Last added log should be persisted');
        System.assertEquals(2, Triton.instance.logs.size(), 'Should have two logs remaining in buffer');
    }

    @IsTest
    private static void test_flush_top_immediate() {
        assertBefore();
        
        Test.startTest();
        Triton.instance.addError(
            TritonTypes.Type.Backend, 
            TritonTypes.Area.Community, 
            'first error', 
            'first details'
        );

        // Test immediate error method - should only flush that error
        Triton.instance.error(
            TritonTypes.Type.Backend, 
            TritonTypes.Area.Community, 
            'immediate error', 
            'immediate details'
        );
        Test.stopTest();
        
        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Summary__c 
            FROM pharos__Log__c 
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(1, logs.size(), 'Should have one log persisted');
        System.assertEquals('immediate error', logs[0].pharos__Summary__c, 'Immediate error should be persisted');
        System.assertEquals(1, Triton.instance.logs.size(), 'Should have one log remaining in buffer');
    }

    @IsTest
    private static void test_flush_top_empty_buffer() {
        assertBefore();
        
        Test.startTest();
        Triton.instance.flushTop();
        Test.stopTest();
        
        List<pharos__Log__c> logs = [SELECT Id FROM pharos__Log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created with empty buffer');
    }

    @IsTest
    private static void test_limit_info() {
        assertBefore();
        
        Test.startTest();
        
        // Create some limit usage
        for(Integer i = 0; i < 5; i++) {
            List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        }
        Account acc = new Account(Name = 'Test');
        insert acc;
        
        // Test via builder
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.Debug)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .summary('Testing limits')
            .details('Limit info test')
            .limitInfo();
        
        Triton.instance.log(builder);
        
        // Test via addLog
        Triton.instance.addLog(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Debug)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('Testing limits via addLog')
                .details('Limit info test via addLog')
                .limitInfo()
        );
        Triton.instance.flush();
        
        Test.stopTest();
        
        List<pharos__Log__c> logs = [
            SELECT Id, 
                   SOQL_Queries__c,
                   SOQL_Queries_Limit__c,
                   SOQL_Rows__c,
                   SOQL_Rows_Limit__c,
                   DML_Statements__c,
                   DML_Statements_Limit__c,
                   DML_Rows__c,
                   DML_Rows_Limit__c,
                   CPU_Time__c,
                   CPU_Time_Limit__c,
                   Heap_Size__c,
                   Heap_Size_Limit__c,
                   Callouts__c,
                   Callouts_Limit__c,
                   SOSL_Queries__c,
                   SOSL_Queries_Limit__c,
                   Future_Calls__c,
                   Future_Calls_Limit__c,
                   Queueable_Jobs__c,
                   Queueable_Jobs_Limit__c,
                   Email_Invocations__c,
                   Email_Invocations_Limit__c,
                   Push_Notifications__c,
                   Push_Notifications_Limit__c,
                   Batch_Jobs__c,
                   Batch_Jobs_Limit__c,
                   Publish_Immediate_DML__c,
                   Publish_Immediate_DML_Limit__c
            FROM pharos__Log__c 
            ORDER BY CreatedDate
        ];
        
        System.assertEquals(2, logs.size(), 'Should have created two logs');
        
        // Verify limits were captured for both logs
        for(pharos__Log__c log : logs) {
            // SOQL Queries
            System.assert(log.SOQL_Queries__c >= 5, 'Should have recorded SOQL queries');
            System.assertEquals(System.Limits.getLimitQueries(), log.SOQL_Queries_Limit__c, 'Should match SOQL queries limit');
            
            // DML Statements
            System.assert(log.DML_Statements__c >= 1, 'Should have recorded DML statements');
            System.assertEquals(System.Limits.getLimitDMLStatements(), log.DML_Statements_Limit__c, 'Should match DML statements limit');
            
            // DML Rows
            System.assert(log.DML_Rows__c >= 1, 'Should have recorded DML rows');
            System.assertEquals(System.Limits.getLimitDMLRows(), log.DML_Rows_Limit__c, 'Should match DML rows limit');
            
            // CPU Time and Heap Size
            System.assert(log.CPU_Time__c > 0, 'Should have recorded CPU time');
            System.assertEquals(System.Limits.getLimitCpuTime(), log.CPU_Time_Limit__c, 'Should match CPU time limit');
            System.assert(log.Heap_Size__c > 0, 'Should have recorded heap size');
            System.assertEquals(System.Limits.getLimitHeapSize(), log.Heap_Size_Limit__c, 'Should match heap size limit');
            
            // Unused limits - verify both usage and limits
            System.assertEquals(0, log.Callouts__c, 'Should have recorded zero callouts');
            System.assertEquals(System.Limits.getLimitCallouts(), log.Callouts_Limit__c, 'Should match callouts limit');
            
            System.assertEquals(0, log.SOSL_Queries__c, 'Should have recorded zero SOSL queries');
            System.assertEquals(System.Limits.getLimitSoslQueries(), log.SOSL_Queries_Limit__c, 'Should match SOSL queries limit');
            
            System.assertEquals(0, log.Future_Calls__c, 'Should have recorded zero future calls');
            System.assertEquals(System.Limits.getLimitFutureCalls(), log.Future_Calls_Limit__c, 'Should match future calls limit');
            
            System.assertEquals(0, log.Queueable_Jobs__c, 'Should have recorded zero queueable jobs');
            System.assertEquals(System.Limits.getLimitQueueableJobs(), log.Queueable_Jobs_Limit__c, 'Should match queueable jobs limit');
            
            System.assertEquals(0, log.Email_Invocations__c, 'Should have recorded zero email invocations');
            System.assertEquals(System.Limits.getLimitEmailInvocations(), log.Email_Invocations_Limit__c, 'Should match email invocations limit');
            
            System.assertEquals(0, log.Push_Notifications__c, 'Should have recorded zero push notifications');
            System.assertEquals(System.Limits.getLimitMobilePushApexCalls(), log.Push_Notifications_Limit__c, 'Should match push notifications limit');
            
            System.assertEquals(0, log.Batch_Jobs__c, 'Should have recorded zero batch jobs');
            System.assertEquals(System.Limits.getLimitAsyncCalls(), log.Batch_Jobs_Limit__c, 'Should match batch jobs limit');
            
            System.assertEquals(0, log.Publish_Immediate_DML__c, 'Should have recorded zero publish immediate DML');
            System.assertEquals(System.Limits.getLimitPublishImmediateDML(), log.Publish_Immediate_DML_Limit__c, 'Should match publish immediate DML limit');
        }
    }

    @IsTest
    private static void test_get_current_stack_trace() {
        // Test with mock stack trace containing Triton entries
        String mockStackTraceWithTriton = 
            'Class.TritonHelper.someMethod: line 5, column 1\n' +
            'Class.TestClass.testMethod: line 10, column 1\n' +
            'Class.TritonBuilder.build: line 15, column 1\n' +
            'Class.AnotherClass.anotherMethod: line 20, column 1';
        
        String filteredStackTrace = TritonHelper.filterStackTrace(mockStackTraceWithTriton);
        System.assert(!filteredStackTrace.contains('Triton'), 'Filtered stack trace should not contain Triton entries');
        System.assert(filteredStackTrace.contains('TestClass.testMethod'), 'Should preserve non-Triton entries');
        System.assert(filteredStackTrace.contains('AnotherClass.anotherMethod'), 'Should preserve non-Triton entries');

        // Test with mock stack trace containing no Triton entries
        String mockStackTraceNoTriton = 
            'Class.TestClass.testMethod: line 10, column 1\n' +
            'Class.AnotherClass.anotherMethod: line 20, column 1\n' +
            'Class.ThirdClass.thirdMethod: line 30, column 1';
        
        String unchangedStackTrace = TritonHelper.filterStackTrace(mockStackTraceNoTriton);
        System.assertEquals(mockStackTraceNoTriton, unchangedStackTrace, 'Stack trace without Triton entries should remain unchanged');
    }

    @IsTest
    private static void test_cache_functionality() {
        Test.startTest();
        
        // Test withCache when cache is available
        Cache.Org.put('test', 'test'); // This will make CACHE_AVAILABLE true
        Triton instance = Triton.instance.withCache();
        System.assert(instance.withCache, 'Cache should be enabled');
        
        // Start a transaction and verify it's cached
        String transactionId = instance.startTransaction();
        System.assertNotEquals(null, transactionId, 'Transaction ID should be generated');
        System.assertEquals(transactionId, TritonHelper.getCachedTransactionId(), 'Transaction ID should be cached');
        
        // Resume transaction and verify cache is updated
        String newTransactionId = 'test-transaction-id';
        instance.resumeTransaction(newTransactionId);
        System.assertEquals(newTransactionId, TritonHelper.getCachedTransactionId(), 'New transaction ID should be cached');
        
        // Stop transaction and verify cache is cleared
        instance.stopTransaction();
        System.assertEquals(null, TritonHelper.getCachedTransactionId(), 'Cache should be cleared after stopping transaction');
        
        Test.stopTest();
    }

    @IsTest
    private static void test_cache_functionality_negative() {
        Test.startTest();
        
        // Force cache to be unavailable by simulating a Platform Cache exception
        Cache.Org.remove('test'); // Clear any existing cache entries
        
        // Create instance with cache disabled
        Triton instance = Triton.instance;
        instance.withCache = false; // Explicitly disable cache
        
        // Verify transaction management still works without cache
        String transactionId = instance.startTransaction();
        System.assertNotEquals(null, transactionId, 'Transaction ID should be generated even without cache');
        System.assertEquals(null, TritonHelper.getCachedTransactionId(), 'Transaction should not be cached when cache is disabled');
        
        Test.stopTest();
    }

    @IsTest
    private static void test_get_operation_from_stack_trace() {
        // Test various stack trace formats
        String stackTrace1 = 'Class.TestClass.testMethod: line 10, column 1\n' +
                            'Class.AnotherClass.anotherMethod: line 20, column 1';
        String operation1 = TritonHelper.getOperation(stackTrace1);
        System.assertEquals('Class.TestClass.testMethod', operation1, 'Should extract first operation from stack trace');
        
        String stackTrace2 = 'Class.TritonHelper.someMethod: line 5, column 1\n' +
                            'Class.TestClass.testMethod: line 10, column 1';
        String operation2 = TritonHelper.getOperation(stackTrace2);
        System.assertEquals('Class.TestClass.testMethod', operation2, 'Should skip Triton entries');
        
        // Test edge cases
        System.assertEquals('', TritonHelper.getOperation(''), 'Should handle empty stack trace');
        System.assertEquals('', TritonHelper.getOperation('Invalid stack trace'), 'Should handle invalid stack trace');
        System.assertEquals('', TritonHelper.getOperation(null), 'Should handle null stack trace');
    }

    @IsTest
    private static void test_log_buffering() {
        Test.startTest();
        
        // Add multiple logs to buffer using direct builder
        for(Integer i = 0; i < 3; i++) {
            Triton.instance.addLog(
                Triton.makeBuilder()
                    .category(TritonTypes.Category.Apex)
                    .type(TritonTypes.Type.Backend)
                    .area(TritonTypes.Area.Community)
                    .summary('Error ' + i)
                    .details('Details ' + i)
                    .level(TritonTypes.Level.ERROR)
            );
        }
        
        // Verify logs are in buffer but not persisted
        System.assertEquals(3, Triton.instance.logs.size(), 'Should have 3 logs in buffer');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c], 'No logs should be persisted yet');
        
        // Test flush - should persist all logs
        Triton.instance.flush();
        
        // Wait for async operations to complete
        Test.stopTest();
        
        List<pharos__Log__c> persistedLogs = [
            SELECT pharos__Summary__c 
            FROM pharos__Log__c 
            ORDER BY CreatedDate
        ];
        System.assertEquals(3, persistedLogs.size(), 'All logs should be persisted');
        
        // Verify log summaries
        Set<String> expectedSummaries = new Set<String>{'Error 0', 'Error 1', 'Error 2'};
        Set<String> actualSummaries = new Set<String>();
        for(pharos__Log__c log : persistedLogs) {
            actualSummaries.add(log.pharos__Summary__c);
        }
        System.assertEquals(expectedSummaries, actualSummaries, 'All expected logs should be persisted');
    }

    @IsTest
    private static void test_log_buffering_with_template() {
        Test.startTest();
        
        // Set up a template
        TritonBuilder template = Triton.makeBuilder()
            .category(TritonTypes.Category.Debug)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community);
        Triton.instance.setTemplate(template);
        
        // Add logs using template
        for(Integer i = 0; i < 3; i++) {
            Triton.instance.addLog(
                Triton.instance.fromTemplate()
                    .summary('Log ' + i)
                    .details('Template test ' + i)
            );
        }
        
        // Verify template properties are applied
        for(pharos__Log__c log : Triton.instance.logs) {
            System.assertEquals(TritonTypes.Category.Debug.name(), log.pharos__Category__c, 
                'Template category should be applied');
            System.assertEquals(TritonTypes.Type.Backend.name(), log.pharos__Type__c, 
                'Template type should be applied');
            System.assertEquals(TritonTypes.Area.Community.name(), log.pharos__Area__c, 
                'Template area should be applied');
        }
        
        Test.stopTest();
    }

    @IsTest
    private static void test_cache_error_handling() {
        Test.startTest();
        
        Triton.CACHE_AVAILABLE = false;
        
        // Test withCache() when cache is unavailable
        Triton.instance.withCache();
        System.assertEquals(false, Triton.CACHE_AVAILABLE, 'Cache should remain disabled');
        System.assertNotEquals(null, Triton.instance.TRANSACTION_ID, 'Transaction ID should be generated');
        
        Test.stopTest();
    }

    @IsTest
    private static void test_warning_and_debug_with_related_objects() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        Set<Id> relatedIds = new Set<Id>{testAccount.Id};
        
        Test.startTest();
        
        // Test warning with related objects
        Triton.instance.warning(
            TritonTypes.Type.Backend,
            TritonTypes.Area.Community,
            'Test Warning',
            'Warning details'
        );
        
        // Test debug with duration and related objects
        Triton.instance.debug(
            TritonTypes.Type.Backend,
            TritonTypes.Area.Community,
            'Test Debug',
            'Debug details',
            100 // duration in ms
        );
        
        // Add debug with related objects
        Triton.instance.addDebug(
            TritonTypes.Type.Backend,
            TritonTypes.Area.Community,
            'Test Debug with Related',
            'Debug details with related records',
            200 // duration
        );
        
        Test.stopTest();
        
        List<pharos__Log__c> logs = [
            SELECT Id, 
                   pharos__Category__c,
                   Log_Level__c,
                   pharos__Duration__c,
                   pharos__Summary__c
            FROM pharos__Log__c 
            ORDER BY CreatedDate
        ];
        
        System.assertEquals(2, logs.size(), 'Should have created warning and debug logs');
        
        // Verify warning log
        System.assertEquals(TritonTypes.Category.Warning.name(), logs[0].pharos__Category__c);
        System.assertEquals(TritonTypes.Level.WARNING.name(), logs[0].Log_Level__c);
        
        // Verify debug log with duration
        System.assertEquals(TritonTypes.Category.Debug.name(), logs[1].pharos__Category__c);
        System.assertEquals(100, logs[1].pharos__Duration__c);
    }

    @IsTest
    private static void test_event_and_integration_error_variations() {
        Test.startTest();
        
        // Test event with related objects
        Triton.instance.event(
            TritonTypes.Level.INFO,
            TritonTypes.Type.Backend,
            TritonTypes.Area.Community,
            'Test Event',
            'Event details'
        );
        
        // Test integration error with different request/response combinations
        RestRequest restReq = new RestRequest();
        RestResponse restRes = new RestResponse();
        restReq.requestURI = '/services/apexrest/Account';
        restReq.httpMethod = 'GET';
        
        // Test with RestRequest/Response
        try {
            throw new CalloutException('Test exception');
        } catch(Exception e) {
            Triton.instance.integrationError(
                TritonTypes.Area.Community,
                e,
                restReq,
                restRes
            );
        }
        
        // Test with HttpRequest/Response
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint('https://example.com');
        httpReq.setMethod('GET');
        HttpResponse httpRes = new HttpResponse();
        httpRes.setStatusCode(500);
        httpRes.setStatus('Internal Server Error');
        
        Triton.instance.integrationError(
            TritonTypes.Type.Backend,
            TritonTypes.Area.Community,
            'HTTP Error',
            'Error details',
            httpReq,
            httpRes
        );
        
        Test.stopTest();
        
        List<pharos__Log__c> logs = [
            SELECT Id, 
                   pharos__Category__c,
                   pharos__Type__c,
                   pharos__Stacktrace_Parse_Result__c
            FROM pharos__Log__c 
            ORDER BY CreatedDate
        ];
        
        System.assertEquals(3, logs.size(), 'Should have created event and integration error logs');
        
        // Verify integration logs have parsed request/response data
        for(pharos__Log__c log : logs) {
            if(log.pharos__Category__c == TritonTypes.Category.Integration.name()) {
                System.assertNotEquals(null, log.pharos__Stacktrace_Parse_Result__c, 
                    'Integration log should have parsed request/response data');
            }
        }
    }

    @IsTest
    private static void test_add_error_with_exception() {
        assertBefore();
        
        Test.startTest();
        String msg;
        // Test addError with just area and exception
        try {
            // Force an exception
            Integer i = 1/0;
        } catch(Exception e) {
            msg = e.getMessage();
            Triton.instance.addError(TritonTypes.Area.Community, e);
        }
        
        // Verify log is in buffer but not persisted yet
        System.assertEquals(1, Triton.instance.logs.size(), 'Should have one log in buffer');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c], 'No logs should be persisted yet');
        
        // Flush and verify log
        Triton.instance.flush();
        
        Test.stopTest();
        
        List<pharos__Log__c> logs = [
            SELECT Id, 
                   pharos__Category__c,
                   pharos__Type__c,
                   pharos__Area__c,
                   pharos__Summary__c,
                   pharos__Details__c,
                   pharos__Stacktrace__c,
                   Log_Level__c
            FROM pharos__Log__c
        ];
        
        System.assertEquals(1, logs.size(), 'Should have created one log');
        pharos__Log__c log = logs[0];
        
        // Verify log properties
        System.assertEquals(TritonTypes.Category.Apex.name(), log.pharos__Category__c);
        System.assertEquals(TritonTypes.Area.Community.name(), log.pharos__Area__c);
        System.assertEquals(TritonTypes.Level.ERROR.name(), log.Log_Level__c);
        System.assert(log.pharos__Summary__c.contains(msg), 'Summary should contain exception message');
        System.assertNotEquals(null, log.pharos__Stacktrace__c, 'Stack trace should be captured');
    }

    @IsTest
    private static void test_add_event() {
        assertBefore();
        
        Test.startTest();
        
        // Test addEvent with default INFO level
        Triton.instance.addEvent(
            TritonTypes.Type.Backend,
            TritonTypes.Area.Community,
            'Test Event Summary',
            'Test Event Details'
        );
        
        // Verify log is in buffer but not persisted yet
        System.assertEquals(1, Triton.instance.logs.size(), 'Should have one log in buffer');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c], 'No logs should be persisted yet');
        
        // Flush and verify log
        Triton.instance.flush();
        
        Test.stopTest();
        
        List<pharos__Log__c> logs = [
            SELECT Id, 
                   pharos__Category__c,
                   pharos__Type__c,
                   pharos__Area__c,
                   pharos__Summary__c,
                   pharos__Details__c,
                   Log_Level__c,
                   pharos__Stacktrace__c
            FROM pharos__Log__c
        ];
        
        System.assertEquals(1, logs.size(), 'Should have created one log');
        pharos__Log__c log = logs[0];
        
        // Verify log properties
        System.assertEquals(TritonTypes.Category.Event.name(), log.pharos__Category__c);
        System.assertEquals(TritonTypes.Type.Backend.name(), log.pharos__Type__c);
        System.assertEquals(TritonTypes.Area.Community.name(), log.pharos__Area__c);
        System.assertEquals(TritonTypes.Level.INFO.name(), log.Log_Level__c);
        System.assertEquals('Test Event Summary', log.pharos__Summary__c);
        System.assertEquals('Test Event Details', log.pharos__Details__c);
        System.assertNotEquals(null, log.pharos__Stacktrace__c, 'Stack trace should be captured');
    }

    @IsTest
    private static void test_post_processing_controls_builder() {
        Test.startTest();
        
        // Test individual settings
        TritonHelper.PostProcessingControlsBuilder builder = new TritonHelper.PostProcessingControlsBuilder();
        String jsonString = builder
            .auditTrail(true)
            .deployResult(true)
            .installedPackages(true)
            .area(true)
            .pendingJobs(true)
            .relatedObjects(true)
            .stackTrace(true)
            .totalActiveSession(true)
            .userInfo(true)
            .build();
        
        // Verify JSON structure
        Map<String, Object> controls = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
        System.assertEquals(true, controls.get('auditTrail'), 'Audit trail should be enabled');
        System.assertEquals(true, controls.get('deployResult'), 'Deploy result should be enabled');
        System.assertEquals(true, controls.get('installedPackages'), 'Installed packages should be enabled');
        System.assertEquals(true, controls.get('objectInfo'), 'Object info should be enabled');
        System.assertEquals(true, controls.get('pendingJobs'), 'Pending jobs should be enabled');
        System.assertEquals(true, controls.get('relatedObjects'), 'Related objects should be enabled');
        System.assertEquals(true, controls.get('stackTrace'), 'Stack trace should be enabled');
        System.assertEquals(true, controls.get('totalActiveSession'), 'Total active session should be enabled');
        System.assertEquals(true, controls.get('userInfo'), 'User info should be enabled');
        
        // Test setAll method
        builder = new TritonHelper.PostProcessingControlsBuilder();
        jsonString = builder.setAll(true).build();
        controls = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
        
        // Verify all settings are enabled
        for(String key : controls.keySet()) {
            System.assertEquals(true, controls.get(key), 'All controls should be enabled: ' + key);
        }
        
        // Test mixed settings
        builder = new TritonHelper.PostProcessingControlsBuilder();
        jsonString = builder
            .setAll(false)
            .auditTrail(true)
            .stackTrace(true)
            .build();
        controls = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
        
        // Verify mixed settings
        System.assertEquals(true, controls.get('auditTrail'), 'Audit trail should be enabled');
        System.assertEquals(true, controls.get('stackTrace'), 'Stack trace should be enabled');
        System.assertEquals(false, controls.get('userInfo'), 'User info should be disabled');
        System.assertEquals(false, controls.get('pendingJobs'), 'Pending jobs should be disabled');
        
        Test.stopTest();
    }

    /**
     * Test the addDebug method
     */
    @IsTest
    static void testAddDebug() {
        // Set up test data
        Triton triton = Triton.instance;
        
        // Add a debug log
        Test.startTest();
        triton.addDebug(TritonTypes.Type.Backend, TritonTypes.Area.Accounts, 'Test Summary', 'Test Details');
        Test.stopTest();
        
        // Verify log was added to the buffer
        System.assertEquals(1, triton.logs.size(), 'One log should be in the buffer');
        
        // Verify log properties
        pharos__Log__c log = triton.logs[0];
        System.assertEquals('Test Summary', log.pharos__Summary__c, 'Summary should match');
        System.assertEquals('Test Details', log.pharos__Details__c, 'Details should match');
        System.assertEquals('Backend', log.pharos__Type__c, 'Type should match');
        System.assertEquals('Accounts', log.pharos__Area__c, 'Area should match');
        System.assertEquals('DEBUG', log.Log_Level__c, 'Level should be DEBUG');
    }

    /**
    * Test the formatDMLError method with various input combinations
    */
    @IsTest
    private static void test_formatDMLError() {
        Test.startTest();
        
        // Create a mock Database.Error using TestVisible method
        Triton testInstance = Triton.instance;
        
        // 1. Test with field errors and record ID
        Id testId = UserInfo.getUserId();
        Database.Error mockError = createMockDatabaseError(
            'Required fields are missing: [LastName]', 
            System.StatusCode.REQUIRED_FIELD_MISSING,
            new List<String>{'LastName'}
        );
        
        String formattedError = TritonHelper.formatDMLError(mockError, testId);
        System.debug('Formatted error: ' + formattedError);
        
        // Verify all components are present
        System.assert(formattedError.contains('Required fields are missing'), 'Error message should be included');
        System.assert(formattedError.contains('Status Code: ' + System.StatusCode.REQUIRED_FIELD_MISSING), 'Status code should be included');
        System.assert(formattedError.contains('Fields: LastName'), 'Field name should be included');
        System.assert(formattedError.contains('on record: ' + testId), 'Record ID should be included');
        
        // 2. Test with null record ID
        String formattedErrorNoId = TritonHelper.formatDMLError(mockError, null);
        System.assert(!formattedErrorNoId.contains('on record:'), 'Record ID section should be omitted when ID is null');
        System.assert(formattedErrorNoId.contains('Fields: LastName'), 'Field name should still be included');
        
        // 3. Test with no fields
        Database.Error mockErrorNoFields = createMockDatabaseError(
            'Record not found', 
            System.StatusCode.INVALID_ID_FIELD,
            null
        );
        
        String formattedErrorNoFields = TritonHelper.formatDMLError(mockErrorNoFields, testId);
        System.assert(!formattedErrorNoFields.contains('Fields:'), 'Fields section should be omitted when no fields are specified');
        System.assert(formattedErrorNoFields.contains('Record not found'), 'Error message should still be included');
        
        Test.stopTest();
    }
    
    /**
    * Create a mock Database.Error for testing
    */
    private static Database.Error createMockDatabaseError(String message, System.StatusCode statusCode, List<String> fields) {
        return (Database.Error)JSON.deserialize(
            JSON.serialize(new MockDatabaseError(message, statusCode, fields)), 
            Database.Error.class
        );
    }
    
    /**
    * Mock class to create Database.Error instances
    */
    private class MockDatabaseError {
        private String message;
        private System.StatusCode statusCode;
        private List<String> fields;
        
        public MockDatabaseError(String message, System.StatusCode statusCode, List<String> fields) {
            this.message = message;
            this.statusCode = statusCode;
            this.fields = fields;
        }
        
        public String getMessage() {
            return message;
        }
        
        public System.StatusCode getStatusCode() {
            return statusCode;
        }
        
        public List<String> getFields() {
            return fields;
        }
    }

    /**
    * Test the field error handling in DML error logging
    */
    @IsTest
    private static void test_field_error_format() {
        Test.startTest();
        
        // Create a Contact with missing required fields to generate a real field error
        Contact invalidContact = new Contact();
        // FirstName is optional, but LastName is required (omitted to cause field error)
        Database.SaveResult[] srList = Database.insert(new List<Contact>{invalidContact}, false);
        
        // Verify we got a field error
        System.assert(!srList[0].isSuccess(), 'Insert should fail');
        Database.Error err = srList[0].getErrors()[0];
        System.assert(err.getFields().contains('LastName'), 'Error should reference LastName field');
        
        // Log the error - captures error via formatDMLError method
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, srList);
        Test.stopTest();
        // Retrieve the log to verify error formatting
        pharos__Log__c log = [
            SELECT pharos__Details__c
            FROM pharos__Log__c
            WHERE pharos__Area__c = :TritonTypes.Area.Accounts.name()
            LIMIT 1
        ];
        
        // Verify details contain field information
        System.assertNotEquals(null, log, 'A log should be created');
        System.assert(log.pharos__Details__c.contains('Fields: LastName'), 
            'Log details should include the field name');
        System.assert(log.pharos__Details__c.contains('Status Code:'), 
            'Log details should include status code');
        
    }
    
    /**
    * Test error handling with various types of errors
    */
    @IsTest
    private static void test_different_error_types() {
        Test.startTest();
        
        // Generate different DML error types
        
        // 1. Error with no specific fields (entity locking error)
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Create a locking error by attempting concurrent updates
        // This requires some creativity in a test context
        try {
            // Set up conflicting operations
            // First operation - establish update
            acc.Name = 'Updated Name 1';
            
            // Second operation (simulated concurrent) - would cause lock error in real scenario
            Account sameAcc = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];
            sameAcc.Name = 'Updated Name 2';
            update sameAcc;
            
            // Try updating original record to cause error
            update acc;
        } catch (Exception e) {
            // Create a log from the exception
            Triton.instance.error(TritonTypes.Area.Accounts, e);
        }
        
        // 2. Record not found error
        Id fakeId = '001000000000000AAA';
        Database.DeleteResult[] drList = Database.delete(new List<Id>{fakeId}, false);
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, drList);
        Test.stopTest();
        
        // Verify logs capture different error types appropriately
        List<pharos__Log__c> logs = [
            SELECT pharos__Details__c, pharos__Type__c, pharos__Summary__c, pharos__Apex_Name__c
            FROM pharos__Log__c
            ORDER BY CreatedDate DESC
        ];
        
        System.assert(logs.size() > 0, 'Logs should be created');
        
        // Find the delete error log
        pharos__Log__c deleteErrorLog = null;
        for (pharos__Log__c log : logs) {
            if (log.pharos__Type__c == TritonTypes.Type.DMLResult.name() && 
                log.pharos__Apex_Name__c == 'Delete') {
                deleteErrorLog = log;
                break;
            }
        }
        
        System.assertNotEquals(null, deleteErrorLog, 'Delete error log should be created');
        
    }

    @IsTest
    private static void test_template_runtime_properties_reset() {
        Test.startTest();
        
        // Set up a template with timestamp, duration, and other runtime properties
        Double templateTimestamp = 123456789.0; // A fixed timestamp
        
        TritonBuilder template = Triton.makeBuilder()
            .category(TritonTypes.Category.Debug)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .createdTimestamp(templateTimestamp)
            .attribute(TritonBuilder.CPU_TIME, 1000)
            .attribute(TritonBuilder.HEAP_SIZE, 2000);
            
        Triton.instance.setTemplate(template);
        
        // Start a transaction
        String transactionId = Triton.instance.startTransaction();
        
        // Create a log from the template
        Triton.instance.log(
            Triton.instance.fromTemplate()
                .summary('Runtime properties test')
                .details('Testing runtime properties are reset')
        );
        
        Test.stopTest();
        
        // Get the log and verify its runtime properties
        pharos__Log__c log = [
            SELECT pharos__Created_Timestamp__c, CPU_Time__c, Heap_Size__c
            FROM pharos__Log__c
            LIMIT 1
        ];
        
        // Verify the template's runtime properties are NOT used
        System.assertNotEquals(templateTimestamp, log.pharos__Created_Timestamp__c,
            'Template timestamp should not be copied to logs created with fromTemplate()');
                    
        System.assertNotEquals(1000, log.CPU_Time__c,
            'Template CPU time should not be copied to logs created with fromTemplate()');
            
        System.assertNotEquals(2000, log.Heap_Size__c,
            'Template heap size should not be copied to logs created with fromTemplate()');
    }

    /**
     * Helper method to verify batch jobs based on expected count
     * @param expectedCount The expected number of batch jobs
     * @param assertMessage The message to display if the assertion fails
     */
    private static void assertBatchJobs(Integer expectedCount, String assertMessage) {
        System.assertEquals(expectedCount, [
            SELECT COUNT() 
            FROM AsyncApexJob 
            WHERE ApexClass.Name = 'TritonDelayedPublishBatch'
            AND Status IN ('Queued', 'Processing', 'Completed')
        ], assertMessage);
    }

}