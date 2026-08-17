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

    private static void assertCreatedIntegrationLog() {
        List<pharos__Log__c> logs = [SELECT Id, pharos__Category__c, pharos__Hash__c, pharos__Summary__c FROM pharos__Log__c ORDER BY CreatedDate];
        System.assertEquals(2, logs.size(), 'Expected exactly 2 logs, found: ' + logs.size());
        for(Integer i = 0; i < logs.size(); i++) {
            System.assertEquals(TritonTypes.Category.Integration.name(), logs.get(i).pharos__Category__c,
                'Log ' + i + ' (' + logs.get(i).pharos__Summary__c + ') should be Integration category, but was: ' + logs.get(i).pharos__Category__c);
        }
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
        System.assertNotEquals(null, logs.get(1).pharos__Hash__c);
    }

    @TestSetup
    private static void testSetup() {
        TritonTestFactory.initTestSetup();
    }

    @IsTest
    private static void test_log_levels() {
        TritonTestFactory.assertNoLogs();

        Log_Level__mdt ll = new Log_Level__mdt();
        ll.Level__c = TritonTypes.Level.DEBUG.name();
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ll};
        TritonHelper.Config.logLevels = null;

        System.assertEquals(1, TritonHelper.Config.logLevels.size(), 'Expected a single parsed log level rule');
    }

    @IsTest
    private static void test_log_levels_positive() {
        TritonTestFactory.assertNoLogs();

        Log_Level__mdt ll = new Log_Level__mdt();
        ll.Level__c = TritonTypes.Level.DEBUG.name();
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ll};

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('some event').details('error details').level(TritonTypes.Level.DEBUG));
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_log_levels_negative() {
        TritonTestFactory.assertNoLogs();

        Log_Level__mdt ll = new Log_Level__mdt();
        ll.Level__c = TritonTypes.Level.DEBUG.name();
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ll};

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('some event').details('error details').level(TritonTypes.Level.FINE));
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

        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{globalLevel, categoryLevel, categoryAndAreaLevel};
        TritonHelper.Config.logLevels = null;
    }

    @IsTest
    private static void test_log_levels_mapping() {
        TritonTestFactory.assertNoLogs();

        setupLogLevelsMap();

        System.assertEquals(3, TritonHelper.Config.logLevels.size(), 'Expected three parsed log level rules');

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('some event').details('error details').level(TritonTypes.Level.FINEST));
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_log_levels_mapping_negative() {
        TritonTestFactory.assertNoLogs();

        setupLogLevelsMap();

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.OpportunityManagement).summary('some event').details('error details').level(TritonTypes.Level.FINEST));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c WHERE pharos__Category__c = :TritonTypes.Category.Event.name()]);
    }

    // A user-scoped log level record used by the user id tests below.
    private static void setupUserIdLogLevel(Id userId) {
        Log_Level__mdt userLevel = new Log_Level__mdt();
        userLevel.Level__c = TritonTypes.Level.DEBUG.name();
        userLevel.User_Id__c = userId;

        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ userLevel };
        TritonHelper.Config.logLevels = null;
    }

    @IsTest
    private static void test_log_level_by_user_id_positive() {
        TritonTestFactory.assertNoLogs();

        // Level defined only for the current user, allowing DEBUG and above.
        setupUserIdLogLevel(UserInfo.getUserId());

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('some event').details('error details').userId(UserInfo.getUserId()).level(TritonTypes.Level.DEBUG));
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_log_level_by_user_id_negative() {
        TritonTestFactory.assertNoLogs();

        // The user-scoped level allows only DEBUG and above; a FINE log for that
        // same user must be filtered out.
        setupUserIdLogLevel(UserInfo.getUserId());

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('some event').details('error details').userId(UserInfo.getUserId()).level(TritonTypes.Level.FINE));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c WHERE pharos__Category__c = :TritonTypes.Category.Event.name()]);
    }

    @IsTest
    private static void test_log_level_by_user_id_different_user() {
        TritonTestFactory.assertNoLogs();

        // Level is scoped to a different user, so it must not target the current
        // user's logs -- the FINE log falls through the default-allow path.
        setupUserIdLogLevel('005000000000001');

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('some event').details('error details').userId(UserInfo.getUserId()).level(TritonTypes.Level.FINE));
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_log_level_by_component_apex_positive() {
        TritonTestFactory.assertNoLogs();

        // Level defined only for the 'MyComponent' Apex class, allowing DEBUG and above.
        Log_Level__mdt componentLevel = new Log_Level__mdt();
        componentLevel.Level__c = TritonTypes.Level.DEBUG.name();
        componentLevel.Component_Name__c = 'MyComponent';
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ componentLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        // Apex Name is Class.Method; the class portion must match the component name.
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('some event').details('error details').operation('MyComponent.someMethod').level(TritonTypes.Level.DEBUG));
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_log_level_by_component_apex_negative() {
        TritonTestFactory.assertNoLogs();

        Log_Level__mdt componentLevel = new Log_Level__mdt();
        componentLevel.Level__c = TritonTypes.Level.DEBUG.name();
        componentLevel.Component_Name__c = 'MyComponent';
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ componentLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        // Component matches but FINE is more verbose than the allowed DEBUG.
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('some event').details('error details').operation('MyComponent.someMethod').level(TritonTypes.Level.FINE));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c WHERE pharos__Category__c = :TritonTypes.Category.Event.name()]);
    }

    @IsTest
    private static void test_log_level_by_component_flow() {
        TritonTestFactory.assertNoLogs();

        // For flows the component is identified by the Flow API name, which takes
        // precedence over the Apex Name.
        Log_Level__mdt componentLevel = new Log_Level__mdt();
        componentLevel.Level__c = TritonTypes.Level.DEBUG.name();
        componentLevel.Component_Name__c = 'My_Flow';
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ componentLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('some event').details('error details').flowApiName('My_Flow').operation('Some.Apex').level(TritonTypes.Level.DEBUG));
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_log_level_all_attributes() {
        TritonTestFactory.assertNoLogs();

        // A single, fully-specified rule so the assertion isolates the new
        // user id / component matching (nothing broader can match instead).
        Log_Level__mdt allLevel = new Log_Level__mdt();
        allLevel.Level__c = TritonTypes.Level.FINER.name();
        allLevel.Category__c = TritonTypes.Category.Event.name();
        allLevel.Type__c = TritonTypes.Type.DMLResult.name();
        allLevel.Area__c = TritonTypes.Area.Community.name();
        allLevel.User_Id__c = UserInfo.getUserId();
        allLevel.Component_Name__c = 'TestComponentName';
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ allLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        // Matches every attribute at exactly the allowed level.
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.DMLResult).area(TritonTypes.Area.Community)
            .summary('some event').details('error details').userId(UserInfo.getUserId()).operation('TestComponentName').level(TritonTypes.Level.FINER));
        // Same attributes but a different component -> no rule targets it -> allowed by default.
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.DMLResult).area(TritonTypes.Area.Community)
            .summary('other event').details('error details').userId(UserInfo.getUserId()).operation('OtherComponent').level(TritonTypes.Level.FINER));
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT pharos__User_Id__c, pharos__Apex_Name__c
            FROM pharos__Log__c
            WHERE pharos__Category__c = :TritonTypes.Category.Event.name()
            ORDER BY pharos__Apex_Name__c
        ];
        System.assertEquals(2, logs.size(), 'Both the targeted (allowed) and untargeted (default-allowed) logs should persist');
        System.assertEquals('OtherComponent', logs.get(0).pharos__Apex_Name__c);
        System.assertEquals('TestComponentName', logs.get(1).pharos__Apex_Name__c);
        System.assertEquals(UserInfo.getUserId(), logs.get(1).pharos__User_Id__c);
    }

    // --- Specificity-based resolution -------------------------------------
    // The most specific rule targeting a log decides its level and overrides
    // every less specific rule, in both directions: a narrow rule can lower
    // verbosity below a broad one, not only raise it above it.

    @IsTest
    private static void test_specificity_narrow_component_silences_verbose_global() {
        TritonTestFactory.assertNoLogs();

        // Global default logs everything, but one noisy component is pinned to
        // ERROR. A DEBUG log from that component must be dropped.
        Log_Level__mdt globalLevel = new Log_Level__mdt();
        globalLevel.Level__c = TritonTypes.Level.FINEST.name();

        Log_Level__mdt componentLevel = new Log_Level__mdt();
        componentLevel.Level__c = TritonTypes.Level.ERROR.name();
        componentLevel.Component_Name__c = 'NoisyBatch';

        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ globalLevel, componentLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('noise').details('details').operation('NoisyBatch.run').level(TritonTypes.Level.DEBUG));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c WHERE pharos__Category__c = :TritonTypes.Category.Event.name()],
            'The component-scoped ERROR rule is more specific than the global FINEST rule and must suppress the DEBUG log');
    }

    @IsTest
    private static void test_specificity_narrow_area_tightens_broader_category() {
        TritonTestFactory.assertNoLogs();

        // Category-wide rule allows FINE, but one area is tightened to INFO.
        Log_Level__mdt categoryLevel = new Log_Level__mdt();
        categoryLevel.Level__c = TritonTypes.Level.FINE.name();
        categoryLevel.Category__c = TritonTypes.Category.Event.name();

        Log_Level__mdt areaLevel = new Log_Level__mdt();
        areaLevel.Level__c = TritonTypes.Level.INFO.name();
        areaLevel.Category__c = TritonTypes.Category.Event.name();
        areaLevel.Area__c = TritonTypes.Area.Community.name();

        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ categoryLevel, areaLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        // DEBUG is above the tightened INFO ceiling for this area -> dropped.
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('tightened').details('details').level(TritonTypes.Level.DEBUG));
        // The same level in a different area still falls under the FINE rule -> kept.
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.OpportunityManagement)
            .summary('untightened').details('details').level(TritonTypes.Level.DEBUG));
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT pharos__Summary__c FROM pharos__Log__c
            WHERE pharos__Category__c = :TritonTypes.Category.Event.name()];
        System.assertEquals(1, logs.size(), 'Only the log outside the tightened area should persist');
        System.assertEquals('untightened', logs.get(0).pharos__Summary__c);
    }

    @IsTest
    private static void test_specificity_user_rule_outranks_category_type_area() {
        TritonTestFactory.assertNoLogs();

        // A user-scoped rule outranks a rule naming category + type + area,
        // so the user rule's level decides -- here silencing the log.
        Log_Level__mdt ctaLevel = new Log_Level__mdt();
        ctaLevel.Level__c = TritonTypes.Level.FINEST.name();
        ctaLevel.Category__c = TritonTypes.Category.Event.name();
        ctaLevel.Type__c = TritonTypes.Type.Backend.name();
        ctaLevel.Area__c = TritonTypes.Area.Community.name();

        Log_Level__mdt userLevel = new Log_Level__mdt();
        userLevel.Level__c = TritonTypes.Level.WARNING.name();
        userLevel.User_Id__c = UserInfo.getUserId();

        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ ctaLevel, userLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('user scoped').details('details').userId(UserInfo.getUserId()).level(TritonTypes.Level.INFO));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c WHERE pharos__Category__c = :TritonTypes.Category.Event.name()],
            'The user-scoped rule is the most specific match and its WARNING ceiling must suppress the INFO log');
    }

    @IsTest
    private static void test_specificity_narrow_rule_still_raises_verbosity() {
        TritonTestFactory.assertNoLogs();

        // Specificity works in both directions: a narrow rule above a quiet
        // global default must still raise verbosity for its scope.
        Log_Level__mdt globalLevel = new Log_Level__mdt();
        globalLevel.Level__c = TritonTypes.Level.ERROR.name();

        Log_Level__mdt userLevel = new Log_Level__mdt();
        userLevel.Level__c = TritonTypes.Level.FINEST.name();
        userLevel.User_Id__c = UserInfo.getUserId();

        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ globalLevel, userLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('debug me').details('details').userId(UserInfo.getUserId()).level(TritonTypes.Level.FINE));
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_specificity_tie_breaks_to_most_restrictive() {
        TritonTestFactory.assertNoLogs();

        // Two rules with an identical field set (equally specific) both target
        // the log. The more restrictive level wins so config order cannot
        // change the outcome.
        Log_Level__mdt verbose = new Log_Level__mdt();
        verbose.Level__c = TritonTypes.Level.FINEST.name();
        verbose.Category__c = TritonTypes.Category.Event.name();

        Log_Level__mdt restrictive = new Log_Level__mdt();
        restrictive.Level__c = TritonTypes.Level.WARNING.name();
        restrictive.Category__c = TritonTypes.Category.Event.name();

        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ verbose, restrictive };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('tie').details('details').level(TritonTypes.Level.INFO));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c WHERE pharos__Category__c = :TritonTypes.Category.Event.name()],
            'Equally specific rules must resolve to the most restrictive level regardless of order');
    }

    @IsTest
    private static void test_has_component_scoped_levels() {
        // No component rules -> the stack trace must not be resolved early.
        Log_Level__mdt plain = new Log_Level__mdt();
        plain.Level__c = TritonTypes.Level.DEBUG.name();
        plain.Category__c = TritonTypes.Category.Event.name();
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ plain };
        TritonHelper.Config.logLevels = null;
        System.assertEquals(false, TritonHelper.Config.hasComponentScopedLevels(),
            'No rule names a component, so early operation resolution must stay off');

        // At least one component rule -> early resolution is required.
        Log_Level__mdt componentLevel = new Log_Level__mdt();
        componentLevel.Level__c = TritonTypes.Level.DEBUG.name();
        componentLevel.Component_Name__c = 'SomeClass';
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ plain, componentLevel };
        TritonHelper.Config.logLevels = null;
        System.assertEquals(true, TritonHelper.Config.hasComponentScopedLevels(),
            'A component-scoped rule requires the operation to be resolved before the level check');
    }

    @IsTest
    private static void test_resolve_stack_trace_and_operation_is_idempotent() {
        // prepareForLogging calls the same resolution again after the level
        // check, so an explicit stacktrace must never be overwritten and the
        // cost must not be paid twice.
        TritonBuilder builder = Triton.makeBuilder()
            .type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('preset')
            .stackTrace('MyClass.myMethod: line 1, column 1').operation('MyClass.myMethod');

        builder.resolveStackTraceAndOperation();
        builder.resolveStackTraceAndOperation();

        pharos__Log__c log = builder.build();
        System.assertEquals('MyClass.myMethod: line 1, column 1', log.pharos__Stacktrace__c,
            'An explicitly supplied stacktrace must be preserved');
        System.assertEquals('MyClass.myMethod', log.pharos__Apex_Name__c,
            'An explicitly supplied operation must be preserved');
    }

    @IsTest
    private static void test_is_triton_frame() {
        // Framework frames, including inner-class and namespaced forms.
        System.assertEquals(true, TritonHelper.isTritonFrame('Class.Triton.log: line 292, column 1'));
        System.assertEquals(true, TritonHelper.isTritonFrame('Class.TritonHelper.getCurrentStackTrace: line 209, column 1'));
        System.assertEquals(true, TritonHelper.isTritonFrame('Class.TritonHelper.Config.isLogAllowed: line 750, column 1'));
        System.assertEquals(true, TritonHelper.isTritonFrame('Class.myns.TritonBuilder.build: line 10, column 1'));

        // Application code whose name merely contains 'Triton' must survive.
        System.assertEquals(false, TritonHelper.isTritonFrame('Class.TritonWrapper.doWork: line 5, column 1'),
            'A customer class containing the word Triton is not a framework frame');
        System.assertEquals(false, TritonHelper.isTritonFrame('Class.TritonTest.test_x: line 5, column 1'),
            'Triton test classes are application code from the framework point of view');
        System.assertEquals(false, TritonHelper.isTritonFrame('Class.MyClass.Triton: line 5, column 1'),
            'A method named after a framework class is not a framework frame');

        // Non-class frames are always caller code.
        System.assertEquals(false, TritonHelper.isTritonFrame('Trigger.AccountTrigger: line 7, column 1'));
        System.assertEquals(false, TritonHelper.isTritonFrame('AnonymousBlock: line 1, column 1'));
        System.assertEquals(false, TritonHelper.isTritonFrame(''));
        System.assertEquals(false, TritonHelper.isTritonFrame(null));
    }

    @IsTest
    private static void test_filter_stack_trace_keeps_lookalike_classes() {
        String trace = 'Class.TritonHelper.getCurrentStackTrace: line 209, column 1\n'
            + 'Class.Triton.log: line 292, column 1\n'
            + 'Class.TritonWrapper.doWork: line 5, column 1\n'
            + 'Class.AccountService.update: line 42, column 1';

        String filtered = TritonHelper.filterStackTrace(trace);

        System.assert(!filtered.contains('TritonHelper'), 'Framework frames must be filtered out');
        System.assert(!filtered.contains('Class.Triton.log'), 'Framework frames must be filtered out');
        System.assert(filtered.contains('TritonWrapper'),
            'An application class named TritonWrapper must be preserved');
        System.assert(filtered.contains('AccountService'), 'Application frames must be preserved');
    }

    @IsTest
    private static void test_get_operation_skips_only_framework_frames() {
        String trace = 'Class.TritonHelper.getCurrentStackTrace: line 209, column 1\n'
            + 'Class.Triton.log: line 292, column 1\n'
            + 'Class.TritonWrapper.doWork: line 5, column 1\n'
            + 'Class.AccountService.update: line 42, column 1';

        System.assertEquals('Class.TritonWrapper.doWork', TritonHelper.getOperation(trace),
            'The topmost non-framework frame wins, even when its class name contains Triton');
    }

    @IsTest
    private static void test_resolve_stack_trace_and_operation_populates_apex_name() {
        // The component used for log level matching comes from the Apex Name,
        // which Triton.log() must resolve BEFORE the level check when a
        // component-scoped level exists.
        TritonBuilder builder = Triton.makeBuilder()
            .type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('resolve me');

        System.assertEquals(null, builder.build().pharos__Stacktrace__c,
            'Stacktrace should be unset before resolution');

        builder.resolveStackTraceAndOperation();

        pharos__Log__c log = builder.build();
        System.assertNotEquals(null, log.pharos__Stacktrace__c,
            'resolveStackTraceAndOperation must capture the stacktrace ahead of the level check');
        System.assert(log.pharos__Apex_Name__c.contains('TritonTest'),
            'The operation must resolve to the calling class, not to a framework frame. Got: ' + log.pharos__Apex_Name__c);
    }

    @IsTest
    private static void test_component_level_matches_stack_trace_derived_apex_name() {
        TritonTestFactory.assertNoLogs();

        // A component-scoped rule must apply to an Apex log that never sets
        // .operation() explicitly -- the component is derived from the stack
        // trace before the level check runs. This test class is the component:
        // it is application code from the framework's point of view, so its
        // frames survive filtering.
        Log_Level__mdt componentLevel = new Log_Level__mdt();
        componentLevel.Level__c = TritonTypes.Level.ERROR.name();
        componentLevel.Component_Name__c = 'TritonTest';
        TritonHelper.Config.logLevelsMdt = new Log_Level__mdt[]{ componentLevel };
        TritonHelper.Config.logLevels = null;

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community)
            .summary('implicit component').details('details').level(TritonTypes.Level.DEBUG));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c WHERE pharos__Category__c = :TritonTypes.Category.Event.name()],
            'Component-scoped levels must match Apex logs whose component is derived from the stack trace');
    }

    @IsTest
    private static void test_get_component_name() {
        // Flow API name takes precedence.
        pharos__Log__c flowLog = new pharos__Log__c(pharos__Flow_API_Name__c = 'My_Flow', pharos__Apex_Name__c = 'Some.Apex');
        System.assertEquals('My_Flow', TritonHelper.getComponentName(flowLog));

        // Stack-trace-derived Apex Names keep the frame's 'Class.' prefix; the
        // component is the class, not the literal 'Class'.
        pharos__Log__c framedLog = new pharos__Log__c(pharos__Apex_Name__c = 'Class.AccountService.updateAccounts');
        System.assertEquals('AccountService', TritonHelper.getComponentName(framedLog),
            'The Class. prefix must be stripped before resolving the component');

        // LWC names carry no prefix.
        pharos__Log__c lwcLog = new pharos__Log__c(pharos__Apex_Name__c = 'orderBuilder.Proxy.next');
        System.assertEquals('orderBuilder', TritonHelper.getComponentName(lwcLog));

        // Apex name: class portion before the first dot.
        pharos__Log__c apexLog = new pharos__Log__c(pharos__Apex_Name__c = 'MyClass.myMethod');
        System.assertEquals('MyClass', TritonHelper.getComponentName(apexLog));

        // Apex name without a dot is returned as-is.
        pharos__Log__c plainLog = new pharos__Log__c(pharos__Apex_Name__c = 'MyClass');
        System.assertEquals('MyClass', TritonHelper.getComponentName(plainLog));

        // Nothing to resolve.
        System.assertEquals(null, TritonHelper.getComponentName(new pharos__Log__c()));
    }

    @IsTest
    private static void test_normalize_user_id() {
        Id userId = UserInfo.getUserId();
        System.assertEquals(String.valueOf(userId).substring(0, 15), TritonHelper.normalizeUserId(userId),
            '18-character Id should be truncated to its 15-character prefix');
        System.assertEquals('015CHAR00000000', TritonHelper.normalizeUserId('015CHAR00000000'),
            '15-character value should be returned unchanged');
        System.assertEquals(null, TritonHelper.normalizeUserId(null));
    }

    @IsTest
    private static void test_sync_event() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('some event').details('error details').info());
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Event);
    }

    @IsTest
    private static void test_sync_debug() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Debug).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('some debug').details('error details').debug());
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Debug);
    }

    @IsTest
    private static void test_sync_warning() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Warning).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('some warning').details('error details').warning());
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Warning);
    }

    @IsTest
    private static void test_sync_error() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Apex).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('some error').details('error details').error());
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Apex);
    }

    @IsTest
    private static void test_sync_error_from_exception() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        try {
            Integer i = 2/0;
        }
        catch(Exception e) {
            Triton.logNow(Triton.t.area(TritonTypes.Area.Community).exception(e));
        }
        Test.stopTest();

        TritonTestFactory.assertSingleLog(TritonTypes.Category.Apex);
    }

    @IsTest
    private static void test_sync_integration_from_exception() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        HttpCalloutMock multiCalloutMock = new MultiRequestMock(createEndpoint2TestResp());
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        testHttpRequest();
        pharos__Log__c spacerLog = new pharos__Log__c(
            pharos__Summary__c = 'Spacer',
            pharos__Post_Processing_Status__c = 'Not Needed'
        );
        insert spacerLog;
        delete spacerLog;
        testHttpRequest();
        Test.stopTest();

        assertCreatedIntegrationLog();
    }

    @IsTest
    private static void test_integration_error_sync() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/Account/testId';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Triton.logNow(Triton.makeBuilder().category(TritonTypes.Category.Integration).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('test summary').details('test details').integrationPayload(req, res).error());
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Summary__c, pharos__Hash__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('test summary', logs.get(0).pharos__Summary__c);
        System.assertNotEquals(null, logs.get(0).pharos__Hash__c);
    }

    @IsTest
    private static void test_save_component_log() {
        TritonTestFactory.assertNoLogs();

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

    /**
     * Deprecated 'Integration' category is a sanctioned input (LOG-2927):
     * mapped case-insensitively to the LWC context category,
     * without the invalid-category note.
     */
    @IsTest
    private static void test_save_component_log_integration_category_maps_to_lwc() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        List<TritonLwc.ComponentLog> componentLogs = new List<TritonLwc.ComponentLog>();
        for (String categoryValue : new List<String>{'Integration', 'integration'}) {
            TritonLwc.ComponentLog componentLog = new TritonLwc.ComponentLog();
            componentLog.category = categoryValue;
            componentLog.type = 'test type';
            componentLog.area = TritonTypes.Area.LWC.name();
            componentLog.level = TritonTypes.Level.ERROR.name();
            componentLog.summary = 'integration category mapping: ' + categoryValue;
            componentLog.details = 'test details';
            TritonLwc.Component component = new TritonLwc.Component();
            component.name = 'TestComponent';
            component.function = 'testFunction';
            componentLog.componentInfo = component;
            componentLogs.add(componentLog);
        }
        TritonLwc.saveComponentLogs(componentLogs);
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Category__c, pharos__Details__c FROM pharos__Log__c];
        System.assertEquals(2, logs.size(), 'Expected both component logs to be created');
        for (pharos__Log__c log : logs) {
            System.assertEquals(TritonTypes.Category.LWC.name(), log.pharos__Category__c,
                'Deprecated Integration category should map to LWC, but was: ' + log.pharos__Category__c);
            System.assert(log.pharos__Details__c == null || !log.pharos__Details__c.contains('Invalid Log Category'),
                'Sanctioned Integration mapping must not append the invalid-category note');
        }
    }

    @IsTest
    private static void test_lwc_runtime_info() {
        TritonTestFactory.assertNoLogs();
        
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
        TritonTestFactory.assertNoLogs();

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
    private static void test_triton_builder() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        Triton.logNow(Triton.t.category(TritonTypes.Category.Event).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('some event').details('error details').level(TritonTypes.Level.INFO));
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
    private static void test_triton_builder_traceable() {
        TritonBuilder builder = new TritonBuilder();
        builder
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .level(TritonTypes.Level.INFO)
            .summary('some event')
            .details('error details')
            .stackTrace('Debug details')
            .traceable(true)
            .tracePoint();

        System.assertEquals(true, builder.traceable, 'Traceable flag should be set');

    }

    @IsTest
    private static void test_trace_point_when_not_traceable() {
        TritonBuilder builder = new TritonBuilder();
        builder
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .level(TritonTypes.Level.INFO)
            .summary('trace point no-op test')
            .details('details')
            .traceable(false)
            .tracePoint();

        System.assertEquals(false, builder.traceable, 'Should not be traceable when traceable(false)');
    }

    @IsTest
    private static void test_traceable_creates_issue() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        Triton.log(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Apex)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .level(TritonTypes.Level.INFO)
                .summary('traceable creates issue test')
                .details('details')
                .traceable(true)
                .tracePoint()
        );
        Triton.flush();
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Do_Not_Create_Issue__c FROM pharos__Log__c];
        System.assertEquals(1, logs.size(), 'Should have one log');
        System.assertEquals(false, logs.get(0).pharos__Do_Not_Create_Issue__c, 'traceable(true) should create issue');
    }

    @IsTest
    private static void test_template() {
        TritonTestFactory.assertNoLogs();
        
        TritonBuilder template = Triton.makeBuilder();
        template.category(TritonTypes.Category.Apex);
        template.type(TritonTypes.Type.Backend);
        template.area(TritonTypes.Area.Community);
        template.level(TritonTypes.Level.INFO);
        Triton.setTemplate(template);
        Test.startTest();
        Triton.logNow(Triton.t
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
                Triton.logNow(Triton.makeBuilder().category(TritonTypes.Category.Integration).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('test integration').details('test error details').integrationPayload(req, res).error());
            }
        } catch (Exception e) {
            Triton.logNow(Triton.makeBuilder().category(TritonTypes.Category.Integration).area(TritonTypes.Area.Community).exception(e).integrationPayload(req, res));
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
        Id fakeId = pharos__Log__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

        // 1. Test SaveResult - Insert log with invalid lookup to force failure
        pharos__Log__c invalidLog = new pharos__Log__c(pharos__Issue__c = fakeId);
        Database.SaveResult[] srList = Database.insert(new List<pharos__Log__c>{invalidLog}, false);
        System.assert(!srList[0].isSuccess(), 'Insert should fail');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Accounts).dmlResults(srList));

        // 2. Test SaveResult with field-specific error details
        pharos__Log__c invalidLog2 = new pharos__Log__c(pharos__Issue__c = fakeId);
        Database.SaveResult[] fieldSrList = Database.insert(new List<pharos__Log__c>{invalidLog2}, false);
        System.assert(!fieldSrList[0].isSuccess(), 'Insert should fail with field error');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Community).dmlResults(fieldSrList));

        // 3. Test DeleteResult - Try to delete non-existent record
        Database.DeleteResult[] drList = Database.delete(new List<Id>{fakeId}, false);
        System.assert(!drList[0].isSuccess(), 'Delete should fail');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Accounts).dmlResults(drList));

        // 4. Test UndeleteResult - Try to undelete non-existent record
        Database.UndeleteResult[] urList = Database.undelete(new List<Id>{fakeId}, false);
        System.assert(!urList[0].isSuccess(), 'Undelete should fail');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Accounts).dmlResults(urList));

        // 5. Test UpsertResult - Try to update non-existent record
        pharos__Log__c invalidUpsertLog = new pharos__Log__c(Id = fakeId);
        Database.UpsertResult[] urList2 = Database.upsert(new List<pharos__Log__c>{invalidUpsertLog}, false);
        System.assert(!urList2[0].isSuccess(), 'Upsert should fail');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Accounts).dmlResults(urList2));

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

        System.assertEquals(5, logs.size(), 'Expected 5 DML error logs');

        Set<String> expectedOperations = new Set<String>{'Save', 'Delete', 'Undelete', 'Upsert'};
        Set<String> foundOperations = new Set<String>();

        // Find the field error log
        pharos__Log__c fieldErrorLog = null;
        for(pharos__Log__c log : logs) {
            System.assertEquals(TritonTypes.Type.DMLResult.name(), log.pharos__Type__c);
            System.assertEquals(TritonTypes.Level.ERROR.name(), log.Log_Level__c);
            System.assert(log.pharos__Summary__c.contains('DML Operation'));

            foundOperations.add(log.pharos__Apex_Name__c);

            if(log.pharos__Area__c == TritonTypes.Area.Community.name()) {
                fieldErrorLog = log;
            }
        }

        // Verify all expected operations are found
        System.assertEquals(expectedOperations, foundOperations);

        // Verify error information is included in the field error log
        System.assertNotEquals(null, fieldErrorLog, 'Field error log should be created');
        System.assert(fieldErrorLog.pharos__Details__c.contains('Status Code:'),
            'Error log should include status code');
    }

    @IsTest
    private static void testDMLErrorLogging_NoErrors() {
        Test.startTest();

        // 1. Test SaveResult with valid data
        pharos__Log__c newLog = new pharos__Log__c(
            pharos__Summary__c = 'Valid Log',
            pharos__Post_Processing_Status__c = 'Not Needed'
        );
        Database.SaveResult[] srList = Database.insert(new List<pharos__Log__c>{newLog}, false);
        System.assert(srList[0].isSuccess(), 'Insert should succeed');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Accounts).dmlResults(srList));

        // 2. Test UpsertResult with valid data
        newLog.pharos__Summary__c = 'Updated Log';
        Database.UpsertResult[] upsertList = Database.upsert(new List<pharos__Log__c>{newLog}, false);
        System.assert(upsertList[0].isSuccess(), 'Upsert should succeed');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Accounts).dmlResults(upsertList));

        // 3. Test DeleteResult with valid data
        Database.DeleteResult[] drList = Database.delete(new List<Id>{newLog.Id}, false);
        System.assert(drList[0].isSuccess(), 'Delete should succeed');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Accounts).dmlResults(drList));

        // 4. Test UndeleteResult with valid data
        Database.UndeleteResult[] urList = Database.undelete(new List<Id>{newLog.Id}, false);
        System.assert(urList[0].isSuccess(), 'Undelete should succeed');
        Triton.logNow(Triton.makeBuilder().area(TritonTypes.Area.Accounts).dmlResults(urList));
        
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
        TritonTestFactory.assertNoLogs();
        
        Test.startTest();
        
        // Add multiple logs to buffer without flushing
        Triton.log(
            Triton.t.category(TritonTypes.Category.Apex).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('first error').details('first details').error()
        );
        Triton.log(
            Triton.t.category(TritonTypes.Category.Apex).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('second error').details('second details').error()
        );
        Triton.log(
            Triton.t.category(TritonTypes.Category.Apex).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('third error').details('third details').error()
        );
        
        // Test flushTop with populated buffer
        Triton.flushTop();
        Test.stopTest();
        
        // Verify only last log was persisted
        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Summary__c 
            FROM pharos__Log__c 
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(1, logs.size(), 'Only one log should be persisted');
        System.assertEquals('third error', logs[0].pharos__Summary__c, 'Last added log should be persisted');
        System.assertEquals(2, Triton.logs.size(), 'Should have two logs remaining in buffer');
    }

    @IsTest
    private static void test_flush_top_immediate() {
        TritonTestFactory.assertNoLogs();
        
        Test.startTest();
        Triton.log(
            Triton.t.category(TritonTypes.Category.Apex).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('first error').details('first details').error()
        );

        // Test immediate error method - should only flush that error
        Triton.logNow(
            Triton.t.category(TritonTypes.Category.Apex).type(TritonTypes.Type.Backend).area(TritonTypes.Area.Community).summary('immediate error').details('immediate details').error()
        );
        Test.stopTest();
        
        List<pharos__Log__c> logs = [
            SELECT Id, pharos__Summary__c 
            FROM pharos__Log__c 
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(1, logs.size(), 'Should have one log persisted');
        System.assertEquals('immediate error', logs[0].pharos__Summary__c, 'Immediate error should be persisted');
        System.assertEquals(1, Triton.logs.size(), 'Should have one log remaining in buffer');
    }

    @IsTest
    private static void test_flush_top_empty_buffer() {
        TritonTestFactory.assertNoLogs();
        
        Test.startTest();
        Triton.flushTop();
        Test.stopTest();
        
        List<pharos__Log__c> logs = [SELECT Id FROM pharos__Log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created with empty buffer');
    }

    @IsTest
    private static void test_limit_info() {
        TritonTestFactory.assertNoLogs();
        
        Test.startTest();
        
        // Create some limit usage
        for(Integer i = 0; i < 5; i++) {
            List<pharos__Log__c> logs = [SELECT Id FROM pharos__Log__c LIMIT 1];
        }
        pharos__Log__c testLog = new pharos__Log__c(
            pharos__Summary__c = 'Limit Test',
            pharos__Post_Processing_Status__c = 'Not Needed'
        );
        insert testLog;
        
        // Test via builder
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.Debug)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .summary('Testing limits')
            .details('Limit info test')
            .limitInfo();
        
        Triton.logNow(builder);

        // Test via log
        Triton.log(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Debug)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('Testing limits via addLog')
                .details('Limit info test via addLog')
                .limitInfo()
        );
        Triton.flush();
        
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
                   Callouts_Limit__c
            FROM pharos__Log__c
            WHERE pharos__Area__c = :TritonTypes.Area.Community.name()
            ORDER BY CreatedDate
        ];
        
        System.assertEquals(2, logs.size(), 'Should have created two logs');
        
        // Verify essential limits were captured (limitInfo without withFullLimitInfo only captures lite limits)
        for(pharos__Log__c log : logs) {
            System.assert(log.SOQL_Queries__c >= 5, 'Should have recorded SOQL queries');
            System.assertEquals(System.Limits.getLimitQueries(), log.SOQL_Queries_Limit__c, 'Should match SOQL queries limit');
            
            System.assert(log.DML_Statements__c >= 1, 'Should have recorded DML statements');
            System.assertEquals(System.Limits.getLimitDMLStatements(), log.DML_Statements_Limit__c, 'Should match DML statements limit');
            
            System.assert(log.DML_Rows__c >= 1, 'Should have recorded DML rows');
            System.assertEquals(System.Limits.getLimitDMLRows(), log.DML_Rows_Limit__c, 'Should match DML rows limit');
            
            System.assert(log.CPU_Time__c > 0, 'Should have recorded CPU time');
            System.assertEquals(System.Limits.getLimitCpuTime(), log.CPU_Time_Limit__c, 'Should match CPU time limit');
            System.assert(log.Heap_Size__c > 0, 'Should have recorded heap size');
            System.assertEquals(System.Limits.getLimitHeapSize(), log.Heap_Size_Limit__c, 'Should match heap size limit');
            
            System.assertEquals(0, log.Callouts__c, 'Should have recorded zero callouts');
            System.assertEquals(System.Limits.getLimitCallouts(), log.Callouts_Limit__c, 'Should match callouts limit');
        }
    }

    @IsTest
    private static void test_limit_info_without_limit_info() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        Triton.log(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Debug)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('No limit info test')
                .details('withoutLimitInfo then limitInfo should be no-op')
                .withoutLimitInfo()
                .limitInfo()
        );
        Triton.flush();
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT Id, SOQL_Queries__c, CPU_Time__c, Heap_Size__c
            FROM pharos__Log__c
            WHERE pharos__Summary__c = 'No limit info test'
        ];
        System.assertEquals(1, logs.size(), 'Should have one log');
        System.assertEquals(null, logs.get(0).SOQL_Queries__c, 'limitInfo should be no-op when withoutLimitInfo');
        System.assertEquals(null, logs.get(0).CPU_Time__c, 'limitInfo should be no-op when withoutLimitInfo');
        System.assertEquals(null, logs.get(0).Heap_Size__c, 'limitInfo should be no-op when withoutLimitInfo');
    }

    @IsTest
    private static void test_limit_info_full() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        Triton.log(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Debug)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('Full limit info test')
                .details('withFullLimitInfo should capture extended limits')
                .withFullLimitInfo()
                .limitInfo()
        );
        Triton.flush();
        Test.stopTest();

        List<pharos__Log__c> logs = [
            SELECT Id, SOQL_Queries__c, SOQL_Aggregates__c, SOSL_Queries__c, Future_Calls__c
            FROM pharos__Log__c
            WHERE pharos__Summary__c = 'Full limit info test'
        ];
        System.assertEquals(1, logs.size(), 'Should have one log');
        System.assertNotEquals(null, logs.get(0).SOQL_Queries__c, 'Should have essential limits');
        System.assertNotEquals(null, logs.get(0).SOQL_Aggregates__c, 'Should have extended limits when withFullLimitInfo');
        System.assertNotEquals(null, logs.get(0).SOSL_Queries__c, 'Should have extended limits when withFullLimitInfo');
        System.assertNotEquals(null, logs.get(0).Future_Calls__c, 'Should have extended limits when withFullLimitInfo');
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
        TritonCacheManager.resetMock();
        // Reset CACHE_AVAILABLE so it re-evaluates through TritonCacheManager
        Triton.CACHE_AVAILABLE = null;

        Test.startTest();

        // Mock cache is always available in test context
        Triton.withCache();
        System.assert(Triton.cacheEnabled, 'Cache should be enabled');

        // Start a transaction and verify it's cached
        String transactionId = Triton.startTransaction();
        System.assertNotEquals(null, transactionId, 'Transaction ID should be generated');
        System.assertEquals(transactionId, TritonHelper.getCachedTransactionId(), 'Transaction ID should be cached');

        // Resume transaction and verify cache is updated
        String newTransactionId = 'test-transaction-id';
        Triton.resumeTransaction(newTransactionId);
        System.assertEquals(newTransactionId, TritonHelper.getCachedTransactionId(), 'New transaction ID should be cached');

        // Stop transaction and verify cache is cleared
        Triton.stopTransaction();
        System.assertEquals(null, TritonHelper.getCachedTransactionId(), 'Cache should be cleared after stopping transaction');

        Test.stopTest();
    }

    @IsTest
    private static void test_cache_functionality_negative() {
        TritonCacheManager.resetMock();

        Test.startTest();

        // Explicitly disable cache
        Triton.cacheEnabled = false;

        // Verify transaction management still works without cache
        String transactionId = Triton.startTransaction();
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
            Triton.log(
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
        System.assertEquals(3, Triton.logs.size(), 'Should have 3 logs in buffer');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c], 'No logs should be persisted yet');
        
        // Test flush - should persist all logs
        Triton.flush();
        
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
        Triton.setTemplate(template);
        
        // Add logs using template
        for(Integer i = 0; i < 3; i++) {
            Triton.log(
                Triton.t
                    .summary('Log ' + i)
                    .details('Template test ' + i)
            );
        }
        
        // Verify template properties are applied
        for(pharos__Log__c log : Triton.logs) {
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
        Triton.withCache();
        System.assertEquals(false, Triton.CACHE_AVAILABLE, 'Cache should remain disabled');
        System.assertNotEquals(null, Triton.TRANSACTION_ID, 'Transaction ID should be generated');
        
        Test.stopTest();
    }

    @IsTest
    private static void test_warning_and_debug_with_related_objects() {
        pharos__Log__c testLog = new pharos__Log__c(
            pharos__Summary__c = 'Related Objects Test',
            pharos__Post_Processing_Status__c = 'Not Needed'
        );
        insert testLog;
        Set<Id> relatedIds = new Set<Id>{testLog.Id};
        
        Test.startTest();
        
        // Test warning with related objects
        Triton.logNow(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Warning)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('Test Warning')
                .details('Warning details')
                .warning()
        );

        // Test debug with duration and related objects
        Triton.logNow(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Debug)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('Test Debug')
                .details('Debug details')
                .duration(100)
                .debug()
        );

        // Add debug with related objects
        Triton.log(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Debug)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('Test Debug with Related')
                .details('Debug details with related records')
                .duration(200)
                .debug()
        );
        
        Test.stopTest();
        
        List<pharos__Log__c> logs = [
            SELECT Id, 
                   pharos__Category__c,
                   Log_Level__c,
                   pharos__Duration__c,
                   pharos__Summary__c
            FROM pharos__Log__c 
            WHERE pharos__Area__c = :TritonTypes.Area.Community.name()
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
        Triton.logNow(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Event)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('Test Event')
                .details('Event details')
                .level(TritonTypes.Level.INFO)
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
            Triton.logNow(
                Triton.makeBuilder()
                    .category(TritonTypes.Category.Integration)
                    .area(TritonTypes.Area.Community)
                    .exception(e)
                    .integrationPayload(restReq, restRes)
                    .error()
            );
        }

        // Test with HttpRequest/Response
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint('https://example.com');
        httpReq.setMethod('GET');
        HttpResponse httpRes = new HttpResponse();
        httpRes.setStatusCode(500);
        httpRes.setStatus('Internal Server Error');

        Triton.logNow(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Integration)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('HTTP Error')
                .details('Error details')
                .integrationPayload(httpReq, httpRes)
                .error()
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
        TritonTestFactory.assertNoLogs();
        
        Test.startTest();
        String msg;
        // Test addError with just area and exception
        try {
            // Force an exception
            Integer i = 1/0;
        } catch(Exception e) {
            msg = e.getMessage();
            Triton.log(
                Triton.makeBuilder()
                    .category(TritonTypes.Category.Apex)
                    .area(TritonTypes.Area.Community)
                    .exception(e)
                    .error()
            );
        }
        
        // Verify log is in buffer but not persisted yet
        System.assertEquals(1, Triton.logs.size(), 'Should have one log in buffer');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c], 'No logs should be persisted yet');
        
        // Flush and verify log
        Triton.flush();
        
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
        TritonTestFactory.assertNoLogs();
        
        Test.startTest();
        
        // Test buffered event with default INFO level
        Triton.log(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Event)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('Test Event Summary')
                .details('Test Event Details')
                .info()
        );
        
        // Verify log is in buffer but not persisted yet
        System.assertEquals(1, Triton.logs.size(), 'Should have one log in buffer');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Log__c], 'No logs should be persisted yet');
        
        // Flush and verify log
        Triton.flush();
        
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
        // Add a debug log
        Test.startTest();
        Triton.log(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Debug)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Accounts)
                .summary('Test Summary')
                .details('Test Details')
                .debug()
        );
        Test.stopTest();

        // Verify log was added to the buffer
        System.assertEquals(1, Triton.logs.size(), 'One log should be in the buffer');

        // Verify log properties
        pharos__Log__c log = Triton.logs[0];
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

        // Insert a pharos__Log__c with invalid lookup to generate a field-specific error
        Id fakeId = pharos__Log__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        pharos__Log__c invalidLog = new pharos__Log__c(pharos__Issue__c = fakeId);
        Database.SaveResult[] srList = Database.insert(new List<pharos__Log__c>{invalidLog}, false);

        // Verify we got a field error
        System.assert(!srList[0].isSuccess(), 'Insert should fail');

        // Log the error - captures error via formatDMLError method
        Triton.logNow(
            Triton.makeBuilder()
                .area(TritonTypes.Area.Accounts)
                .dmlResults(srList)
        );
        Test.stopTest();

        // Retrieve the log to verify error formatting
        pharos__Log__c log = [
            SELECT pharos__Details__c
            FROM pharos__Log__c
            WHERE pharos__Area__c = :TritonTypes.Area.Accounts.name()
            LIMIT 1
        ];

        // Verify details contain error information
        System.assertNotEquals(null, log, 'A log should be created');
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

        // 1. Error with no specific fields (simulated concurrent update)
        pharos__Log__c testLog = new pharos__Log__c(
            pharos__Summary__c = 'Test Log',
            pharos__Post_Processing_Status__c = 'Not Needed'
        );
        insert testLog;

        // Create a locking error by attempting concurrent updates
        // This requires some creativity in a test context
        try {
            // Set up conflicting operations
            // First operation - establish update
            testLog.pharos__Summary__c = 'Updated 1';

            // Second operation (simulated concurrent) - would cause lock error in real scenario
            pharos__Log__c sameLog = [SELECT Id, pharos__Summary__c FROM pharos__Log__c WHERE Id = :testLog.Id];
            sameLog.pharos__Summary__c = 'Updated 2';
            update sameLog;

            // Try updating original record to cause error
            update testLog;
        } catch (Exception e) {
            // Create a log from the exception
            Triton.logNow(
                Triton.makeBuilder()
                    .category(TritonTypes.Category.Apex)
                    .area(TritonTypes.Area.Accounts)
                    .exception(e)
                    .error()
            );
        }

        // 2. Record not found error
        Id fakeId = pharos__Log__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        Database.DeleteResult[] drList = Database.delete(new List<Id>{fakeId}, false);
        Triton.logNow(
            Triton.makeBuilder()
                .area(TritonTypes.Area.Accounts)
                .dmlResults(drList)
        );
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
            
        Triton.setTemplate(template);
        
        // Start a transaction
        String transactionId = Triton.startTransaction();
        
        // Create a log from the template
        Triton.log(
            Triton.t
                .summary('Runtime properties test')
                .details('Testing runtime properties are reset')
        );
        Triton.flush();

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

    @isTest
    private static void test_triton_addLog_method() {
        TritonBuilder builder = new TritonBuilder();
        builder
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .level(TritonTypes.Level.INFO)
            .summary('some event')
            .details('error details')
            .stackTrace('Debug details')
            .traceable(true)
            .tracePoint();

        Triton.log(builder);
        Triton.flush();

        List<pharos__Log__c> logs = [SELECT Id, pharos__Stacktrace__c FROM pharos__Log__c];
        System.assertNotEquals(null, logs, 'Log should be created');
        System.assertEquals(true, builder.traceable, 'Traceable flag should be set');
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

    @IsTest
    static void test_summary_auto_carryover() {
        String longSummary = 'A'.repeat(300);
        pharos__Log__c log = Triton.makeBuilder()
            .summary(longSummary)
            .error()
            .build();
        System.assertEquals(255, log.pharos__Summary__c.length(), 'Summary should be truncated to 255');
        System.assertEquals(longSummary, log.pharos__Details__c, 'Full summary should be in details');
    }

    @IsTest
    static void test_summary_appended_to_details() {
        String longSummary = 'A'.repeat(300);
        String explicitDetails = 'explicit details';
        pharos__Log__c log = Triton.makeBuilder()
            .summary(longSummary)
            .details(explicitDetails)
            .error()
            .build();
        System.assertEquals(explicitDetails + Triton.SPACE_SEP + longSummary, log.pharos__Details__c,
            'Full summary should be appended to explicit details');
    }

    @IsTest
    static void test_level_shorthand_with_summary() {
        pharos__Log__c log = Triton.makeBuilder()
            .error('Account sync failed')
            .build();
        System.assertEquals('Account sync failed', log.pharos__Summary__c, 'Summary should be set');
        System.assertEquals('ERROR', log.Log_Level__c, 'Level should be ERROR');
    }

    @IsTest
    static void test_default_category_apex() {
        pharos__Log__c log = Triton.makeBuilder()
            .summary('test')
            .error()
            .build();
        System.assertEquals(TritonTypes.Category.Apex.name(), log.pharos__Category__c, 'Category should default to Apex');
    }

    @IsTest
    static void test_default_category_not_overridden() {
        pharos__Log__c log = Triton.makeBuilder()
            .category(TritonTypes.Category.Integration)
            .summary('test')
            .error()
            .build();
        System.assertEquals(TritonTypes.Category.Integration.name(), log.pharos__Category__c, 'Explicit category should not be overridden');
    }

    @IsTest
    static void test_execution_context_sync() {
        Test.startTest();
        String context = TritonHelper.formatExecutionContext();
        Test.stopTest();
        System.assertEquals('', context, 'Sync context should return empty string');
    }

    @IsTest
    static void test_builder_clone() {
        TritonBuilder original = Triton.makeBuilder()
            .category(TritonTypes.Category.Integration)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .level(TritonTypes.Level.WARNING)
            .withFullLimitInfo()
            .traceable(true);

        TritonBuilder cloned = original.cloneBuilder();
        pharos__Log__c clonedLog = cloned.build();

        System.assertEquals(TritonTypes.Category.Integration.name(), clonedLog.pharos__Category__c,
            'Cloned builder should preserve category');
        System.assertEquals(TritonTypes.Type.Backend.name(), clonedLog.pharos__Type__c,
            'Cloned builder should preserve type');
        System.assertEquals(TritonTypes.Area.Community.name(), clonedLog.pharos__Area__c,
            'Cloned builder should preserve area');
        System.assertEquals(true, cloned.fullLimitInfoRequested,
            'Cloned builder should preserve fullLimitInfoRequested');
        System.assertEquals(true, cloned.traceable,
            'Cloned builder should preserve traceable');
    }

    @IsTest
    static void test_execution_context_captured_for_apex_category() {
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .summary('apex context test')
            .details('original details');

        // Simulate the internal log path which calls prepareForLogging
        Triton.log(builder);

        // In synchronous test context formatExecutionContext returns empty string,
        // but the gate should have attempted to capture it (executionContextDetails is set to '')
        System.assertNotEquals(null, builder.executionContextDetails,
            'Apex category should trigger execution context capture');
    }

    @IsTest
    static void test_execution_context_skipped_for_flow_category() {
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.Flow)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .summary('flow context test')
            .details('original details');

        Triton.log(builder);

        System.assertEquals(null, builder.executionContextDetails,
            'Flow category should not trigger execution context capture');
    }

    @IsTest
    static void test_execution_context_skipped_for_lwc_category() {
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.LWC)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .summary('lwc context test')
            .details('original details');

        Triton.log(builder);

        System.assertEquals(null, builder.executionContextDetails,
            'LWC category should not trigger execution context capture');
    }

    @IsTest
    static void test_builder_post_processing() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();
        TritonHelper.PostProcessingControlsBuilder ppBuilder =
            Triton.makePostProcessingBuilder().setAll(true);
        Triton.logNow(
            Triton.makeBuilder()
                .category(TritonTypes.Category.Apex)
                .type(TritonTypes.Type.Backend)
                .area(TritonTypes.Area.Community)
                .summary('post processing test')
                .postProcessing(ppBuilder)
                .error()
        );
        Test.stopTest();

        List<pharos__Log__c> logs = [SELECT Id FROM pharos__Log__c];
        System.assertEquals(1, logs.size(), 'Log with post processing should be created');
    }

    @IsTest
    static void test_builder_action() {
        TritonBuilder builder = Triton.makeBuilder()
            .action('myAction')
            .summary('action test');
        pharos__Log__c log = builder.build();
        System.assertEquals('myAction', log.Action__c, 'Action should be set');
    }

    @IsTest
    static void test_builder_level_shorthands_with_summary() {
        // warning(String)
        pharos__Log__c log = Triton.makeBuilder().warning('warn msg').build();
        System.assertEquals('warn msg', log.pharos__Summary__c);
        System.assertEquals('WARNING', log.Log_Level__c);

        // info(String)
        log = Triton.makeBuilder().info('info msg').build();
        System.assertEquals('info msg', log.pharos__Summary__c);
        System.assertEquals('INFO', log.Log_Level__c);

        // debug(String)
        log = Triton.makeBuilder().debug('debug msg').build();
        System.assertEquals('debug msg', log.pharos__Summary__c);
        System.assertEquals('DEBUG', log.Log_Level__c);

        // fine(String)
        log = Triton.makeBuilder().fine('fine msg').build();
        System.assertEquals('fine msg', log.pharos__Summary__c);
        System.assertEquals('FINE', log.Log_Level__c);

        // finer(String)
        log = Triton.makeBuilder().finer('finer msg').build();
        System.assertEquals('finer msg', log.pharos__Summary__c);
        System.assertEquals('FINER', log.Log_Level__c);

        // finest(String)
        log = Triton.makeBuilder().finest('finest msg').build();
        System.assertEquals('finest msg', log.pharos__Summary__c);
        System.assertEquals('FINEST', log.Log_Level__c);
    }

    @IsTest
    static void test_builder_related_object_null() {
        TritonBuilder builder = Triton.makeBuilder();
        builder.relatedObject((Id)null);
        System.assertEquals(null, builder.build().pharos__Related_Objects__c,
            'relatedObject(null) should be no-op');
    }

    @IsTest
    static void test_builder_exception_null() {
        TritonBuilder builder = Triton.makeBuilder();
        builder.exception(null);
        // Should be no-op — no type/summary/stacktrace set from exception
        pharos__Log__c log = builder.build();
        System.assertNotEquals(null, log, 'Builder should still produce a log');
    }

    @IsTest
    static void test_builder_related_objects_list_string() {
        Id validId = UserInfo.getUserId();
        TritonBuilder builder = Triton.makeBuilder();
        builder.relatedObjects(new List<String>{ validId, 'bad-id' });
        pharos__Log__c log = builder.build();
        System.assertEquals(JSON.serialize(new Set<Id>{ validId }), log.pharos__Related_Objects__c,
            'Should include only valid IDs from List<String>');
    }

    @IsTest
    static void test_triton_level_shorthand_methods() {
        Test.startTest();

        Triton.setTemplate(Triton.makeBuilder()
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community));

        Triton.error(Triton.t.summary('error log'));
        Triton.warning(Triton.t.summary('warning log'));
        Triton.info(Triton.t.summary('info log'));
        Triton.debug(Triton.t.summary('debug log'));
        Triton.fine(Triton.t.summary('fine log'));
        Triton.finer(Triton.t.summary('finer log'));
        Triton.finest(Triton.t.summary('finest log'));

        System.assertEquals(7, Triton.logs.size(), 'All 7 level methods should buffer a log');

        System.assertEquals(TritonTypes.Level.ERROR.name(), Triton.logs[0].Log_Level__c);
        System.assertEquals(TritonTypes.Level.WARNING.name(), Triton.logs[1].Log_Level__c);
        System.assertEquals(TritonTypes.Level.INFO.name(), Triton.logs[2].Log_Level__c);
        System.assertEquals(TritonTypes.Level.DEBUG.name(), Triton.logs[3].Log_Level__c);
        System.assertEquals(TritonTypes.Level.FINE.name(), Triton.logs[4].Log_Level__c);
        System.assertEquals(TritonTypes.Level.FINER.name(), Triton.logs[5].Log_Level__c);
        System.assertEquals(TritonTypes.Level.FINEST.name(), Triton.logs[6].Log_Level__c);

        Test.stopTest();
    }

    @IsTest
    static void test_triton_level_shorthand_overrides_template() {
        Test.startTest();

        Triton.setTemplate(Triton.makeBuilder()
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .level(TritonTypes.Level.DEBUG));

        Triton.error(Triton.t.summary('should be error'));

        System.assertEquals(1, Triton.logs.size());
        System.assertEquals(TritonTypes.Level.ERROR.name(), Triton.logs[0].Log_Level__c,
            'Triton.error() should override template level');

        Test.stopTest();
    }

    @IsTest
    static void test_triton_level_shorthand_persists() {
        TritonTestFactory.assertNoLogs();

        Test.startTest();

        Triton.setTemplate(Triton.makeBuilder()
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community));

        Triton.info(Triton.t.summary('info to persist').details('some details'));
        Triton.error(Triton.t.summary('error to persist').details('error details'));
        Triton.flush();

        Test.stopTest();

        List<pharos__Log__c> persistedLogs = [
            SELECT pharos__Summary__c, Log_Level__c
            FROM pharos__Log__c
            ORDER BY CreatedDate
        ];
        System.assertEquals(2, persistedLogs.size(), 'Both logs should be persisted');

        Set<String> levels = new Set<String>();
        for (pharos__Log__c log : persistedLogs) {
            levels.add(log.Log_Level__c);
        }
        System.assert(levels.contains(TritonTypes.Level.INFO.name()), 'Should contain INFO level log');
        System.assert(levels.contains(TritonTypes.Level.ERROR.name()), 'Should contain ERROR level log');
    }

    @IsTest
    static void test_builder_span_id_explicit() {
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .summary('span test')
            .spanId('explicit-span-id')
            .parentSpanId('explicit-parent-span-id');

        pharos__Log__c log = builder.build();

        System.assertEquals('explicit-span-id', (String) log.get(TritonBuilder.SPAN_ID),
            'Should set explicit span ID');
        System.assertEquals('explicit-parent-span-id', (String) log.get(TritonBuilder.PARENT_SPAN_ID),
            'Should set explicit parent span ID');
    }

    @IsTest
    static void test_builder_span_id_fallback_to_request_id() {
        TritonBuilder builder = Triton.makeBuilder()
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .summary('span fallback test');

        pharos__Log__c log = builder.build();

        String requestId = System.Request.getCurrent().getRequestId();
        System.assertEquals(requestId, (String) log.get(TritonBuilder.SPAN_ID),
            'Should fallback to request ID when no span ID explicitly set');
    }

    @IsTest
    static void test_builder_clone_preserves_span_ids() {
        TritonBuilder original = Triton.makeBuilder()
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .spanId('clone-span')
            .parentSpanId('clone-parent');

        TritonBuilder cloned = original.cloneBuilder();

        System.assertEquals('clone-span', cloned.currentSpanId,
            'Cloned builder should preserve span ID');
        System.assertEquals('clone-parent', cloned.currentParentSpanId,
            'Cloned builder should preserve parent span ID');
    }

    @IsTest
    private static void test_switches_default_enabled() {
        TritonHelper.Config.settings = null;
        System.assertEquals(false, TritonHelper.Config.isLoggingDisabled(),
            'Logging should be enabled by default (org defaults / no record)');
        System.assertEquals(false, TritonHelper.Config.isFlowFlushBatchDisabled(),
            'Flow flush batch should be enabled by default');
    }

    @IsTest
    private static void test_switch_logging_disabled_flag() {
        TritonHelper.Config.settings = new TritonSettings__c(Disable_Logging__c = true);
        System.assertEquals(true, TritonHelper.Config.isLoggingDisabled(),
            'isLoggingDisabled should reflect the Disable_Logging__c flag');
        System.assertEquals(false, TritonHelper.Config.isFlowFlushBatchDisabled(),
            'Flow flush batch flag is independent and defaults false');
    }

    @IsTest
    private static void test_switch_flow_flush_batch_disabled_flag() {
        TritonHelper.Config.settings = new TritonSettings__c(Disable_Flow_Flush_Batch__c = true);
        System.assertEquals(true, TritonHelper.Config.isFlowFlushBatchDisabled(),
            'isFlowFlushBatchDisabled should reflect the Disable_Flow_Flush_Batch__c flag');
        System.assertEquals(false, TritonHelper.Config.isLoggingDisabled(),
            'Logging flag is independent and defaults false');
    }

    @IsTest
    private static void test_operational_knobs_default_when_unset() {
        // No org-default record — getOrgDefaults() returns an empty setting.
        System.assertEquals(300, TritonHelper.Config.getCacheTtlSeconds(),
            'Cache TTL should fall back to the packaged default (300s) when unset');
        System.assertEquals(1, TritonHelper.Config.getFlowFlushBatchDelayMinutes(),
            'Batch delay should fall back to the packaged default (1 min) when unset');
    }

    @IsTest
    private static void test_operational_knobs_read_configured_values() {
        // Knobs are read live from the org-default custom setting, not the cached
        // Config.settings member — so seed a real org-default record.
        upsert new TritonSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Cache_TTL_Minutes__c = 30,
            Flow_Flush_Batch_Delay_Minutes__c = 5
        );
        System.assertEquals(30 * 60, TritonHelper.Config.getCacheTtlSeconds(),
            'Cache TTL should be the configured minutes converted to seconds');
        System.assertEquals(5, TritonHelper.Config.getFlowFlushBatchDelayMinutes(),
            'Batch delay should reflect the configured minutes');
    }

    @IsTest
    private static void test_operational_knobs_negative_falls_back_to_default() {
        upsert new TritonSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Cache_TTL_Minutes__c = -5,
            Flow_Flush_Batch_Delay_Minutes__c = -1
        );
        System.assertEquals(300, TritonHelper.Config.getCacheTtlSeconds(),
            'Negative cache TTL should fall back to the packaged default');
        System.assertEquals(1, TritonHelper.Config.getFlowFlushBatchDelayMinutes(),
            'Negative batch delay should fall back to the packaged default');
    }

    @IsTest
    private static void test_master_switch_disables_apex_logging() {
        TritonTestFactory.assertNoLogs();
        TritonHelper.Config.settings = new TritonSettings__c(Disable_Logging__c = true);

        Test.startTest();
        Triton.logNow(Triton.t
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Accounts)
            .summary('should not persist')
            .level(TritonTypes.Level.INFO));
        Triton.log(Triton.t
            .category(TritonTypes.Category.Apex)
            .summary('buffered should not persist')
            .level(TritonTypes.Level.ERROR));
        Triton.flush();
        Test.stopTest();

        TritonTestFactory.assertNoLogs();
    }

    @IsTest
    private static void test_master_switch_enabled_still_logs() {
        TritonTestFactory.assertNoLogs();
        TritonHelper.Config.settings = new TritonSettings__c(Disable_Logging__c = false);

        Test.startTest();
        Triton.logNow(Triton.t
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Accounts)
            .summary('should persist')
            .level(TritonTypes.Level.INFO));
        Test.stopTest();

        TritonTestFactory.assertLogCount(1);
    }

    @IsTest
    private static void test_master_switch_disables_lwc_logging() {
        TritonTestFactory.assertNoLogs();
        TritonHelper.Config.settings = new TritonSettings__c(Disable_Logging__c = true);

        TritonLwc.ComponentLog cl = new TritonLwc.ComponentLog();
        cl.category = TritonTypes.Category.LWC.name();
        cl.level = TritonTypes.Level.INFO.name();
        cl.summary = 'lwc should not persist';
        cl.componentInfo = new TritonLwc.Component();
        cl.componentInfo.name = 'myCmp';

        Test.startTest();
        TritonLwc.saveComponentLogs(new List<TritonLwc.ComponentLog>{ cl });
        Test.stopTest();

        TritonTestFactory.assertNoLogs();
    }

}