/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import Triton, { AREA, CATEGORY, LEVEL, TYPE } from '../triton';

// Mock TritonBuilder
jest.mock('c/tritonBuilder', () => {
  return jest.fn().mockImplementation(() => {
    const mockBuilder = {
      level: jest.fn().mockReturnThis(),
      category: jest.fn().mockReturnThis(),
      type: jest.fn().mockReturnThis(),
      area: jest.fn().mockReturnThis(),
      summary: jest.fn().mockReturnThis(),
      details: jest.fn().mockReturnThis(),
      transactionId: jest.fn().mockReturnThis(),
      duration: jest.fn().mockReturnThis(),
      action: jest.fn().mockReturnThis(),
      exception: jest.fn().mockReturnThis(),
      userId: jest.fn().mockReturnThis(),
      runtimeInfo: jest.fn().mockReturnThis(),
      timestamp: jest.fn().mockReturnThis(),
      spanId: jest.fn().mockReturnThis(),
      parentSpanId: jest.fn().mockReturnThis(),
      componentDetails: jest.fn().mockReturnThis(),
      clone: jest.fn().mockImplementation(() => {
        // Return a new mock with the same structure
        return {
          level: jest.fn().mockReturnThis(),
          category: jest.fn().mockReturnThis(),
          type: jest.fn().mockReturnThis(),
          area: jest.fn().mockReturnThis(),
          summary: jest.fn().mockReturnThis(),
          details: jest.fn().mockReturnThis(),
          transactionId: jest.fn().mockReturnThis(),
          duration: jest.fn().mockReturnThis(),
          action: jest.fn().mockReturnThis(),
          exception: jest.fn().mockReturnThis(),
          userId: jest.fn().mockReturnThis(),
          runtimeInfo: jest.fn().mockReturnThis(),
          timestamp: jest.fn().mockReturnThis(),
          spanId: jest.fn().mockReturnThis(),
          parentSpanId: jest.fn().mockReturnThis(),
          componentDetails: jest.fn().mockReturnThis(),
          build: jest.fn().mockReturnValue({ mockBuiltLog: true }),
          clone: jest.fn().mockReturnThis(),
          _createdTimestamp: Date.now()
        };
      }),
      build: jest.fn().mockReturnValue({ mockBuiltLog: true }),
      _createdTimestamp: Date.now()
    };
    return mockBuilder;
  });
});

// Mock tritonUtils
jest.mock('c/tritonUtils', () => ({
  generateTransactionId: jest.fn(() => 'mock-transaction-id'),
  captureRuntimeInfo: jest.fn(() => ({ mockRuntimeInfo: true }))
}));

import saveComponentLogs from '@salesforce/apex/TritonLwc.saveComponentLogs';
import USER_ID from '@salesforce/user/Id';
import TritonBuilder from 'c/tritonBuilder';
import { generateTransactionId, captureRuntimeInfo } from 'c/tritonUtils';

