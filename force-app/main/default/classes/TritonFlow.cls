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
 * Provides logging capabilities for Salesforce Flows and Process Builder.
 * This class exposes an invocable method that can be called directly from Flow Builder
 * to create log records with customizable attributes like category, type, area, and level.
 * 
 * The class handles:
 * - Log creation with default INFO level if not specified
 * - Automatic transaction management
 * - Custom field mapping through JSON
 * - Flow context capture (Interview GUID, Flow API Name)
 * - Validation and fallback for category and log level enums
 */
global with sharing class TritonFlow {
    private static final String INVALID_LOG_LEVEL = 'Unable to locate log level: {0}. Default INFO level will be used.';
    private static final String INVALID_CATEGORY = 'Unable to locate category: {0}. Default Flow category will be used.';
    
    /**
     * @description
     * Invocable method, that can be called via flow.
     * Defaults to INFO log level
     * @param flowLogs The list of FlowLog instances to save
     * @return List<FlowLogOutput> The list of FlowLogOutput instances to save
     */
    @InvocableMethod(Category='TritonLogging' 
                    Label='Log' 
                    Description='Creates a log for a flow or process builder')
    public static List<FlowLogOutput> log(List<FlowLog> flowLogs) {
        List<FlowLogOutput> flowLogOutputs = new List<FlowLogOutput>();
        for (FlowLog flowLog : flowLogs) {
            FlowLogOutput result = processFlowLog(flowLog);
            flowLogOutputs.add(result);
        }
        Triton.instance.flush();
        return flowLogOutputs;
    }
    
    @TestVisible
    private static FlowLogOutput processFlowLog(FlowLog flowLog) {
        FlowLogOutput result = new FlowLogOutput();

        result.fullStacktrace = (String.isNotBlank(flowLog?.fullStacktrace)) ? 
                                    flowLog.fullStacktrace + flowLog?.stacktrace : 
                                    flowLog?.stacktrace;
                                    
        TritonTypes.Level level = TritonTypes.Level.INFO;
        String flowDetails = flowLog.details;
        
        try {
            level = TritonTypes.Level.valueOf(flowLog.level);
        } catch (Exception e) {
            flowDetails += Triton.SPACE_SEP + TritonHelper.formatMessage(INVALID_LOG_LEVEL, flowLog.level);
        }
        
        TritonTypes.Category category = TritonTypes.Category.Flow;
        try {
            category = TritonTypes.Category.valueOf(flowLog.category);
        } catch (Exception e) {
            if(String.isNotBlank(flowLog.category)) {
                flowDetails += Triton.SPACE_SEP + TritonHelper.formatMessage(INVALID_CATEGORY, flowLog.category);
            }
        }
        
        //resume or start transaction if one isn't already in progress
        if(String.isNotBlank(flowLog.transactionId)) {
            Triton.instance.resumeTransaction(flowLog.transactionId);
        } else if(Triton.instance.TRANSACTION_ID == null) {
            Triton.instance.startTransaction();
        }
                
        TritonBuilder builder = Triton.makeBuilder();
        builder
                .category(category)
                .type(flowLog.type)
                .area(flowLog.area)
                .summary(flowLog.summary)
                .details(flowDetails)
                .interviewGuid(flowLog.interviewGUID)
                .flowApiName(flowLog.flowApiName)
                .operation(flowLog.operation)
                .stacktrace(result.fullStacktrace)
                .postProcessing(Triton.makePostProcessingBuilder()
                                    .stackTrace(true)
                                    .userInfo(true)
                                    .relatedObjects(true)
                                    .installedPackages(true)
                                    .pendingJobs(true)
                                    .totalActiveSession(true))
                .level(level);

        // if the log level is ERROR, create an issue
        if(level == TritonTypes.Level.ERROR) {
            builder.createIssue();
        }

        if (String.isNotBlank(flowLog.additionalFields)) {
            try {
                Map<String, Object> mapAdditionalFields = (Map<String, Object>)JSON.deserializeUntyped(flowLog.additionalFields);
                for (String field : mapAdditionalFields.keySet()) {
                    builder.attribute(field, mapAdditionalFields.get(field));
                }
            } catch (Exception e) {
                builder.details(flowDetails + Triton.SPACE_SEP + 
                    TritonHelper.formatMessage(
                        'Additional Information (failed to parse json input to invokable): {0}', 
                        flowLog.additionalFields));
            }
        }
        Triton.instance.addLog(builder);
        return result;
    }


    /**
     * A wrapper class for passing log data from flow
     */
    global class FlowLog {
        @InvocableVariable(Required=false Label='Category')
        global String category;
        @InvocableVariable(Required=false Label='Type')
        global String type;
        @InvocableVariable(Required=true Label='Area')
        global String area;
        @InvocableVariable(Required=false Label='Operation')
        global String operation;
        @InvocableVariable(Required=true Label='Summary')
        global String summary;
        @InvocableVariable(Required=false Label='Details')
        global String details;
        @InvocableVariable(Required=true Label='Interview GUID')
        global String interviewGUID;
        @InvocableVariable(Required=false Label='Flow API Name')
        global String flowApiName;
        @InvocableVariable(Required=false Label='Level')
        global String level;
        @InvocableVariable(Required=false Label='Transaction ID')
        global String transactionId;
        @InvocableVariable(Required=false Label='Additional Fields')
        global String additionalFields;
        @InvocableVariable(Required=false Label='Stacktrace')
        global String stacktrace;
        @InvocableVariable(Required=false Label='Full Stacktrace')
        global String fullStacktrace; 
    }

    /**
     * A wrapper class for returning log data from flow
     */
    global class FlowLogOutput {
        @InvocableVariable(Required=false Label='Stacktrace')
        global String stacktrace;
        @InvocableVariable(Required=false Label='Full Stacktrace')
        global String fullStacktrace;
    }
}