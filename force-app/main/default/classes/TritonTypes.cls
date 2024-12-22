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
    @description Class used to store Enums for the Triton Logger
    * Log classification.
    * Use these enums to provide values for Category, Type and Functional Area fields on the log record.
    * These fields are useful for analytics and should be populated on all records.
    * Feel free to modify these or add new values as you see fit. It is best to stick to the
    * general spirit of the definition.
 */
public with sharing class TritonTypes {

    /**
    * Area.
    * Represents the functional area. This value will be written to the Functional Area field.
    * These values should represent the functional area from a business perspective.
    * E.g. DealRegistration, PartnerCommunity, CustomPipelineUI.
    */
    public enum Area {
        OpportunityManagement,
        LeadConversion,
        Community,
        RestAPI,
        Accounts,
        LWC,
        Flow
    }

    /**
    * Category.
    * Provides general classification. Defaults are Error, Warning, Event, Debug.
    * This value will be written to the Category field.
    * These values should reflect what kind of log entry they represent at a high level.
    */
    public enum Category {
        Apex,
        Flow,
        LWC,
        Aura,
        Warning,
        Event,
        Debug,
        Integration
    }
    /**
    * Log Levels.
    * Values listed from the least verbose to the most verbose
    */
    public enum Level {
        ERROR,
        WARNING,
        INFO,
        DEBUG,
        FINE,
        FINER,
        FINEST
    }

    /**
    * Type.
    * Provides a more specific classification. This value will be written to the Type field.
    * Defaults are Backend and Frontend.
    * This value represents a more specific technical classification.
    * When an Exception is provided, the methods below will use the Exception type.
    */
    public enum Type {
        Backend,
        Frontend,
        LongRunningRequest,
        ConcurrentRequestsLimit,
        AccountTrigger
    }
}
