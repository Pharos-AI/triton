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
    @description Triton log for Flows
 */
public with sharing class TritonFlow {

    /**
     * @description
     * Invocable method, that can be called via flow.
     * Defaults to INFO log level
     * @param flowLogs The list of FlowLog instances to save
     */
    @InvocableMethod(Category='TritonLogging' Label='Add Log' Description='Creates a log for a flow or process builder')
    public static void log(List<FlowLog> flowLogs) {
        for (FlowLog flowLog : flowLogs) {
            TritonTypes.Level level = TritonTypes.Level.INFO;
            String flowDetails = flowLog.details;
            try {
                level = TritonTypes.Level.valueOf(flowLog.level);
            } catch (StringException e) {
                flowDetails += '\nUnable to locate log level: ' + flowLog.level + '. Default INFO level will be used.'; 
            }
            
            TritonTypes.Category category = TritonTypes.Category.Flow;
            try {
                category = TritonTypes.Category.valueOf(flowLog.category);
            } catch (StringException e) {
                flowDetails += '\nUnable to locate category: ' + flowLog.category + '. Default Flow category will be used.'; 
            }
            
            //start transaction if one isn't already in progress
            if(Triton.instance.TRANSACTION_ID == null) Triton.instance.startTransaction();
            
            TritonBuilder builder = Triton.makeBuilder();
            builder
                    .category(category)
                    .type(flowLog.type)
                    .area(flowLog.area)
                    .summary(flowLog.summary)
                    .details(flowDetails)
                    .transactionId(Triton.instance.TRANSACTION_ID)
                    .interviewGuid(flowLog.interviewGUID)
                    .flowApiName(flowLog.flowApiName)
                    .level(level);

            if (String.isNotBlank(flowLog.additionalFields)) {
                try {
                    Map<String, Object> mapAdditionalFields = (Map<String, Object>)JSON.deserializeUntyped(flowLog.additionalFields);
                    for (String field : mapAdditionalFields.keySet()) {
                        builder.attribute(field, mapAdditionalFields.get(field));
                    }
                } catch (Exception e) {
                    builder.details(flowDetails + '\nAdditional Information (failed to parse json input to invokable):' + '\n' + flowLog.additionalFields);
                }
            }
            Triton.instance.add(builder.build());
        }
        Triton.instance.flush();
    }


    /**
     * A wrapper class for passing log data from flow
     */
    public class FlowLog {
        @InvocableVariable(Required=true Label='Category')
        public String category;
        @InvocableVariable(Required=true Label='Type')
        public String type;
        @InvocableVariable(Required=true Label='Area')
        public String area;
        @InvocableVariable(Required=true Label='Summary')
        public String summary;
        @InvocableVariable(Required=true Label='Details')
        public String details;
        @InvocableVariable(Required=true Label='Interview GUID')
        public String interviewGUID;
        @InvocableVariable(Required=false Label='Flow API Name')
        public String flowApiName;
        @InvocableVariable(Required=false Label='Level')
        public String level;
        @InvocableVariable(Required=false Label='Additional Fields')
        public String additionalFields;
    }
}
