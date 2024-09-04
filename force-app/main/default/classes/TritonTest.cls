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
    private static void test_flow() {
        assertBefore();

        Test.startTest();
        List<TritonFlow.FlowLog> flowLogs = new List<TritonFlow.FlowLog>();
        TritonFlow.FlowLog flowLog = new TritonFlow.FlowLog();
        flowLog.category = 'test category';
        flowLog.type = 'test type';
        flowLog.area = 'test area';
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

}