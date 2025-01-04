/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 *
 * The TritonTypes class provides enums and constants for the Triton logging framework.
 * It defines the classification system used to categorize and filter log entries.
 * 
 * Key components:
 * - Area enum: Defines functional areas from a business perspective (e.g., OpportunityManagement, RestAPI)
 * - Category enum: Provides high-level classification of log entries (e.g., Apex, Flow, Integration)
 * - Level enum: Defines log severity levels from ERROR to FINEST
 * - Type enum: Offers technical classification of log entries (e.g., Backend, Frontend, DMLResult)
 * 
 * These enums are used to populate Category, Type, and Functional Area fields on log records,
 * enabling detailed analytics and filtering capabilities.
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
        DMLResult,
        LongRunningRequest,
        ConcurrentRequestsLimit,
        AccountTrigger
    }
}