describe('Triton', () => {
  let triton;

  beforeEach(() => {
    // Reset all mocks
    jest.clearAllMocks();
    
    // Mock sessionStorage
    Object.defineProperty(window, 'sessionStorage', {
      value: {
        getItem: jest.fn().mockReturnValue(null),
        setItem: jest.fn(),
        removeItem: jest.fn()
      },
      writable: true,
      configurable: true
    });

    // Mock performance.now
    Object.defineProperty(window, 'performance', {
      value: {
        now: jest.fn(() => 1000)
      },
      writable: true,
      configurable: true
    });

    // Create a fresh instance for each test
    triton = new Triton();
    
    // Clear the logs array to start fresh
    triton.logs = [];
    triton.templates.clear();
  });

  afterEach(() => {
    // Clean up any timers
    jest.clearAllTimers();
    
    // Stop any running transaction managers
    if (triton.transactionManager) {
      triton.transactionManager.isMonitoring = false;
    }
  });

  describe('Constructor and Singleton Pattern', () => {
    test('should create an instance with default properties', () => {
      expect(triton.logs).toEqual([]);
      expect(triton.templates).toBeInstanceOf(Map);
      expect(triton.category).toBe(CATEGORY.LWC);
      expect(triton.performance).toBeDefined();
    });

    test('should initialize transaction manager', () => {
      expect(triton.transactionManager).toBeDefined();
      expect(triton.transactionId).toBeDefined();
    });
  });

  describe('bindToComponent()', () => {
    test('should return a proxy with component context', () => {
      const componentId = 'testComponent';
      const boundTriton = triton.bindToComponent(componentId);

      expect(boundTriton._componentId).toBe(componentId);
      expect(boundTriton._componentInstanceId).toBeDefined();
      expect(boundTriton._componentKey).toContain(componentId);
    });

    test('should provide setTemplate method', () => {
      const componentId = 'testComponent';
      const boundTriton = triton.bindToComponent(componentId);
      const mockTemplate = new TritonBuilder();

      boundTriton.setTemplate(mockTemplate);
      expect(triton.templates.get(componentId)).toBe(mockTemplate);
    });

    test('should provide fromTemplate method that clones template', () => {
      const componentId = 'testComponent';
      const boundTriton = triton.bindToComponent(componentId);
      const mockTemplate = new TritonBuilder();

      boundTriton.setTemplate(mockTemplate);
      const result = boundTriton.fromTemplate();

      expect(mockTemplate.clone).toHaveBeenCalled();
      expect(result).toBeDefined();
    });

    test('should fallback to makeBuilder when no template exists', () => {
      const componentId = 'testComponent';
      const boundTriton = triton.bindToComponent(componentId);

      const result = boundTriton.fromTemplate();
      expect(result).toBeDefined();
    });
  });

  describe('Transaction Management', () => {
    test('should start a new transaction', () => {
      const newTransactionId = triton.startTransaction();
      
      expect(newTransactionId).toBeDefined();
      expect(triton.transactionId).toBe(newTransactionId);
    });

    test('should resume an existing transaction', () => {
      const existingId = 'existing-transaction-id';
      triton.resumeTransaction(existingId);
      
      expect(triton.transactionId).toBe(existingId);
    });

    test('should stop transaction and flush logs', async () => {
      saveComponentLogs.mockResolvedValue({ success: true });
      
      triton.stopTransaction();
      
      expect(triton.transactionId).toBeNull();
    });
  });

  describe('Log Level Methods', () => {
    test('should create error log and return builder', () => {
      const result = triton.error('BACKEND', 'ACCOUNTS');
      
      expect(result).toBeDefined();
      expect(TritonBuilder).toHaveBeenCalled();
    });

    test('should create warning log and return builder', () => {
      const result = triton.warning('FRONTEND', 'COMMUNITY');
      
      expect(result).toBeDefined();
      expect(TritonBuilder).toHaveBeenCalled();
    });

    test('should create info log and return builder', () => {
      const result = triton.info('PERFORMANCE', 'REST_API');
      
      expect(result).toBeDefined();
      expect(TritonBuilder).toHaveBeenCalled();
    });

    test('should create debug log and return builder', () => {
      const result = triton.debug('BACKEND_CALL', 'LEAD_CONVERSION');
      
      expect(result).toBeDefined();
      expect(TritonBuilder).toHaveBeenCalled();
    });

    test('should create exception log with error', () => {
      const error = new Error('Test error');
      const result = triton.exception(error);
      
      expect(result).toBeDefined();
      expect(TritonBuilder).toHaveBeenCalled();
    });
  });

  describe('Builder Methods', () => {
    test('should create builder with default properties', () => {
      const builder = triton.makeBuilder();
      
      expect(builder).toBeDefined();
      expect(TritonBuilder).toHaveBeenCalled();
    });

    test('should refresh builder with span context', () => {
      const mockBuilder = new TritonBuilder();
      const result = triton.refreshBuilder(mockBuilder);

      expect(result).toBe(mockBuilder);
      expect(mockBuilder.runtimeInfo).toHaveBeenCalledWith({ mockRuntimeInfo: true });
      expect(mockBuilder.timestamp).toHaveBeenCalled();
      expect(mockBuilder.spanId).toHaveBeenCalledWith('mock-transaction-id');
      expect(mockBuilder.parentSpanId).toHaveBeenCalled();
    });

    test('should set component info when component is bound', () => {
      const boundTriton = triton.bindToComponent('testComponent');
      const mockBuilder = new TritonBuilder();
      
      boundTriton.refreshBuilder(mockBuilder);
      
      expect(mockBuilder._componentInfo).toEqual({ name: 'testComponent', function: '' });
    });
  });

  describe('Logging Methods', () => {
    test('should add builder to logs array', () => {
      const mockBuilder = new TritonBuilder();
      const initialLength = triton.logs.length;
      
      triton.log(mockBuilder);
      
      expect(triton.logs).toHaveLength(initialLength + 1);
      expect(triton.logs).toContain(mockBuilder);
      expect(mockBuilder.componentDetails).toHaveBeenCalled();
    });

    test('should immediately flush single log', async () => {
      saveComponentLogs.mockResolvedValue({ success: true });
      const existingLogs = [new TritonBuilder()];
      triton.logs = [...existingLogs];
      
      const newBuilder = new TritonBuilder();
      await triton.logNow(newBuilder);
      
      expect(saveComponentLogs).toHaveBeenCalled();
      expect(triton.logs).toEqual(existingLogs); // Original logs restored
    });

    test('should preserve logs on logNow error', async () => {
      const error = new Error('Flush failed');
      saveComponentLogs.mockRejectedValue(error);
      const existingLogCount = 1;
      triton.logs = [new TritonBuilder()];
      
      const newBuilder = new TritonBuilder();
      
      await expect(triton.logNow(newBuilder)).rejects.toThrow('Flush failed');
      // Both original logs and the new builder should be preserved after error
      expect(triton.logs).toHaveLength(existingLogCount + 1); // Original + new builder
    });
  });

  describe('Flush Method', () => {
    test('should return early if no logs to flush', async () => {
      triton.logs = [];
      
      const result = await triton.flush();
      
      expect(saveComponentLogs).not.toHaveBeenCalled();
      expect(result).toBeUndefined();
    });

    test('should successfully flush logs to server', async () => {
      const mockLogs = [new TritonBuilder(), new TritonBuilder()];
      const mockResponse = { success: true };
      triton.logs = mockLogs;
      saveComponentLogs.mockResolvedValue(mockResponse);
      
      const result = await triton.flush();
      
      expect(saveComponentLogs).toHaveBeenCalledWith({
        componentLogs: [{ mockBuiltLog: true }, { mockBuiltLog: true }]
      });
      expect(triton.logs).toEqual([]); // Logs cleared
      expect(result).toBe(mockResponse);
    });

    test('should restore logs on flush error', async () => {
      const mockLogs = [new TritonBuilder(), new TritonBuilder()];
      const error = new Error('Network error');
      triton.logs = mockLogs;
      saveComponentLogs.mockRejectedValue(error);
      
      await expect(triton.flush()).rejects.toThrow('Network error');
      expect(triton.logs).toEqual(mockLogs); // Logs restored
    });
  });

  describe('Performance Tracking', () => {
    let boundTriton;

    beforeEach(() => {
      boundTriton = triton.bindToComponent('testComponent');
    });

    test('should warn when performance methods called without component binding', () => {
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
      
      const result = triton.startPerformanceMark('testMark');
      
      expect(consoleSpy).toHaveBeenCalledWith(
        'Triton performance tracking requires bindToComponent() to be called first'
      );
      expect(result).toBeNull();
      
      consoleSpy.mockRestore();
    });

    test('should start performance mark with component binding', () => {
      const markName = boundTriton.startPerformanceMark('testMark');
      
      expect(markName).toBe('testMark');
    });

    test('should end performance mark with component binding', () => {
      boundTriton.startPerformanceMark('testMark');
      const initialLogCount = triton.logs.length;
      
      boundTriton.endPerformanceMark('testMark');
      
      // Verify that a log was created
      expect(triton.logs.length).toBe(initialLogCount + 1);
    });

    test('should track component lifecycle', () => {
      const initialLogCount = triton.logs.length;
      
      boundTriton.trackComponentLifecycle('connected');
      
      // Verify that a log was created
      expect(triton.logs.length).toBe(initialLogCount + 1);
    });

    test('should track component render', () => {
      const initialLogCount = triton.logs.length;
      
      boundTriton.trackComponentRender();
      
      // Verify that a log was created
      expect(triton.logs.length).toBe(initialLogCount + 1);
    });

    test('should create backend call builder', () => {
      const methodName = 'testMethod';
      const apexCall = jest.fn();
      
      const builder = boundTriton.timeBackendCall(methodName, apexCall);
      
      expect(builder).toBeDefined();
      expect(builder.constructor.name).toBe('PerformanceCallBuilder');
    });

    test('should create user interaction builder', () => {
      const interactionName = 'buttonClick';
      const interaction = jest.fn();
      
      const builder = boundTriton.timeUserInteraction(interactionName, interaction);
      
      expect(builder).toBeDefined();
      expect(builder.constructor.name).toBe('PerformanceCallBuilder');
    });
  });

  describe('Constants', () => {
    test('should export AREA constants', () => {
      expect(AREA.ACCOUNTS).toBe('ACCOUNTS');
      expect(AREA.COMMUNITY).toBe('COMMUNITY');
      expect(AREA.LEAD_CONVERSION).toBe('LEAD_CONVERSION');
      expect(AREA.OPPORTUNITY_MANAGEMENT).toBe('OPPORTUNITY_MANAGEMENT');
      expect(AREA.REST_API).toBe('REST_API');
    });

    test('should export CATEGORY constants', () => {
      expect(CATEGORY.LWC).toBe('LWC');
      expect(CATEGORY.AURA).toBe('Aura');
      expect(CATEGORY.WARNING).toBe('Warning');
      expect(CATEGORY.DEBUG).toBe('Debug');
      expect(CATEGORY.EVENT).toBe('Event');
    });

    test('should export LEVEL constants', () => {
      expect(LEVEL.ERROR).toBe('ERROR');
      expect(LEVEL.WARNING).toBe('WARNING');
      expect(LEVEL.INFO).toBe('INFO');
      expect(LEVEL.DEBUG).toBe('DEBUG');
      expect(LEVEL.FINE).toBe('FINE');
      expect(LEVEL.FINER).toBe('FINER');
      expect(LEVEL.FINEST).toBe('FINEST');
    });

    test('should export TYPE constants', () => {
      expect(TYPE.BACKEND).toBe('Backend');
      expect(TYPE.FRONTEND).toBe('Frontend');
      expect(TYPE.BACKEND_CALL).toBe('BackendCall');
      expect(TYPE.COMPONENT_LIFECYCLE).toBe('ComponentLifecycle');
      expect(TYPE.COMPONENT_RENDER).toBe('ComponentRender');
      expect(TYPE.USER_INTERACTION).toBe('UserInteraction');
      expect(TYPE.PERFORMANCE).toBe('Performance');
    });
  });
});

