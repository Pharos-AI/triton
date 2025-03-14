/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

const TRITON_COMPONENTS = ['triton', 'tritonBuilder', 'tritonHelper'];

/**
 * Checks if a stack trace line is from internal Triton files
 * @param {string} stackTraceLine - Line from stack trace to check
 * @returns {boolean} True if the line is NOT from internal Triton files
 */
const isNotTriton = (stackTraceLine) => {
    return !TRITON_COMPONENTS.some(component => 
        stackTraceLine.indexOf(`c/${component}.js`) !== -1
    );
};

/**
 * Determines if a stack trace line is from an LWC component
 * @param {string} stackTraceLine - Line from stack trace to check
 * @returns {boolean} True if the line is from an LWC component
 */
const isLWCLine = (stackTraceLine) => {
    return stackTraceLine.includes('modules/');
};

/**
 * Checks if a stack trace line is from a component (LWC or Aura)
 * @param {string} stackTraceLine - Line from stack trace to check
 * @returns {boolean} True if the line is from a component
 */
const isComponentLine = (stackTraceLine) => {
    return isLWCLine(stackTraceLine) || isAuraLine(stackTraceLine);
};

/**
 * Determines if a stack trace line is from an Aura component
 * @param {string} stackTraceLine - Line from stack trace to check
 * @returns {boolean} True if the line is from an Aura component
 */
const isAuraLine = (stackTraceLine) => {
    return stackTraceLine.includes('components/');
};

/**
 * Determines if a stack trace is from an Aura component
 * @param {string} [stack] - Stack trace to analyze. If not provided, gets current stack trace
 * @returns {boolean} True if the stack trace contains Aura component references
 */
const isAura = (stack) => {
    return (stack || new Error().stack).split('\n').some(line => isAuraLine(line));
};

/**
 * Generates a UUID v4 (random UUID)
 * @returns {string} The generated UUID in format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
 * @example
 * const uuid = generateTransactionId(); // e.g. "550e8400-e29b-41d4-a716-446655440000"
 */
const generateTransactionId = () => {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
};

/**
 * Captures comprehensive runtime information about the current environment
 * @returns {Object} Object containing:
 *   - Environment info (userAgent, language, platform)
 *   - Viewport dimensions
 *   - Theme settings
 *   - Performance metrics (page load, paint times, memory usage)
 *   - Network info (connection type, speed)
 *   - Device info (screen size, orientation)
 * @throws {Error} Logs warning to console if any info capture fails
 */
const captureRuntimeInfo = () => {
    const info = {};
    
    // Environment info
    try {
        if (typeof navigator !== 'undefined') {
            info.userAgent = navigator.userAgent;
            info.language = navigator.language;
            if (navigator.userAgentData) {
                info.platform = navigator.userAgentData.platform;
                info.mobile = navigator.userAgentData.mobile;
                info.brands = navigator.userAgentData.brands;
            } else {
                info.platform = navigator.platform;
            }
        }
    } catch (error) {
        console.warn('Error capturing environment info:', error);
    }

    // Viewport info
    try {
        if (typeof window !== 'undefined') {
            info.viewportWidth = window.innerWidth;
            info.viewportHeight = window.innerHeight;
        }
    } catch (error) {
        console.warn('Error capturing viewport info:', error);
    }

    // Theme info
    try {
        if (document.documentElement) {
            info.theme = document.documentElement.getAttribute('data-theme') || 
                        document.documentElement.getAttribute('data-mode') || 
                        'default';
        }
    } catch (error) {
        console.warn('Error capturing theme info:', error);
    }

    // Performance metrics
    try {
        if (window.performance) {
            const navigationTiming = performance.getEntriesByType('navigation')[0];
            if (navigationTiming) {
                info.pageLoadTime = navigationTiming.loadEventEnd - navigationTiming.startTime;
                info.domInteractive = navigationTiming.domInteractive;
                info.domContentLoaded = navigationTiming.domContentLoadedEventEnd;
                info.firstByte = navigationTiming.responseStart - navigationTiming.requestStart;
                info.serverTime = navigationTiming.responseEnd - navigationTiming.requestStart;
            }
            
            const paintMetrics = performance.getEntriesByType('paint');
            paintMetrics.forEach(paint => {
                if (paint.name === 'first-paint') {
                    info.firstPaint = paint.startTime;
                }
                if (paint.name === 'first-contentful-paint') {
                    info.firstContentfulPaint = paint.startTime;
                }
            });

            if (window.performance.memory) {
                info.memoryUsage = performance.memory.usedJSHeapSize;
                info.memoryLimit = performance.memory.jsHeapSizeLimit;
            }
        }
    } catch (error) {
        console.warn('Error capturing performance metrics:', error);
    }

    // Network info
    try {
        if (navigator.connection) {
            info.connectionType = navigator.connection.effectiveType;
            info.connectionSpeed = navigator.connection.downlink;
            info.connectionRtt = navigator.connection.rtt;
            info.saveData = navigator.connection.saveData;
        }
        if (window.location) {
            info.pathname = window.location.pathname;
            info.hostname = window.location.hostname;
        }
        info.isOnline = navigator.onLine;
    } catch (error) {
        console.warn('Error capturing network info:', error);
    }

    // Device info
    try {
        if (window.screen) {
            info.formFactor = window.screen.width < 768 ? 'SMALL' 
                : window.screen.width < 1024 ? 'MEDIUM' 
                : 'LARGE';
            info.screenWidth = window.screen.width;
            info.screenHeight = window.screen.height;
            if (window.screen.orientation) {
                info.orientation = window.screen.orientation.type;
            }
        }
    } catch (error) {
        console.warn('Error capturing device info:', error);
    }

    return info;
};

/**
 * Extracts the component name from a stack trace line
 * @param {string} componentLine - Stack trace line containing component info
 * @returns {string} Component name or 'unknown-component' if not found
 */
const extractComponentName = (componentLine) => {
    const match = componentLine.match(/modules\/c\/(\w+)\.js/);
    if (match && match[1]) {
        return match[1];  // Returns just the component name (e.g., "productTileList")
    }
    console.warn('Could not parse component name from line:', componentLine);
    return 'unknown-component';
};

/**
 * Extracts the component identifier from a stack trace
 * @returns {string} Component identifier
 */
const generateComponentId = () => {
    const stack = new Error().stack;
    const lines = stack.split('\n');
    
    // Skip the first line (Error message) and the generateComponentId call
    const componentLine = lines.slice(2).find(line => 
        isNotTriton(line) && isComponentLine(line)
    );
    
    if (!componentLine) {
        console.warn('Could not identify component from stack trace');
        return 'unknown-component';
    }
    
    return extractComponentName(componentLine);
};

export {
    isNotTriton,
    isLWCLine,
    isComponentLine,
    isAuraLine,
    isAura,
    generateTransactionId,
    captureRuntimeInfo,
    generateComponentId,
    extractComponentName
};