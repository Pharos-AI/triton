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

    /**
     * Performance tracking instance
     * @private
     */
    performance = null;

    constructor() {
        if (instance) {
            return instance;
        }
        this.transactionManager = new TransactionManager(this);
        this.transactionId = this.transactionManager.initialize();
        this.spanContext = new SpanContext();
        this.spanContext.reset(this.transactionId);
        this.performance = new PerformanceTracker(this);

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
        // Generate a unique instance ID for this component binding
        const componentInstanceId = generateTransactionId();
        const componentKey = `${componentId}-${componentInstanceId}`;
        
        return new Proxy(this, {
            get(target, prop, receiver) {
                if (prop === '_componentId') return componentId;
                if (prop === '_componentInstanceId') return componentInstanceId;
                if (prop === '_componentKey') return componentKey;

                if (prop === 'setTemplate') {
                    return (builder) => self.templates.set(componentId, builder);
                }
                if (prop === 'fromTemplate') {
                    return () => {
                        const template = self.templates.get(componentId);
                        if (template) {
                            const builder = template.clone();
                            return receiver.refreshBuilder(builder);
                        }
                        return receiver.makeBuilder();
                    };
                }
                
                // For methods, bind them to the receiver (proxy) so 'this' refers to the proxy
                const value = Reflect.get(target, prop, receiver);
                if (typeof value === 'function') {
                    return value.bind(receiver);
                }
                
                return value;
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
        this.spanContext.reset(this.transactionId);
        this.performance.clearAllMarks();
        return this.transactionId;
    }

    /**
     * Resumes a transaction using an existing transaction ID
     * Also starts the auto-flush monitor
     * @param {string} transactionId - Existing transaction ID to resume
     */
    resumeTransaction(transactionId) {
        this.transactionId = this.transactionManager.resume(transactionId);
        this.spanContext.reset(this.transactionId);
    }

    /**
     * Stops the current transaction and auto-flush monitor
     * Flushes any remaining logs
     */
    stopTransaction() {
        this.transactionManager.stop();
        this.transactionId = null;
        this.spanContext.clear();
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
            .timestamp(Date.now())
            .spanId(generateTransactionId())
            .parentSpanId(this.stableParentSpanId());
    }

    /**
     * Resolves the parent span id for a new log, skipping marks that are still
     * open: startMark() pushes a span id but endMark() publishes the record, so
     * the stack top can name a span that has not been emitted yet — or never
     * will be, if the mark does not close.
     * @private
     * @returns {string|null}
     */
    stableParentSpanId() {
        if (!this.performance || typeof this.performance.isActiveMarkSpanId !== 'function') {
            return this.spanContext.current();
        }
        return this.spanContext.getStableParent(
            (spanId) => this.performance.isActiveMarkSpanId(spanId)
        );
    }

    /**
     * Enters a new logical step (e.g., wizard step), resetting the span stack
     * to the transaction root and pushing a new span for the step.
     * @param {string} [stepSpanId] - Optional custom span ID for the step (auto-generated if omitted)
     * @returns {string} The span ID for this step
     */
    enterStep(stepSpanId) {
        const spanId = stepSpanId || generateTransactionId();
        this.spanContext.reset(this.transactionId);
        this.spanContext.push(spanId);
        return spanId;
    }

    /**
     * Enables sessionStorage persistence for the span context stack.
     * Useful for multi-page flows where span hierarchy must survive navigation.
     */
    enableSpanPersistence() {
        this.spanContext.persist();
    }

    /**
     * Checks if component binding is available for performance tracking
     * @private
     * @returns {boolean} True if component is bound, false otherwise
     */
    _checkComponentBinding() {
        if (!this._componentId) {
            console.warn('Triton performance tracking requires bindToComponent() to be called first');
            return false;
        }
        return true;
    }

    /**
     * Start a performance mark for timing operations
     * @param {string} markName - Name of the performance mark
     * @returns {string} Mark name for later reference
     */
    startPerformanceMark(markName) {
        if (!this._checkComponentBinding()) return null;
        // Pass the bound proxy (this) to the performance tracker
        return this.performance.startMark(markName, this);
    }

    /**
     * End a performance mark and log the timing
     * @param {string} markName - Mark name used in startPerformanceMark
     */
    endPerformanceMark(markName) {
        if (!this._checkComponentBinding()) return;
        // Pass the bound proxy (this) to the performance tracker
        this.performance.endMark(markName, this);
    }

    /**
     * Time a backend call and automatically log performance metrics
     * @param {string} methodName - Name of the method/action being performed
     * @param {Function} apexCall - Function that returns the Apex call promise
     * @returns {PerformanceCallBuilder} Builder for configuring error handling
     */
    timeBackendCall(methodName, apexCall) {
        return new PerformanceCallBuilder(this, 'backend', apexCall, methodName);
    }

    /**
     * Track component lifecycle events
     * @param {string} lifecycleEvent - Lifecycle event (connected, disconnected, rendered)
     */
    trackComponentLifecycle(lifecycleEvent) {
        if (!this._checkComponentBinding()) return;
        // Pass the bound proxy (this) to the performance tracker
        this.performance.trackLifecycle(lifecycleEvent, this);
    }

    /**
     * Track component render performance
     */
    trackComponentRender() {
        if (!this._checkComponentBinding()) return;
        // Pass the bound proxy (this) to the performance tracker
        this.performance.trackRender(this);
    }

    /**
     * Track user interaction performance
     * @param {string} interactionName - Name of the interaction
     * @param {Function} interaction - Function to execute and time
     * @returns {PerformanceCallBuilder} Builder for configuring error handling
     */
    timeUserInteraction(interactionName, interaction) {
        return new PerformanceCallBuilder(this, 'interaction', interaction, interactionName);
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
    FRONTEND: 'Frontend',
    BACKEND_CALL: 'BackendCall',
    COMPONENT_LIFECYCLE: 'ComponentLifecycle',
    COMPONENT_RENDER: 'ComponentRender',
    USER_INTERACTION: 'UserInteraction',
    PERFORMANCE: 'Performance'
};

/**
 * Unified builder for configuring performance call error handling and execution
 * @private
 */
class PerformanceCallBuilder {
    constructor(triton, callType, callFunction, methodName) {
        this.triton = triton;
        this.callType = callType; // 'backend' or 'interaction'
        this.callFunction = callFunction;
        this.methodName = methodName; // Explicit method/interaction name
        this.shouldRethrow = true; // Default to rethrow
        this.customErrorHandler = null;
    }

    /**
     * Configure to not rethrow errors after handling
     * @returns {PerformanceCallBuilder} Builder instance for chaining
     */
    withoutRethrow() {
        this.shouldRethrow = false;
        return this;
    }

    /**
     * Configure custom error handler (automatically disables built-in handler)
     * @param {Function} errorHandler - Custom error handling function
     * @returns {PerformanceCallBuilder} Builder instance for chaining
     */
    withCustomErrorHandler(errorHandler) {
        this.customErrorHandler = errorHandler;
        return this;
    }

    /**
     * Execute the call with configured error handling
     * @returns {Promise} Result of the call
     */
    async execute() {
        const startTime = this.triton.performance.getCurrentTime();

        // Capture span context at call start
        const spanId = generateTransactionId();
        const parentSpanId = this.triton.spanContext.current();
        this.triton.spanContext.push(spanId);

        // Use explicit method name and determine log type based on call type
        const methodName = this.methodName;
        let logType, operationName;
        if (this.callType === 'backend') {
            logType = TYPE.BACKEND_CALL;
            operationName = 'Backend call';
        } else {
            logType = TYPE.USER_INTERACTION;
            operationName = 'User interaction';
        }

        try {
            // Log operation start (only if component is bound)
            if (this.triton._componentId) {
                this.triton.log(
                    this.triton.makeBuilder()
                        .type(logType)
                        .summary(`${operationName} started: ${methodName}`)
                        .details(`Initiating ${operationName.toLowerCase()}: ${methodName}`)
                        .action(methodName)
                        .spanId(spanId)
                        .parentSpanId(parentSpanId)
                );
            }

            const result = await this.callFunction();
            const endTime = this.triton.performance.getCurrentTime();
            const duration = endTime - startTime;

            // Log successful operation (only if component is bound)
            if (this.triton._componentId) {
                this.triton.log(
                    this.triton.makeBuilder()
                        .type(logType)
                        .summary(`${operationName} completed: ${methodName}`)
                        .details(`Duration: ${duration}ms`)
                        .duration(duration)
                        .action(methodName)
                        .spanId(spanId)
                        .parentSpanId(parentSpanId)
                );
            }

            return result;

        } catch (error) {
            const endTime = this.triton.performance.getCurrentTime();
            const duration = endTime - startTime;

            // Use custom error handler if provided, otherwise use built-in
            if (this.customErrorHandler) {
                const context = this.callType === 'backend'
                    ? { methodName, duration }
                    : { interactionName: methodName, duration };
                this.customErrorHandler(error, context);
            } else if (this.triton._componentId) {
                // Built-in error logging (only if component is bound)
                this.triton.log(
                    this.triton.makeBuilder()
                        .type(logType)
                        .summary(`${operationName} failed: ${methodName}`)
                        .details(`Duration: ${duration}ms, Error: ${error.message}`)
                        .duration(duration)
                        .action(methodName)
                        .exception(error)
                        .spanId(spanId)
                        .parentSpanId(parentSpanId)
                );
            }

            // Rethrow if configured
            if (this.shouldRethrow) {
                throw error;
            }

            return null;
        } finally {
            this.triton.spanContext.pop(spanId);
        }
    }
}

/**
 * Performance tracking functionality integrated into Triton
 * Locker Service compatible implementation with component instance mapping
 * @private
 */
class PerformanceTracker {
    constructor(triton) {
        this.triton = triton;
        // Map of component instances to their performance data
        // Structure: componentKey (name-instanceId) -> { marks: Map, renderCounts: number, lifecycleEvents: Map }
        this.componentInstances = new Map();
        this.startTime = this.getCurrentTime();
    }

    /**
     * Get or create component performance data
     * @private
     * @param {string} componentKey - Component key (name + instance ID)
     * @returns {Object} Component performance data
     */
    getComponentData(componentKey) {
        if (!componentKey) {
            componentKey = 'unknown';
        }
        
        if (!this.componentInstances.has(componentKey)) {
            this.componentInstances.set(componentKey, {
                marks: new Map(),
                renderCounts: 0,
                lifecycleEvents: new Map()
            });
        }
        
        return this.componentInstances.get(componentKey);
    }

    /**
     * Safe method to get current time
     * Falls back to Date.now() if performance.now() is not available
     * @private
     * @returns {number} Current time in milliseconds
     */
    getCurrentTime() {
        try {
            if (typeof performance !== 'undefined' && typeof performance.now === 'function') {
                return performance.now();
            }
        } catch (error) {
            console.warn('performance.now() not available, falling back to Date.now()');
        }
        return Date.now();
    }



    /**
     * Start a performance mark
     * @param {string} markName - Name of the mark
     * @param {Object} boundTriton - The bound Triton proxy instance (optional)
     * @returns {string} Mark name
     */
    startMark(markName, boundTriton = null) {
        const tritonInstance = boundTriton || this.triton;
        const componentKey = tritonInstance._componentKey || 'unknown';
        const componentData = this.getComponentData(componentKey);
        const startTime = this.getCurrentTime();

        const spanId = generateTransactionId();
        const parentSpanId = tritonInstance.spanContext.current();
        tritonInstance.spanContext.push(spanId);

        componentData.marks.set(markName, {
            name: markName,
            startTime: startTime,
            componentKey: componentKey,
            spanId: spanId,
            parentSpanId: parentSpanId
        });

        return markName;
    }

    /**
     * End a performance mark and log the timing
     * @param {string} markName - Mark name
     * @param {Object} boundTriton - The bound Triton proxy instance (optional)
     */
    endMark(markName, boundTriton = null) {
        const tritonInstance = boundTriton || this.triton;
        const endTime = this.getCurrentTime();
        const componentKey = tritonInstance._componentKey || 'unknown';
        const componentData = this.getComponentData(componentKey);

        const markData = componentData.marks.get(markName);

        if (!markData) {
            console.warn(`Performance mark '${markName}' not found for component ${tritonInstance._componentId || 'unknown'}`);
            return;
        }

        const duration = endTime - markData.startTime;

        // Remove this mark's span from the context stack
        tritonInstance.spanContext.pop(markData.spanId);

        // Clean up the mark
        componentData.marks.delete(markName);

        // Log the performance data using the mark's captured span context
        tritonInstance.log(
            tritonInstance.makeBuilder()
                .type(TYPE.PERFORMANCE)
                .summary(`Performance: ${tritonInstance._componentId || 'unknown'} - ${markData.name}`)
                .details(`Duration: ${duration}ms`)
                .duration(duration)
                .action(markData.name)
                .spanId(markData.spanId)
                .parentSpanId(markData.parentSpanId)
        );
    }

    /**
     * Checks if a span ID belongs to an active performance mark
     * @param {string} spanId - Span ID to check
     * @returns {boolean}
     */
    isActiveMarkSpanId(spanId) {
        for (const [, componentData] of this.componentInstances) {
            for (const [, markData] of componentData.marks) {
                if (markData.spanId === spanId) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Clears all active marks across all components.
     * Called on new transaction to prevent stale marks.
     */
    clearAllMarks() {
        for (const [, componentData] of this.componentInstances) {
            componentData.marks.clear();
        }
    }

    /**
     * Track component lifecycle events
     * @param {string} lifecycleEvent - Lifecycle event
     * @param {Object} boundTriton - The bound Triton proxy instance (optional)
     */
    trackLifecycle(lifecycleEvent, boundTriton = null) {
        const tritonInstance = boundTriton || this.triton;
        const componentKey = tritonInstance._componentKey || 'unknown';
        const componentData = this.getComponentData(componentKey);
        const eventKey = `${lifecycleEvent}`;
        componentData.lifecycleEvents.set(eventKey, Date.now());
        
        // Use the appropriate context for logging
        tritonInstance.log(
            tritonInstance.makeBuilder()
                .type(TYPE.COMPONENT_LIFECYCLE)
                .summary(`Component lifecycle: ${tritonInstance._componentId || 'unknown'} - ${lifecycleEvent}`)
                .details(`Component ${lifecycleEvent} event triggered`)
                .action(`lifecycle-${lifecycleEvent}`)
        );
    }

    /**
     * Track component render performance
     * @param {Object} boundTriton - The bound Triton proxy instance (optional)
     */
    trackRender(boundTriton = null) {
        const tritonInstance = boundTriton || this.triton;
        const componentKey = tritonInstance._componentKey || 'unknown';
        const componentData = this.getComponentData(componentKey);
        componentData.renderCounts += 1;
        
        // Use the appropriate context for logging
        tritonInstance.log(
            tritonInstance.makeBuilder()
                .type(TYPE.COMPONENT_RENDER)
                .summary(`Component render: ${tritonInstance._componentId || 'unknown'}`)
                .details(`Render count: ${componentData.renderCounts}`)
                .action('component-render')
        );
    }
}

/**
 * Manages span hierarchy tracking with an in-memory stack.
 * Optionally persists to sessionStorage for cross-navigation scenarios.
 * @private
 */
class SpanContext {
    static STORAGE_KEY = 'tritonContextStack';

    constructor(options = {}) {
        this._stack = [];
        this._persist = options.persist || false;
    }

    /**
     * Returns the current span stack
     * @returns {string[]}
     */
    getStack() {
        if (this._persist) {
            try {
                const stored = sessionStorage.getItem(SpanContext.STORAGE_KEY);
                if (stored) {
                    this._stack = JSON.parse(stored);
                }
            } catch (e) {
                // fall back to in-memory
            }
        }
        return this._stack;
    }

    /**
     * Replaces the span stack
     * @param {string[]} stack
     */
    setStack(stack) {
        this._stack = stack;
        if (this._persist) {
            try {
                sessionStorage.setItem(SpanContext.STORAGE_KEY, JSON.stringify(stack));
            } catch (e) {
                // fall back to in-memory
            }
        }
    }

    /**
     * Push a span ID onto the stack
     * @param {string} spanId
     */
    push(spanId) {
        const stack = this.getStack();
        stack.push(spanId);
        this.setStack(stack);
    }

    /**
     * Remove a specific span ID from the stack (supports out-of-order pops)
     * @param {string} spanId
     */
    pop(spanId) {
        const stack = this.getStack();
        const index = stack.lastIndexOf(spanId);
        if (index !== -1) {
            stack.splice(index, 1);
            this.setStack(stack);
        }
    }

    /**
     * Returns the current (top) span ID
     * @returns {string|null}
     */
    current() {
        const stack = this.getStack();
        return stack.length > 0 ? stack[stack.length - 1] : null;
    }

    /**
     * Returns the parent span ID (second from top)
     * @returns {string|null}
     */
    parent() {
        const stack = this.getStack();
        return stack.length > 1 ? stack[stack.length - 2] : null;
    }

    /**
     * Reset the stack to contain only the root ID
     * @param {string} rootId
     */
    reset(rootId) {
        this.setStack(rootId ? [rootId] : []);
    }

    /**
     * Clear the stack entirely
     */
    clear() {
        this._stack = [];
        if (this._persist) {
            try {
                sessionStorage.removeItem(SpanContext.STORAGE_KEY);
            } catch (e) {
                // ignore
            }
        }
    }

    /**
     * Enable sessionStorage persistence
     */
    persist() {
        this._persist = true;
        // Write current in-memory stack to storage
        this.setStack(this._stack);
    }

    /**
     * Returns a stable parent span ID by skipping active mark spans.
     * Walks the stack from top down, skipping any span IDs that match active marks.
     * @param {Function} isActiveMarkFn - Predicate: (spanId) => boolean
     * @returns {string|null}
     */
    getStableParent(isActiveMarkFn) {
        const stack = this.getStack();
        for (let i = stack.length - 1; i >= 0; i--) {
            if (!isActiveMarkFn(stack[i])) {
                return stack[i];
            }
        }
        return null;
    }
}

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