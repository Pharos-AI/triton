/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import saveComponentLogs from '@salesforce/apex/TritonLwc.saveComponentLogs';
import USER_ID from '@salesforce/user/Id';
import TritonBuilder from 'c/tritonBuilder';
import { isNotTriton, isAura, generateTransactionId, captureRuntimeInfo } from 'c/tritonUtils';

export default class Triton {
    static instance = null;

    /**
     * Buffer to store logs before sending to server
     * @private
     * @type {Array}
     */
    logs = [];

    /**
     * Template builder for reuse
     * @private
     * @type {TritonBuilder}
     */
    template = null;

    category = CATEGORY.LWC;
    
    /**
     * Current transaction ID
     * @private
     * @type {string}
     */
    transactionId = null;

    constructor() {
        if (Triton.instance) {
            return Triton.instance;
        }

        this.transactionManager = new TransactionManager(this);
        if(isAura()) {
            this.category = CATEGORY.AURA;
        }
            
        this.transactionId = this.transactionManager.initialize();
        
        Triton.instance = this;
    }

    /**
     * Generates and stores a new transaction ID (UUID v4)
     * Also starts the auto-flush monitor
     * @returns {string} The generated transaction ID
     */
    startTransaction() {
        this.transactionId = this.transactionManager.start();
        return this.transactionId;
    }

    /**
     * Resumes a transaction using an existing transaction ID
     * Also starts the auto-flush monitor
     * @param {string} transactionId - Existing transaction ID to resume
     */
    resumeTransaction(transactionId) {
        this.transactionId = this.transactionManager.resume(transactionId);
    }

    /**
     * Stops the current transaction and auto-flush monitor
     * Flushes any remaining logs
     */
    stopTransaction() {
        this.transactionManager.stop();
        this.transactionId = null;
    }

    /**
     * Creates an error log from an Exception
     * @param {Error} error - JavaScript Error object to log
     * @returns {void}
     */
    exception(error) {
        return this.makeBuilder()
                        .exception(error)
                        .level(LEVEL.ERROR)
    }

    /**
     * Creates an error level log
     * @param {string} type - Log type from TYPE enum
     * @param {string} area - Log area from AREA enum
     * @returns {void}
     */
    error(type, area) {
        return this.makeBuilder()
            .level(LEVEL.ERROR)
            .type(type)
            .area(area)
    }

    /**
     * Creates a warning level log
     * @param {string} type - Log type from TYPE enum
     * @param {string} area - Log area from AREA enum
     * @returns {void}
     */
    warning(type, area) {
        return this.makeBuilder()
            .level(LEVEL.WARNING)
            .type(type)
            .area(area)
    }

    /**
     * Creates a debug level log
     * @param {string} type - Log type from TYPE enum
     * @param {string} area - Log area from AREA enum
     * @returns {void}
     */
    debug(type, area) {
        return this.makeBuilder()
            .level(LEVEL.DEBUG)
            .type(type)
            .area(area)
    }

    /**
     * Creates an info level log
     * @param {string} type - Log type from TYPE enum
     * @param {string} area - Log area from AREA enum
     * @returns {void}
     */
    info(type, area) {
        return this.makeBuilder()
            .level(LEVEL.INFO)
            .type(type)
            .area(area)
    }

    /**
     * Flushes all logs in the buffer to the server
     * @returns {Promise} Promise that resolves when logs are successfully saved
     * @throws {Error} If there's an error saving the logs
     */
    async flush() {
        if(this.logs.length === 0) {
            console.log('No logs to flush');
            return;
        }

        // Take a snapshot of current logs
        const logsToFlush = [...this.logs];
        this.logs = [];

        try {
            const data = await saveComponentLogs({
                componentLogs: logsToFlush
            });
            
            console.log('Logs flushed successfully:', data);
            return data;
        } catch (error) {
            // On error, add back the logs that failed to flush
            // but append them to any new logs that might have been added
            this.logs = [...this.logs, ...logsToFlush];
            console.error(error);
            throw error;
        }
    }

    /**
     * Sets a builder template that can be re-used
     * @param {TritonBuilder} builder - Builder to be used as template
     */
    setTemplate(builder) {
        this.template = builder;
    }

    /**
     * Creates a new builder from the saved template
     * If no template exists, creates a new builder with default settings
     * @returns {TritonBuilder} New builder instance
     */
    fromTemplate() {
        if (this.template) {
            // Clone the template and set transaction-specific properties
            const builder = Object.assign(new TritonBuilder(), this.template);
            return builder
                .transactionId(this.transactionId)
                .timestamp(Date.now());
        }
        return this.makeBuilder();
    }

    /**
     * Adds a log to the buffer
     * @param {TritonBuilder} builder - Builder instance to add to the buffer
     * @returns {TritonBuilder} The builder instance for chaining
     */
    log(builder) {
        this.logs.push(builder);
        return builder;
    }