describe('PerformanceCallBuilder', () => {
  let triton;
  let boundTriton;
  let mockApexCall;

  beforeEach(() => {
    jest.clearAllMocks();
    triton = new Triton();
    triton.logs = []; // Clear logs
    boundTriton = triton.bindToComponent('testComponent');
    mockApexCall = jest.fn();
    
    // Mock performance.now
    let timeCounter = 1000;
    window.performance.now = jest.fn(() => timeCounter += 100);
  });

  test('should execute backend call successfully', async () => {
    const expectedResult = { success: true };
    mockApexCall.mockResolvedValue(expectedResult);
    
    const builder = boundTriton.timeBackendCall('testMethod', mockApexCall);
    const result = await builder.execute();
    
    expect(result).toBe(expectedResult);
    expect(mockApexCall).toHaveBeenCalled();
    expect(triton.logs.length).toBeGreaterThan(0); // Start and completion logs
  });

  test('should execute user interaction successfully', async () => {
    const expectedResult = 'interaction result';
    const mockInteraction = jest.fn().mockResolvedValue(expectedResult);
    
    const builder = boundTriton.timeUserInteraction('buttonClick', mockInteraction);
    const result = await builder.execute();
    
    expect(result).toBe(expectedResult);
    expect(mockInteraction).toHaveBeenCalled();
  });

  test('should handle errors and rethrow by default', async () => {
    const error = new Error('Backend error');
    mockApexCall.mockRejectedValue(error);
    
    const builder = boundTriton.timeBackendCall('testMethod', mockApexCall);
    
    await expect(builder.execute()).rejects.toThrow('Backend error');
    expect(triton.logs.length).toBeGreaterThan(0); // Error should be logged
  });

  test('should not rethrow errors when configured', async () => {
    const error = new Error('Backend error');
    mockApexCall.mockRejectedValue(error);
    
    const builder = boundTriton.timeBackendCall('testMethod', mockApexCall);
    const result = await builder.withoutRethrow().execute();
    
    expect(result).toBeNull();
    expect(triton.logs.length).toBeGreaterThan(0);
  });

  test('should use custom error handler', async () => {
    const error = new Error('Backend error');
    const customHandler = jest.fn();
    mockApexCall.mockRejectedValue(error);
    
    const builder = boundTriton.timeBackendCall('testMethod', mockApexCall);
    await expect(builder.withCustomErrorHandler(customHandler).execute()).rejects.toThrow();
    
    expect(customHandler).toHaveBeenCalledWith(error, {
      methodName: 'testMethod',
      duration: expect.any(Number)
    });
  });

  test('should handle calls without component binding', async () => {
    const expectedResult = { success: true };
    mockApexCall.mockResolvedValue(expectedResult);
    
    // Use unbound triton
    const builder = triton.timeBackendCall('testMethod', mockApexCall);
    const result = await builder.execute();
    
    expect(result).toBe(expectedResult);
    // Should not create logs without component binding (performance call builder checks for _componentId)
  });
});

