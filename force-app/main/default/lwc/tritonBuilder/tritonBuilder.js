/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import { isNotTriton, getFunctionName } from 'c/tritonUtils';

export default class TritonBuilder {

    /**
     * Sets the log level
     * @param {string} level - Log level to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    level(level) {
        this._level = level;
        return this;
    }

    /**
     * Sets the log category
     * @param {string} category - Log category to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    category(category) {
        this._category = category;
        return this;
    }

    /**
     * Sets the log type
     * @param {string} type - Log type to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    type(type) {
        this._type = type;
        return this;
    }

    /**
     * Sets the log area
     * @param {string} area - Log area to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    area(area) {
        this._area = area;
        return this;
    }

    /**
     * Sets the log summary
     * @param {string} summary - Log summary to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    summary(summary) {
        this._summary = summary;
        return this;
    }

    /**
     * Sets the log details
     * @param {string} details - Log details to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    details(details) {
        this._details = details;
        return this;
    }

    /**
     * Sets the transaction ID
     * @param {string} transactionId - Transaction ID to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    transactionId(transactionId) {
        this._transactionId = transactionId;
        return this;
    }

    /**
     * Sets the duration value
     * @param {number} duration - Duration in milliseconds
     * @returns {TritonBuilder} Builder instance for chaining
     */
    duration(duration) {
        this._duration = duration;
        return this;
    }

    /**
     * Sets the created timestamp
     * @param {number} [timestamp] - Optional timestamp to set (defaults to current time)
     * @returns {TritonBuilder} Builder instance for chaining
     */
    timestamp(timestamp) {
        this._createdTimestamp = timestamp;
        return this;
    }

    /**
     * Sets the error information
     * @param {Error|Object} error - Error object to process
     * @returns {TritonBuilder} Builder instance for chaining
     */
    exception(error) {
        this._error = {};

        if (error.body) {
            this._error.message = error.body.message;
            this._error.stack = error.body.stackTrace;
            this._error.type = error.body.exceptionType;
        } else {
            this._error.message = error.message ? error.message : null;
            this._error.stack = error.stack ? error.stack : error.stacktrace ? error.stacktrace : null;
            this._error.type = error.name ? error.name : error.body ? error.body.exceptionType : null;
        }

        this.componentDetails(this._error.stack);
        this._details = (this._details || '') + this._error.message;
        this._summary = (this._summary || this._error.message);
        return this;
    }

    /**
     * Extracts and sets component details from stack trace
     * @param {string} stack - Stack trace to process
     * @returns {TritonBuilder} Builder instance for chaining
     */
    componentDetails(stack) {
        if(!this._componentInfo) {
            this._componentInfo = {};
        }
        // Filter and process stack trace
        const stackTraceLines = (stack || '')
            .split(/\r?\n/) 
            .filter(line => isNotTriton(line));
        
        if(stackTraceLines.length > 1) {
            //skip the first line as it is the error message
            this._componentInfo.function = getFunctionName(stackTraceLines[1]);
            // reconstruct the stack trace without the error message
            this._stack = stackTraceLines.slice(1).join('\n');                                               
        } else {
            this._componentInfo.function = '';
        }

        return this;
    }

    /**
     * Sets the user ID
     * @param {string} userId - User ID to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    userId(userId) {
        this._userId = userId;
        return this;
    }

    /**
     * Adds related object(s) to the log
     * @param {string|string[]} objectIds - Single ID or array of IDs to relate to the log
     * @returns {TritonBuilder} Builder instance for chaining
     */
    relatedObjects(objectIds) {
        if (!objectIds) return this;

        // Convert single ID to array
        const idsArray = Array.isArray(objectIds) ? objectIds : [objectIds];
        
        // Filter out any null/undefined/empty values
        const validIds = idsArray.filter(id => id);
        
        if (validIds.length > 0) {
            this._relatedObjectIds = validIds;
        }
        
        return this;
    }

    /**
     * Creates a deep clone of the builder
     * @returns {TritonBuilder} New builder instance with copied properties
     */
    clone() {
        const newBuilder = new TritonBuilder();
        
        // Copy all properties except functions
        Object.keys(this).forEach(key => {
            if (this[key] !== undefined && typeof this[key] !== 'function') {
                // Handle objects that need deep cloning
                if (this[key] && typeof this[key] === 'object') {
                    newBuilder[key] = { ...this[key] };
                } else {
                    newBuilder[key] = this[key];
                }
            }
        });
        
        return newBuilder;
    }

    /**
     * Sets runtime information
     * @param {Object} info - Object containing all runtime details
     * @returns {TritonBuilder} Builder instance for chaining
     */
    runtimeInfo(runtimeInfo = {}) {
        this._runtimeInfo = runtimeInfo;
        return this;
    }

    /**
     * Builds the final log object from the builder properties
     * @returns {Object} The constructed log object
     */
    build() {
        return {
            level: this._level,
            category: this._category,
            type: this._type,
            area: this._area,
            summary: this._summary,
            details: this._details,
            transactionId: this._transactionId,
            componentInfo: this._componentInfo,
            duration: this._duration,
            createdTimestamp: this._createdTimestamp,
            error: this._error,
            stack: this._stack,
            userId: this._userId,
            runtimeInfo: this._runtimeInfo,
            relatedObjectIds: this._relatedObjectIds
        };
    }

}