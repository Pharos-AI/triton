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
            Pharos.LogBuilder builder = Triton.makeBuilder();
            builder
                    .category(TritonTypes.Category.Flow.name())
                    .type(flowLog.type)
                    .area(flowLog.area)
                    .summary(flowLog.summary)
                    .details(flowLog.details)
                    .transactionId(Triton.instance.TRANSACTION_ID)
                    .attribute(Triton.INTERVIEW_GUID, flowLog.interviewGUID)
                    .attribute(Triton.LOG_LEVEL, TritonTypes.Level.INFO.name());

            if (String.isNotBlank(flowLog.additionalFields)) {
                try {
                    Map<String, Object> mapAdditionalFields = (Map<String, Object>)JSON.deserializeUntyped(flowLog.additionalFields);
                    for (String field : mapAdditionalFields.keySet()) {
                        builder.attribute(field, mapAdditionalFields.get(field));
                    }
                } catch (Exception e) {
                    builder.details(flowLog.details + '\nAdditional Information (failed to parse json input to invokable):' + '\n' + flowLog.additionalFields);
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
        @InvocableVariable(Required=false Label='Additional Fields')
        public String additionalFields;
    }
}
