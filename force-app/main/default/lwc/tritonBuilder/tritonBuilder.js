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

const TritonBuilder = class {

    /**
     * Constructor used to generate each log
     */
    constructor() {
        this._setCreatedTimestamp();
        this._setComponentDetails(new Error().stack);
    }

    /**
     * Sets the log Category field
     */
    setLevel(level) {
        if (level) this.level = level;
        return this;
    }

    /**
     * Sets the log Category field
     */
    setCategory(category) {
        if (category) this.category = category;
        return this;
    }

    /**
     * Sets the log Type field
     */
    setType(type) {
        if (type) this.type = type;
        return this;
    }

    /**
     * Sets the log Area field
     */
    setArea(area) {
        if (area) this.area = area;
        return this;
    }

    /**
     * Sets the log Summary field
     */
    setSummary(summary) {
        if (summary) this.summary = summary;
        return this;
    }

    /**
     * Sets the log Details field
     */
    setDetails(details) {
        if (details) this.details = details;
        return this;
    }

    /**
     * Sets the log RecordId field
     */
    setRecordId(recordId) {
        if (recordId) this.recordId = recordId;
        return this;
    }

    /**
     * Sets the log ObjectApiName field
     */
    setObjectApiName(objectApiName) {
        if (objectApiName) this.objectApiName = objectApiName;
        return this;
    }

    /**
     * Sets the transaction Id
     */
    setTransactionId(transactionId) {
        if (transactionId) this.transactionId = transactionId;
        return this;
    }


    /**
     * Sets the component info structure
     */
    setComponent(component) {
        if (component) {
            if (!this.component) this.component = {};
            this.component.name = component.name;
            this.component.function = component.function;
        }
        return this;
    }

    /**
     * Sets the duration value
     */
    setDuration(duration) {
        if (duration) this.duration = duration;
        return this;
    }

    /**
     * Sets created timestamp
     */
    setCreatedTimestamp(startTime) {
        if (startTime) this.createdTimestamp = startTime;
    }

    /**
     * Sets the log Exception field
     */
    setError(error) {
        if (error) {
            this.error = {};
            this.error.message = error.message ? error.message : error.body ? error.body.message : null;
            this.error.stack = error.stack ? error.stack : error.body ? error.body.stackTrace : null;
            this.error.type = error.name ? error.name : error.body ? error.body.exceptionType : null;
            this._setComponentDetails(this.error.stack);
        }
        return this;
    }

    _setCreatedTimestamp() {
        this.createdTimestamp = Date.now();
    }

    _setComponentDetails(stack) {
        if (stack != null) {
            if (!this.component) this.component = {}
            let stackTraceLines = [];
            stack.split('\n').filter(
                stackTraceLine => !stackTraceLine.includes('/c/triton.js') && !stackTraceLine.includes('/c/tritonBuilder.js')
            ).forEach(stackTraceLine => {
                console.log(stackTraceLine);
                if (!this.component.category && (stackTraceLine.includes('/modules/') || stackTraceLine.includes('/components/'))) {
                    this.component.category = stackTraceLine.includes('/modules/') ? 'LWC' : 'Aura';
                    this.component.name = stackTraceLine.substring(stackTraceLine.lastIndexOf('/') + 1, stackTraceLine.lastIndexOf('.js'));
                    this.component.function = stackTraceLine.substring(stackTraceLine.indexOf(this.component.category === 'LWC' ? '.' : 'at ') + (this.component.category === 'LWC' ? 1 : 3), stackTraceLine.lastIndexOf(' ('));
                }
                stackTraceLines.push(stackTraceLine);
            });
            this.stack = stackTraceLines.join('\n');
        }
    }

}

export function makeBuilder() {
    return new TritonBuilder();
}