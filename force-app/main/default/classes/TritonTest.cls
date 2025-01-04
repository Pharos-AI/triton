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
    private static void test_flow_error() {
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

        List<pharos__Log__c> logs = [SELECT Id, pharos__Details__c, pharos__Summary__c, pharos__Hash__c FROM pharos__Log__c];
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
        Triton.instance.dmlError(TritonTypes.Area.Accounts, srList);
        
        // 2. Test DeleteResult - Try to delete non-existent record
        Id fakeId = '001000000000000AAA';
        Database.DeleteResult[] drList = Database.delete(new List<Id>{fakeId}, false);
        System.assert(!drList[0].isSuccess(), 'Delete should fail');
        Triton.instance.dmlError(TritonTypes.Area.Accounts, drList);
        
        // 3. Test UndeleteResult - Try to undelete non-existent record
        Database.UndeleteResult[] urList = Database.undelete(new List<Id>{fakeId}, false);
        System.assert(!urList[0].isSuccess(), 'Undelete should fail');
        Triton.instance.dmlError(TritonTypes.Area.Accounts, urList);
        
        // 4. Test UpsertResult - Try to update non-existent record
        Account invalidUpsertAcc = new Account(Id = fakeId);
        Database.UpsertResult[] urList2 = Database.upsert(new List<Account>{invalidUpsertAcc}, false);
        System.assert(!urList2[0].isSuccess(), 'Upsert should fail');
        Triton.instance.dmlError(TritonTypes.Area.Accounts, urList2);
        
        // 5. Test MergeResult - Try to merge with invalid record
        Account masterAcc = new Account(Name = 'Master');
        insert masterAcc;
        Database.MergeResult[] mergeList = Database.merge(masterAcc, new List<Id>{fakeId}, false);
        System.assert(!mergeList[0].isSuccess(), 'Merge should fail');
        Triton.instance.dmlError(TritonTypes.Area.Accounts, mergeList);
        
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
        Triton.instance.dmlError(TritonTypes.Area.Accounts, srList);
        
        // 2. Test UpsertResult with valid data
        newAcc.Name = 'Updated Name';
        Database.UpsertResult[] upsertList = Database.upsert(new List<Account>{newAcc}, false);
        System.assert(upsertList[0].isSuccess(), 'Upsert should succeed');
        Triton.instance.dmlError(TritonTypes.Area.Accounts, upsertList);
        
        // 3. Test DeleteResult with valid data
        Database.DeleteResult[] drList = Database.delete(new List<Id>{newAcc.Id}, false);
        System.assert(drList[0].isSuccess(), 'Delete should succeed');
        Triton.instance.dmlError(TritonTypes.Area.Accounts, drList);
        
        // 4. Test UndeleteResult with valid data
        Database.UndeleteResult[] urList = Database.undelete(new List<Id>{newAcc.Id}, false);
        System.assert(urList[0].isSuccess(), 'Undelete should succeed');
        Triton.instance.dmlError(TritonTypes.Area.Accounts, urList);
        
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
}
