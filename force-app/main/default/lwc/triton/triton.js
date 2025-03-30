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
import { generateTransactionId, captureRuntimeInfo } from 'c/tritonUtils';

// Create a shared instance in module scope
let instance = null;

export default class Triton {
    /**
     * Buffer to store logs before sending to server
     * @private
     * @type {Array}
     */
    logs = [];

    /**
     * Map to store component-specific templates
     * @private
     * @type {Map<string, TritonBuilder>}
     */
    templates = new Map();

    category = CATEGORY.LWC;
    
    /**
     * Current transaction ID
     * @private
     * @type {string}
     */
    transactionId = null;

    constructor() {
        if (instance) {
            return instance;
        }
        this.transactionManager = new TransactionManager(this);        
        this.transactionId = this.transactionManager.initialize();
        
        instance = this;
        return instance;
    }

    /**
     * Binds logger methods to a specific component context
     * @param {string} componentId - Unique component ID
     * @returns {Proxy} Scoped logger instance
     */
    bindToComponent(componentId) {
        const self = this;
        return new Proxy(this, {
            get(target, prop, receiver) {
                if (prop === '_componentId') return componentId;

                if (prop === 'setTemplate') {
                    return (builder) => self.templates.set(componentId, builder);
                }
                if (prop === 'fromTemplate') {
                    return () => {
                        const template = self.templates.get(componentId);
                        if (template) {
                            const builder = Object.assign(new TritonBuilder(), template);
                            return self.refreshBuilder(builder);
                        }
                        return self.makeBuilder();
                    };
                }
                // default behavior for all other methods
                return Reflect.get(target, prop, receiver);
            }
        });
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
     * Sends all buffered logs to the server and clears the buffer
     * @returns {Promise} Promise that resolves when logs are flushed
     */
    async flush() {
        if(this.logs.length === 0) {
            return;
        }

        // Save current logs and clear buffer to prevent duplicates
        const logsToFlush = [...this.logs];
        this.logs = [];

        try {
            const data = await saveComponentLogs({
                componentLogs: logsToFlush.map(builder => builder.build())
            });
            return data;
        } catch (error) {
            console.error('Error flushing logs:', error);
            // Restore logs that failed to flush
            this.logs.unshift(...logsToFlush);
            throw error;
        }
    }

    /**
     * Adds a log builder to the buffer
     * @param {TritonBuilder} builder - Builder instance to log
     * @returns {TritonBuilder} The builder instance
     */
    log(builder) {
        builder.componentDetails(new Error().stack);
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
        this.logs = [];
        this.log(builder);
        
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
     * Creates a new builder with default settings
     * @returns {TritonBuilder} New builder instance
     */
    makeBuilder() {
        return this.refreshBuilder(new TritonBuilder())
            .userId(USER_ID)
            .category(this.category);
    }

    refreshBuilder(builder) {
        if (this._componentId) {
            builder._componentInfo = {name: this._componentId, function: ''};
        }
        return builder
            .runtimeInfo(captureRuntimeInfo())
            .transactionId(this.transactionId)
            .timestamp(Date.now());
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
    static AUTO_FLUSH_CHECK_INTERVAL = 5000; // 10 seconds
    static AUTO_FLUSH_DELAY = 10000; // 1 minute

    constructor(triton) {
        this.triton = triton;
        this._transactionId = null; // Memory storage fallback
    }

    /**
     * Safely gets item from storage
     * @private
     * @returns {string|null}
     */
    getItem() {
        try {
            return sessionStorage.getItem(TransactionManager.STORAGE_KEY);
        } catch (e) {
            console.log('Error getting item from storage', e);
            return this._transactionId;
        }
    }

    /**
     * Safely sets item in storage
     * @private
     */
    setItem(value) {
        try {
            sessionStorage.setItem(TransactionManager.STORAGE_KEY, value);
        } catch (e) {
            console.log('Error setting item in storage', e);
            // Fallback to memory storage
        }
        this._transactionId = value;
    }

    /**
     * Safely removes item from storage
     * @private
     */
    removeItem() {
        try {
            sessionStorage.removeItem(TransactionManager.STORAGE_KEY);
        } catch (e) {
            // Fallback to memory storage   
            console.log('Error removing item from storage', e);
        }
        this._transactionId = null;
    }

    /**
     * Initializes transaction management
     * Either resumes existing transaction or starts new one
     * @returns {string} Active transaction ID
     */
    initialize() {
        const storedId = this.getItem();
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
        this.setItem(newId);
        this.startAutoFlushMonitor();
        return newId;
    }

    /**
     * Resumes an existing transaction
     * @param {string} transactionId - Transaction ID to resume
     * @returns {string} Resumed transaction ID
     */
    resume(transactionId) {
        this.setItem(transactionId);
        this.startAutoFlushMonitor();
        return transactionId;
    }

    /**
     * Stops current transaction and monitoring
     */
    stop() {
        this.stopAutoFlushMonitor();
        this.triton.flush();
        this.removeItem();
    }

    /**
     * Starts monitoring the logs array for auto-flushing
     * @private
     */
    async startAutoFlushMonitor() {
        // Clear any existing monitor
        this.stopAutoFlushMonitor();
        
        this.isMonitoring = true;
        
        const checkAndFlush = async () => {
            if (!this.isMonitoring) return;

            try {
                const now = Date.now();
                if (this.triton?.logs?.length > 0) {
                    const lastLog = this.triton.logs[this.triton.logs.length - 1];
                    const lastLogTime = lastLog._createdTimestamp;
                    
                    if ((now - lastLogTime) >= TransactionManager.AUTO_FLUSH_DELAY) {
                        await this.triton.flush();
                    }
                }
            } catch (error) {
                console.error('Error in auto-flush monitor:', error);
            }

            // Schedule next check if still monitoring
            if (this.isMonitoring) {
                setTimeout(checkAndFlush, TransactionManager.AUTO_FLUSH_CHECK_INTERVAL);
            }
        };

        // Start the monitoring loop
        checkAndFlush();
    }

    /**
     * Stops the auto-flush monitor
     * @private
     */
    stopAutoFlushMonitor() {
        this.isMonitoring = false;
    }
}