describe('TransactionManager', () => {
  let triton;

  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();
    
    // Mock sessionStorage
    Object.defineProperty(window, 'sessionStorage', {
      value: {
        getItem: jest.fn().mockReturnValue(null),
        setItem: jest.fn(),
        removeItem: jest.fn()
      },
      writable: true,
      configurable: true
    });

    triton = new Triton();
    triton.logs = [];
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('should initialize with new transaction when none exists', () => {
    expect(triton.transactionManager).toBeDefined();
    expect(triton.transactionId).toBeDefined();
  });

  test('should resume existing transaction', () => {
    const existingId = 'existing-transaction';
    triton.resumeTransaction(existingId);
    
    expect(triton.transactionId).toBe(existingId);
  });

  test('should handle storage errors gracefully', () => {
    window.sessionStorage.setItem.mockImplementation(() => {
      throw new Error('Storage error');
    });
    
    const consoleSpy = jest.spyOn(console, 'log').mockImplementation();
    
    // Should not throw error
    expect(() => triton.startTransaction()).not.toThrow();
    
    consoleSpy.mockRestore();
  });

  test('should start auto-flush monitor', async () => {
    const flushSpy = jest.spyOn(triton, 'flush').mockResolvedValue();
    
    triton.transactionManager.start();
    
    // Add a log with old timestamp
    const oldBuilder = new TritonBuilder();
    oldBuilder._createdTimestamp = Date.now() - 15000; // 15 seconds ago
    triton.logs.push(oldBuilder);
    
    // Fast-forward time to trigger auto-flush
    jest.advanceTimersByTime(10000); // 10 seconds
    await Promise.resolve(); // Allow async operations to complete
    
    expect(flushSpy).toHaveBeenCalled();
  });

  test('should stop auto-flush monitor', () => {
    triton.transactionManager.start();
    expect(triton.transactionManager.isMonitoring).toBe(true);
    
    triton.transactionManager.stop();
    expect(triton.transactionManager.isMonitoring).toBe(false);
  });
});