    /**
     * Immediately flushes a single log builder
     * @param {TritonBuilder} builder - Builder instance to log
     * @returns {Promise} Promise that resolves when the log is flushed
     */
    async logNow(builder) {
        const currentLogs = [...this.logs];
        this.logs = [builder];
        
        try {
            const data = await this.flush();
            // Add back any logs that were buffered during flush
            this.logs.push(...currentLogs);  
            return data;
        } catch (error) {
            // Also preserve logs on error
            this.logs.push(...currentLogs);  
            throw error;
        }
    }

    /**
     * Creates a new builder from the saved template or default settings
     * @private
     * @returns {TritonBuilder} New builder instance
     */
    makeBuilder() {
        let builder = new TritonBuilder();
        const componentStack = new Error().stack;
        
        builder.category(this.category)
            .userId(USER_ID)
            .timestamp(Date.now())
            .componentDetails(componentStack)
            .transactionId(this.transactionId);
        
        try {
            builder.runtimeInfo(captureRuntimeInfo());
        } catch (error) {
            console.warn('Error capturing runtime details:', error);
        }
        
        return builder;
    }
}

/**
 * Enumeration of available log areas
 * @enum {string}
 */
export const AREA = {
    ACCOUNTS: 'ACCOUNTS',
    COMMUNITY: 'COMMUNITY',
    LEAD_CONVERSION: 'LEAD_CONVERSION',
    OPPORTUNITY_MANAGEMENT: 'OPPORTUNITY_MANAGEMENT',
    REST_API: 'REST_API'
};

/**
 * Enumeration of available log categories
 * @enum {string}
 */
export const CATEGORY = {
    LWC: 'LWC',
    AURA: 'Aura',
    WARNING: 'Warning',
    DEBUG: 'Debug',
    EVENT: 'Event'
};

/**
 * Enumeration of available log levels
 * @enum {string}
 */
export const LEVEL = {
    ERROR: 'ERROR',
    WARNING: 'WARNING',
    INFO: 'INFO',
    DEBUG: 'DEBUG',
    FINE: 'FINE',
    FINER: 'FINER',
    FINEST: 'FINEST'
};

/**
 * Enumeration of available log types
 * @enum {string}
 */
export const TYPE = {
    BACKEND: 'Backend',
    FRONTEND: 'Frontend'
};

/**
 * Manages transaction lifecycle and storage
 * @private
 */
class TransactionManager {
    static STORAGE_KEY = 'tritonTransactionId';
    static AUTO_FLUSH_CHECK_INTERVAL = 10000; // 10 seconds
    static AUTO_FLUSH_DELAY = 60000; // 1 minute

    constructor(triton) {
        this.triton = triton; // Reference to parent Triton instance for accessing logs
    }

    /**
     * Initializes transaction management
     * Either resumes existing transaction or starts new one
     * @returns {string} Active transaction ID
     */
    initialize() {
        const storedId = sessionStorage.getItem(TransactionManager.STORAGE_KEY);
        if (storedId) {
            return this.resume(storedId);
        }
        return this.start();
    }

    /**
     * Starts a new transaction
     * @returns {string} New transaction ID
     */
    start() {
        const newId = generateTransactionId();
        sessionStorage.setItem(TransactionManager.STORAGE_KEY, newId);
        this.startAutoFlushMonitor();
        return newId;
    }

    /**
     * Resumes an existing transaction
     * @param {string} transactionId - Transaction ID to resume
     * @returns {string} Resumed transaction ID
     */
    resume(transactionId) {
        sessionStorage.setItem(TransactionManager.STORAGE_KEY, transactionId);
        this.startAutoFlushMonitor();
        return transactionId;
    }

    /**
     * Stops current transaction and monitoring
     */
    stop() {
        this.stopAutoFlushMonitor();
        this.triton.flush();
        sessionStorage.removeItem(TransactionManager.STORAGE_KEY);
    }

    /**
     * Starts monitoring the logs array for auto-flushing
     * @private
     */
    async startAutoFlushMonitor() {
        this.isMonitoring = true;
        
        while (this.isMonitoring) {
            await new Promise(resolve => setTimeout(resolve, TransactionManager.AUTO_FLUSH_CHECK_INTERVAL));
            
            if (!this.isMonitoring) break;
            
            const now = Date.now();
            if (this.triton.logs.length > 0) {
                const lastLog = this.triton.logs[this.triton.logs.length - 1];
                const lastLogTime = lastLog.createdTimestamp;
                
                if ((now - lastLogTime) >= TransactionManager.AUTO_FLUSH_DELAY) {
                    await this.triton.flush();
                }
            }
        }
    }

    /**
     * Stops the auto-flush monitor
     * @private
     */
    stopAutoFlushMonitor() {
        this.isMonitoring = false;
    }
}