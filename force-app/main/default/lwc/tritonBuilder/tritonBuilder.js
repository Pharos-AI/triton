/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import { isNotTriton, isLWCLine, isComponentLine } from 'c/tritonUtils';

export default class TritonBuilder {

    /**
     * Sets the log level
     * @param {string} level - Log level to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    level(level) {
        this.level = level;
        return this;
    }

    /**
     * Sets the log category
     * @param {string} category - Log category to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    category(category) {
        this.category = category;
        return this;
    }

    /**
     * Sets the log type
     * @param {string} type - Log type to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    type(type) {
        this.type = type;
        return this;
    }

    /**
     * Sets the log area
     * @param {string} area - Log area to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    area(area) {
        this.area = area;
        return this;
    }

    /**
     * Sets the log summary
     * @param {string} summary - Log summary to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    summary(summary) {
        this.summary = summary;
        return this;
    }

    /**
     * Sets the log details
     * @param {string} details - Log details to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    details(details) {
        this.details = details;
        return this;
    }

    /**
     * Sets the transaction ID
     * @param {string} transactionId - Transaction ID to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    transactionId(transactionId) {
        this.transactionId = transactionId;
        return this;
    }

    /**
     * Sets the component information
     * @param {Object} component - Component information object
     * @returns {TritonBuilder} Builder instance for chaining
     */
    componentInfo(component) {
        this.component = component;
        return this;
    }

    /**
     * Sets the duration value
     * @param {number} duration - Duration in milliseconds
     * @returns {TritonBuilder} Builder instance for chaining
     */
    duration(duration) {
        this.duration = duration;
        return this;
    }

    /**
     * Sets the created timestamp
     * @param {number} [timestamp] - Optional timestamp to set (defaults to current time)
     * @returns {TritonBuilder} Builder instance for chaining
     */
    timestamp(timestamp) {
        this.createdTimestamp = timestamp;
        return this;
    }

    /**
     * Sets the error information
     * @param {Error|Object} error - Error object to process
     * @returns {TritonBuilder} Builder instance for chaining
     */
    exception(error) {
        this.error = {};

        if (error.body) {
            this.error.message = error.body.message;
            this.error.stack = error.body.stackTrace;
            this.error.type = error.body.exceptionType;
        } else {
            this.error.message = error.message ? error.message : null;
            this.error.stack = error.stack ? error.stack : error.stacktrace ? error.stacktrace : null;
            this.error.type = error.name ? error.name : error.body ? error.body.exceptionType : null;
        }
        this.componentDetails(this.error.stack);
        if (!this.details) this.details = this.error.message + '\n\n' + this.stack;
        return this;
    }

    /**
     * Extracts and sets component details from stack trace
     * @param {string} stack - Stack trace to process
     * @returns {TritonBuilder} Builder instance for chaining
     */
    componentDetails(stack) {
        if (!this.component) this.component = {};
        
        // Filter and process stack trace
        const stackTraceLines = (stack || '')
            .split(/\r?\n/)  // Handles both \n and \r\n line endings
            .filter(line => isNotTriton(line));
        
        // Find first component line for metadata
        const componentLine = stackTraceLines.find(line => isComponentLine(line));

        if (componentLine) {
            const isLWC = isLWCLine(componentLine);

            // Extract component name (everything between last / and .js)
            this.component.name = componentLine.substring(
                componentLine.lastIndexOf('/') + 1, 
                componentLine.lastIndexOf('.js')
            );

            // Extract function name based on stack trace format
            const functionStartIndex = componentLine.indexOf(isLWC ? 'at ' : '.') + (isLWC ? 3 : 1);
            const functionEndIndex = componentLine.lastIndexOf(' (');
            this.component.function = componentLine
                .substring(functionStartIndex, functionEndIndex)
                .trim();
        }

        // Join filtered lines back into stack trace
        this.stack = stackTraceLines.join('\n');
        return this;
    }

    /**
     * Sets the user ID
     * @param {string} userId - User ID to set
     * @returns {TritonBuilder} Builder instance for chaining
     */
    userId(userId) {
        this.userId = userId;
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
            this.relatedObjectIds = validIds;
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
    runtimeInfo(info = {}) {
        this.runtime = info;
        return this;
    }

}
