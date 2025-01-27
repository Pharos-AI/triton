/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import {makeBuilder} from 'c/tritonBuilder';
import saveComponentLogs from '@salesforce/apex/TritonLwc.saveComponentLogs';

const Triton =  class {

    /**
     * Logs buffer
     */
    logs = [];

    /**
     * Add Log with LWC / Aura Category.
     * This method will automatically get the stacktrace from Exception.
     * Type will be obtained from Exception. If blank, a default Frontend Type will be saved
     * Summary is the Exception message.
     * Details will be a combination of Exception String and stacktrace
     */
    addException(error) {
        return this._makeBuilder().setError(error).setLevel(LEVEL.ERROR);
    }

    /**
     * Add Log with LWC / Aura Category.
     */
    addError() {
        return this._makeBuilder().setLevel(LEVEL.ERROR);
    }

    /**
     * Add Log with Warning Category.
     */
    addWarning() {
        return this._makeBuilder().setCategory(CATEGORY.WARNING).setLevel(LEVEL.WARNING);
    }

    /**
     * Add Log with Debug Category.
     */
    addDebug() {
        return this._makeBuilder().setCategory(CATEGORY.DEBUG).setLevel(LEVEL.DEBUG);
    }

    /**
     * Add Log with Event Category.
     */
    addInfo() {
        return this._makeBuilder().setCategory(CATEGORY.EVENT).setLevel(LEVEL.INFO);
    }

    /**
     * Save Log with LWC / Aura Category.
     * This method will automatically get the stacktrace from Exception.
     * Type will be obtained from Exception. If blank, a default Frontend Type will be saved
     * Summary is the Exception message.
     * Details will be a combination of Exception String and stacktrace
     */
    exception(error, transactionId) {
        this._makeBuilder()
            .setError(error)
            .setLevel(LEVEL.ERROR)
            .setTransactionId(transactionId);
        this.flush();
    }

    /**
     * Save Log with LWC / Aura Category.
     */
    error(type, area, summary, details, transactionId, component, duration, startTime) {
        this._makeBuilder()
            .setLevel(LEVEL.ERROR)
            .setType(type)
            .setArea(area)
            .setSummary(summary)
            .setDetails(details)
            .setTransactionId(transactionId)
            .setComponent(component)
            .setDuration(duration)
            .setCreatedTimestamp(startTime);
        this.flush();
    }

    /**
     * Save Log with Warning Category.
     */
    warning(type, area, summary, details, transactionId, component, duration, startTime) {
        this._makeBuilder()
            .setLevel(LEVEL.WARNING)
            .setCategory(CATEGORY.WARNING)
            .setType(type)
            .setArea(area)
            .setSummary(summary)
            .setDetails(details)
            .setTransactionId(transactionId)
            .setComponent(component)
            .setDuration(duration)
            .setCreatedTimestamp(startTime);
        this.flush();
    }

    /**
     * Save Log with Debug Category.
     */
    debug(type, area, summary, details, transactionId, component, duration, startTime) {
        this._makeBuilder()
            .setLevel(LEVEL.DEBUG)
            .setCategory(CATEGORY.DEBUG)
            .setType(type)
            .setArea(area)
            .setSummary(summary)
            .setDetails(details)
            .setTransactionId(transactionId)
            .setComponent(component)
            .setDuration(duration)
            .setCreatedTimestamp(startTime);
        this.flush();
    }

    /**
     * Save Log with Event Category.
     */
    info(type, area, summary, details, level, transactionId, component, duration, startTime) {
        this._makeBuilder()
            .setLevel(level)
            .setCategory(CATEGORY.EVENT)
            .setType(type)
            .setArea(area)
            .setSummary(summary)
            .setDetails(details)
            .setTransactionId(transactionId)
            .setComponent(component)
            .setDuration(duration)
            .setCreatedTimestamp(startTime);
        this.flush();
    }

    /**
     * Commit all logs previously added using the addXXX() methods.
     */
    flush() {
        saveComponentLogs({
            componentLogs: this.logs
        }).then((data) => {
        }).catch(error => {
            console.error(error);
        });
        this.logs = [];
    }

    _makeBuilder() {
        let logBuilder = makeBuilder();
        this.logs.push(logBuilder);
        return logBuilder;
    }

}

/** AREA */
export const AREA = {
    ACCOUNTS: 'ACCOUNTS',
    COMMUNITY: 'COMMUNITY',
    LEAD_CONVERSION: 'LEAD_CONVERSION',
    OPPORTUNITY_MANAGEMENT: 'OPPORTUNITY_MANAGEMENT',
    REST_API: 'REST_API'
};

/** LOG CATEGORY */
export const CATEGORY = {
    LWC: 'LWC',
    AURA: 'Aura',
    WARNING: 'Warning',
    DEBUG: 'Debug',
    EVENT: 'Event'
};

/** LOG LEVEL */
export const LEVEL = {
    ERROR: 'ERROR',
    WARNING: 'WARNING',
    INFO: 'INFO',
    DEBUG: 'DEBUG',
    FINE: 'FINE',
    FINER: 'FINER',
    FINEST: 'FINEST'
};

/** LOG TYPE */
export const TYPE = {
    BACKEND: 'Backend',
    FRONTEND: 'Frontend'
};

export default Triton;