describe('PerformanceTracker', () => {
  let triton;
  let boundTriton;

  beforeEach(() => {
    jest.clearAllMocks();
    triton = new Triton();
    triton.logs = [];
    boundTriton = triton.bindToComponent('testComponent');
    
    // Mock performance.now with incrementing values
    let timeCounter = 1000;
    window.performance.now = jest.fn(() => timeCounter += 100);
  });

  test('should start and end performance marks', () => {
    const markName = 'testMark';
    const initialLogCount = triton.logs.length;
    
    boundTriton.startPerformanceMark(markName);
    // The opening record ships immediately, so the span exists while the mark
    // is open and logs written meanwhile have a real parent to nest under.
    expect(triton.logs.length).toBe(initialLogCount + 1);

    boundTriton.endPerformanceMark(markName);
    
    // Two records, one span: the backend pairs them by span id, the same way it
    // pairs "Backend call started/completed".
    expect(triton.logs.length).toBe(initialLogCount + 2);
    const [opening, completion] = triton.logs.slice(-2);
    expect(opening.summary).toHaveBeenCalledWith(
      expect.stringContaining('Performance started:')
    );
    expect(opening.spanId.mock.calls[0][0]).toBe(completion.spanId.mock.calls[0][0]);
    expect(completion.duration).toHaveBeenCalled();
  });

  test('an open mark is already a real span for logs written under it', () => {
    // Before the opening record existed, a log written while the mark was open
    // named a span that had not been emitted — and never would be if the mark
    // stayed open. Measured on a live purchase trace: 60 LWC spans pointing at
    // three span ids that were absent from it, 30 under a single one.
    const initialLogCount = triton.logs.length;

    boundTriton.startPerformanceMark('slow-thing');
    const openMarkSpanId = triton.spanContext.current();

    boundTriton.log(boundTriton.info(TYPE.FRONTEND, AREA.OTHER).summary('work'));

    const [opening, work] = triton.logs.slice(initialLogCount);
    expect(opening.spanId).toHaveBeenCalledWith(openMarkSpanId);
    expect(work.parentSpanId).toHaveBeenCalledWith(openMarkSpanId);
  });

  test('should warn when ending non-existent mark', () => {
    const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
    
    boundTriton.endPerformanceMark('nonExistentMark');
    
    expect(consoleSpy).toHaveBeenCalledWith(
      "Performance mark 'nonExistentMark' not found for component testComponent"
    );
    
    consoleSpy.mockRestore();
  });

  test('should track component lifecycle events', () => {
    const initialLogCount = triton.logs.length;
    
    boundTriton.trackComponentLifecycle('connected');
    
    expect(triton.logs.length).toBe(initialLogCount + 1);
  });

  test('should track component renders with incrementing count', () => {
    const initialLogCount = triton.logs.length;
    
    boundTriton.trackComponentRender();
    boundTriton.trackComponentRender();
    
    expect(triton.logs.length).toBe(initialLogCount + 2);
  });

  test('should handle performance.now() unavailability', () => {
    // Mock performance.now to throw error
    window.performance.now = jest.fn(() => {
      throw new Error('Performance API not available');
    });
    
    const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
    
    // Should fallback to Date.now()
    const time = triton.performance.getCurrentTime();
    
    expect(typeof time).toBe('number');
    expect(consoleSpy).toHaveBeenCalledWith(
      'performance.now() not available, falling back to Date.now()'
    );
    
    consoleSpy.mockRestore();
  });

  test('should handle multiple component instances', () => {
    const boundTriton2 = triton.bindToComponent('anotherComponent');
    const initialLogCount = triton.logs.length;
    
    boundTriton.startPerformanceMark('mark1');
    boundTriton2.startPerformanceMark('mark2');
    
    boundTriton.endPerformanceMark('mark1');
    boundTriton2.endPerformanceMark('mark2');
    
    // Two marks, each an opening record plus a completion.
    expect(triton.logs.length).toBe(initialLogCount + 4);
  });

  test('should create component data for unknown components', () => {
    const componentData = triton.performance.getComponentData('unknown');

    expect(componentData).toBeDefined();
    expect(componentData.marks).toBeInstanceOf(Map);
    expect(componentData.renderCounts).toBe(0);
    expect(componentData.lifecycleEvents).toBeInstanceOf(Map);
  });

  test('should clear all marks', () => {
    boundTriton.startPerformanceMark('mark1');
    boundTriton.startPerformanceMark('mark2');

    triton.performance.clearAllMarks();

    const componentData = triton.performance.getComponentData(boundTriton._componentKey);
    expect(componentData.marks.size).toBe(0);
  });

  test('should identify active mark span IDs', () => {
    boundTriton.startPerformanceMark('mark1');

    // The mock generateTransactionId always returns 'mock-transaction-id'
    // so isActiveMarkSpanId checks against that
    expect(triton.performance.isActiveMarkSpanId('mock-transaction-id')).toBe(true);
    expect(triton.performance.isActiveMarkSpanId('non-existent-span')).toBe(false);
  });
});

