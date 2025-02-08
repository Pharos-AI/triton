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
        componentLog.summary = 'test summary';
        componentLog.details = 'test details';
        componentLog.recordId = 'recordId';
        componentLog.objectApiName = 'objectApiName';
        TritonLwc.Component component = new TritonLwc.Component();
        component.category = 'test category';
        component.name = 'test name';
        component.function = 'test function';
        componentLog.component = component;
        componentLogs.add(componentLog);
        TritonLwc.saveComponentLogs(componentLogs);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    @IsTest
    private static void test_save_component_log_negative() {
        assertBefore();

        Test.startTest();
        List<TritonLwc.ComponentLog> componentLogs = new List<TritonLwc.ComponentLog>();
        TritonLwc.ComponentLog componentLog = new TritonLwc.ComponentLog();
        
        // Set invalid values to trigger error handling
        componentLog.userId = 'invalid-user-id';
        componentLog.recordId = 'invalid-record-id';
        componentLog.category = 'InvalidCategory';
        componentLog.area = 'InvalidArea';
        componentLog.level = 'InvalidLevel';
        componentLog.details = 'Initial details';
        componentLog.summary = 'Test summary';
        
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
        componentLog.component = component;
        
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
        
        // Verify error messages in details
        String details = log.pharos__Details__c;
        System.assert(details.contains('Invalid User Id'), 'Should contain user ID error message');
        System.assert(details.contains('Invalid Record Id'), 'Should contain record ID error message');
        System.assert(details.contains('Invalid Log Category'), 'Should contain category error message');
        System.assert(details.contains('Invalid Log Functional Area'), 'Should contain area error message');
        System.assert(details.contains('Invalid Log Level'), 'Should contain level error message');
        
        // Verify null values for invalid IDs
        System.assertEquals(UserInfo.getUserId(), log.pharos__User_Id__c, 'User ID should be current user for invalid');
        System.assertEquals(null, log.pharos__Related_Objects__c, 'Related objects should be null for invalid input');
    }

    @IsTest
    private static void test_flow() {
        assertBefore();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = TritonTypes.Category.Flow.name();
        flowLog.type = 'type';
        flowLog.area = 'area';
        flowLog.summary = 'test';
        flowLog.details = 'test';
        flowLog.additionalFields = '{"pharos__Summary__c":"test summary","pharos__Details__c":"test Details"}';
        flowLogs.add(flowLog);
        TritonFlow.log(flowLogs);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    @IsTest
    private static void test_flow_negative() {
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
        
        // 2. Test DeleteResult - Try to delete non-existent record
        Id fakeId = '001000000000000AAA';
        Database.DeleteResult[] drList = Database.delete(new List<Id>{fakeId}, false);
        System.assert(!drList[0].isSuccess(), 'Delete should fail');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, drList);
        
        // 3. Test UndeleteResult - Try to undelete non-existent record
        Database.UndeleteResult[] urList = Database.undelete(new List<Id>{fakeId}, false);
        System.assert(!urList[0].isSuccess(), 'Undelete should fail');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, urList);
        
        // 4. Test UpsertResult - Try to update non-existent record
        Account invalidUpsertAcc = new Account(Id = fakeId);
        Database.UpsertResult[] urList2 = Database.upsert(new List<Account>{invalidUpsertAcc}, false);
        System.assert(!urList2[0].isSuccess(), 'Upsert should fail');
        Triton.instance.dmlResult(TritonTypes.Area.Accounts, urList2);
        
        // 5. Test MergeResult - Try to merge with invalid record
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
        
        // Debug information
        System.debug('Number of logs found: ' + logs.size());
        for(pharos__Log__c log : logs) {
            System.debug('Log operation: ' + log.pharos__Apex_Name__c);
        }
        
        System.assertEquals(5, logs.size(), 'Expected 5 DML error logs to be created (one for each DML type)');
        
        Set<String> expectedOperations = new Set<String>{'Save', 'Delete', 'Undelete', 'Upsert', 'Merge'};
        Set<String> foundOperations = new Set<String>();
        
        for(pharos__Log__c log : logs) {
            System.assertEquals(TritonTypes.Category.Apex.name(), log.pharos__Category__c);
            System.assertEquals(TritonTypes.Area.Accounts.name(), log.pharos__Area__c);
            System.assertEquals(TritonTypes.Level.ERROR.name(), log.Log_Level__c);
            System.assertEquals(TritonTypes.Type.DMLResult.name(), log.pharos__Type__c);
            System.assert(log.pharos__Summary__c.contains('DML Operation'));
            foundOperations.add(log.pharos__Apex_Name__c);
        }
        
        System.assertEquals(expectedOperations, foundOperations);
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
        
        // Debug info
        for(pharos__Log__c log : logs) {
            System.debug('Found unexpected error log:');
            System.debug('Operation: ' + log.pharos__Apex_Name__c);
            System.debug('Summary: ' + log.pharos__Summary__c);
            System.debug('Details: ' + log.pharos__Details__c);
        }
        
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
}