describe('SpanContext', () => {
  let triton;

  beforeEach(() => {
    jest.clearAllMocks();

    Object.defineProperty(window, 'sessionStorage', {
      value: {
        getItem: jest.fn().mockReturnValue(null),
        setItem: jest.fn(),
        removeItem: jest.fn()
      },
      writable: true,
      configurable: true
    });

    triton = new Triton();
    triton.logs = [];
  });

  test('should initialize span context on construction', () => {
    expect(triton.spanContext).toBeDefined();
  });

  test('should reset span context on startTransaction', () => {
    triton.startTransaction();
    const current = triton.spanContext.current();

    expect(current).toBe(triton.transactionId);
  });

  test('should reset span context on resumeTransaction', () => {
    triton.resumeTransaction('resume-txn-id');
    const current = triton.spanContext.current();

    expect(current).toBe('resume-txn-id');
  });

  test('should clear span context on stopTransaction', () => {
    triton.startTransaction();
    triton.spanContext.push('child-span');
    triton.stopTransaction();

    expect(triton.spanContext.current()).toBeNull();
  });

  test('push/pop should manage stack correctly', () => {
    triton.spanContext.reset('root');
    triton.spanContext.push('child1');
    triton.spanContext.push('child2');

    expect(triton.spanContext.current()).toBe('child2');
    expect(triton.spanContext.parent()).toBe('child1');

    triton.spanContext.pop('child2');
    expect(triton.spanContext.current()).toBe('child1');
  });

  test('pop should handle out-of-order removal', () => {
    triton.spanContext.reset('root');
    triton.spanContext.push('a');
    triton.spanContext.push('b');
    triton.spanContext.push('c');

    // Remove middle element
    triton.spanContext.pop('b');
    const stack = triton.spanContext.getStack();

    expect(stack).toEqual(['root', 'a', 'c']);
  });

  test('enterStep should reset to root and push step span', () => {
    triton.startTransaction();
    triton.spanContext.push('old-child');

    const stepId = triton.enterStep('step-1');

    expect(stepId).toBe('step-1');
    const stack = triton.spanContext.getStack();
    expect(stack).toEqual([triton.transactionId, 'step-1']);
  });

  test('enterStep should auto-generate span ID if not provided', () => {
    const stepId = triton.enterStep();

    expect(stepId).toBe('mock-transaction-id'); // from mocked generateTransactionId
  });

  test('getStableParent should skip active mark spans', () => {
    triton.spanContext.reset('root');
    triton.spanContext.push('stable-parent');
    triton.spanContext.push('active-mark-span');

    const isActiveMark = (id) => id === 'active-mark-span';
    const parent = triton.spanContext.getStableParent(isActiveMark);

    expect(parent).toBe('stable-parent');
  });

  test('enableSpanPersistence should enable sessionStorage', () => {
    triton.enableSpanPersistence();
    triton.spanContext.push('persisted-span');

    expect(window.sessionStorage.setItem).toHaveBeenCalled();
  });

  test('clear should empty the stack', () => {
    triton.spanContext.reset('root');
    triton.spanContext.push('child');
    triton.spanContext.clear();

    expect(triton.spanContext.current()).toBeNull();
    expect(triton.spanContext.getStack()).toEqual([]);
  });
});