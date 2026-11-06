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
    // The singleton keeps its failure count across tests
    triton.failedFlushes = 0;
    
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
      const earlier = new TritonBuilder();
      triton.logs = [earlier];

      const newBuilder = new TritonBuilder();

      // Never rejects, so an awaited logNow inside a catch block cannot derail it
      await expect(triton.logNow(newBuilder)).resolves.toBeUndefined();
      // Both are kept for the next flush, the earlier log first
      expect(triton.logs).toHaveLength(2);
      expect(triton.logs[0]).toBe(earlier);
      expect(triton.logs[1]).toBe(newBuilder);
    });

    test.each([
      ['undefined', undefined],
      ['null', null],
      ['a built log instead of its builder', { mockBuiltLog: true }]
    ])('logNow given %s resolves and keeps the buffered logs', async (_label, notABuilder) => {
      const earlier = [new TritonBuilder(), new TritonBuilder()];
      triton.logs = [...earlier];

      // Never rejects, even when handed something that is not a builder
      await expect(triton.logNow(notABuilder)).resolves.toBeUndefined();

      expect(saveComponentLogs).not.toHaveBeenCalled();
      expect(triton.logs).toHaveLength(2);
      expect(triton.logs[0]).toBe(earlier[0]);
      expect(triton.logs[1]).toBe(earlier[1]);
      expect(console.error).toHaveBeenCalledWith(expect.stringContaining('needs a builder'), expect.any(TypeError));
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
      
      await expect(triton.flush()).resolves.toBeUndefined();
      expect(triton.logs).toEqual(mockLogs); // Logs restored
    });
  });

  describe('Flush failure policy', () => {
    beforeEach(() => {
      saveComponentLogs.mockReset();
    });

    test('flush resolves and keeps the logs on a first failure', async () => {
      const error = new Error('offline');
      saveComponentLogs.mockRejectedValue(error);
      const logs = [new TritonBuilder(), new TritonBuilder()];
      triton.logs = [...logs];

      await expect(triton.flush()).resolves.toBeUndefined();

      expect(triton.logs).toEqual(logs);
      expect(console.error).toHaveBeenCalledWith(expect.stringContaining('logs kept'), error);
    });

    test('drops the failed batch on the third consecutive failure', async () => {
      const error = new Error('offline');
      saveComponentLogs.mockRejectedValue(error);
      triton.logs = [new TritonBuilder()];

      await triton.flush();
      await triton.flush();
      expect(triton.logs).toHaveLength(1);

      await triton.flush();

      expect(saveComponentLogs).toHaveBeenCalledTimes(3);
      expect(triton.logs).toEqual([]);
      expect(console.error).toHaveBeenCalledWith(expect.stringContaining('dropping 1 log'), error);
    });

    test('a successful flush resets the failure count', async () => {
      const error = new Error('offline');
      saveComponentLogs
        .mockRejectedValueOnce(error)
        .mockRejectedValueOnce(error)
        .mockResolvedValueOnce({ success: true })
        .mockRejectedValueOnce(error)
        .mockRejectedValueOnce(error);
      triton.logs = [new TritonBuilder()];

      await triton.flush();
      await triton.flush();
      await triton.flush();
      expect(triton.logs).toEqual([]);

      const kept = new TritonBuilder();
      triton.logs = [kept];
      await triton.flush();
      await triton.flush();

      // Two failures since the success, not four in a row: still kept
      expect(triton.logs).toHaveLength(1);
      expect(triton.logs[0]).toBe(kept);
    });

    test('the restored buffer is capped at MAX_BUFFERED_LOGS, oldest dropped', async () => {
      saveComponentLogs.mockRejectedValue(new Error('offline'));
      const logs = Array.from({ length: Triton.MAX_BUFFERED_LOGS + 5 }, () => new TritonBuilder());
      triton.logs = [...logs];

      await triton.flush();

      expect(triton.logs).toHaveLength(Triton.MAX_BUFFERED_LOGS);
      expect(triton.logs[0]).toBe(logs[5]);
      expect(triton.logs[triton.logs.length - 1]).toBe(logs[logs.length - 1]);
      expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('dropped the 5 oldest'));
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
    test('AREA values are the Apex TritonTypes.Area names', () => {
      // LWC logs group with the Apex and Flow logs of the same feature only when the
      // strings match the server-side enum names exactly.
      expect(AREA).toEqual({
        ACCOUNTS: 'Accounts',
        COMMUNITY: 'Community',
        LEAD_CONVERSION: 'LeadConversion',
        OPPORTUNITY_MANAGEMENT: 'OpportunityManagement',
        REST_API: 'RestAPI'
      });
    });

    test('should export CATEGORY constants', () => {
      expect(CATEGORY.LWC).toBe('LWC');
      expect(CATEGORY.AURA).toBe('Aura');
      expect(Object.keys(CATEGORY)).toHaveLength(2);
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
    // The singleton keeps its failure count across tests
    triton.failedFlushes = 0;
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
    // The singleton keeps its failure count across tests
    triton.failedFlushes = 0;
    triton.logs = [];
  });

  afterEach(() => {
    jest.useRealTimers();
    // Spies on the singleton outlive the test unless restored
    if (jest.isMockFunction(triton.flush)) {
      triton.flush.mockRestore();
    }
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

  test('stop() never rejects when the final flush fails', async () => {
    jest.spyOn(triton, 'flush').mockRejectedValue(new Error('offline'));

    await expect(triton.transactionManager.stop()).resolves.toBeUndefined();
  });

  test('restarting the monitor leaves a single polling loop', () => {
    const flushSpy = jest.spyOn(triton, 'flush').mockResolvedValue();

    triton.transactionManager.start();
    triton.transactionManager.start();

    const oldBuilder = new TritonBuilder();
    oldBuilder._createdTimestamp = Date.now() - 15000; // 15 seconds ago
    triton.logs.push(oldBuilder);

    jest.advanceTimersByTime(5000);

    expect(flushSpy).toHaveBeenCalledTimes(1);
  });
});

describe('PerformanceTracker', () => {
  let triton;
  let boundTriton;

  beforeEach(() => {
    jest.clearAllMocks();
    triton = new Triton();
    // The singleton keeps its failure count across tests
    triton.failedFlushes = 0;
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

    boundTriton.log(boundTriton.info(TYPE.FRONTEND, AREA.ACCOUNTS).summary('work'));

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

describe('Profiling defaults', () => {
  // Profiling records carry fixed levels, so one Log_Level__mdt threshold selects a
  // verbosity tier: spans at FINE (as Apex marks), failures at ERROR, lifecycle at
  // FINER, render at FINEST.
  let triton;
  let boundTriton;
  let mockApexCall;

  beforeEach(() => {
    jest.clearAllMocks();
    triton = new Triton();
    // The singleton keeps its failure count across tests
    triton.failedFlushes = 0;
    triton.logs = [];
    triton.templates.clear();
    boundTriton = triton.bindToComponent('testComponent');
    mockApexCall = jest.fn();

    let timeCounter = 1000;
    window.performance.now = jest.fn(() => timeCounter += 100);
  });

  test('backend call started and completed records log at FINE', async () => {
    mockApexCall.mockResolvedValue('ok');

    await boundTriton.timeBackendCall('loadData', mockApexCall).execute();

    expect(triton.logs).toHaveLength(2);
    const [started, completed] = triton.logs;
    expect(started.summary).toHaveBeenCalledWith('Backend call started: loadData');
    expect(started.level).toHaveBeenLastCalledWith(LEVEL.FINE);
    expect(completed.summary).toHaveBeenCalledWith('Backend call completed: loadData');
    expect(completed.level).toHaveBeenLastCalledWith(LEVEL.FINE);
  });

  test('a failed backend call logs at ERROR', async () => {
    const error = new Error('Backend error');
    mockApexCall.mockRejectedValue(error);

    await boundTriton.timeBackendCall('loadData', mockApexCall).withoutRethrow().execute();

    const failedRecord = triton.logs[triton.logs.length - 1];
    expect(failedRecord.summary).toHaveBeenCalledWith('Backend call failed: loadData');
    expect(failedRecord.exception).toHaveBeenCalledWith(error);
    expect(failedRecord.level).toHaveBeenLastCalledWith(LEVEL.ERROR);
  });

  test('a failed user interaction logs at ERROR', async () => {
    const error = new Error('Click failed');
    const interaction = jest.fn().mockRejectedValue(error);

    await boundTriton.timeUserInteraction('save', interaction).withoutRethrow().execute();

    const failedRecord = triton.logs[triton.logs.length - 1];
    expect(failedRecord.summary).toHaveBeenCalledWith('User interaction failed: save');
    expect(failedRecord.exception).toHaveBeenCalledWith(error);
    expect(failedRecord.level).toHaveBeenLastCalledWith(LEVEL.ERROR);
  });

  test('a call rejected with no reason is logged, and resolves null without rethrow', async () => {
    mockApexCall.mockRejectedValue(undefined);

    const result = await boundTriton.timeBackendCall('loadData', mockApexCall).withoutRethrow().execute();

    expect(result).toBeNull();
    const failedRecord = triton.logs[triton.logs.length - 1];
    expect(failedRecord.summary).toHaveBeenCalledWith('Backend call failed: loadData');
    expect(failedRecord.exception).toHaveBeenCalledWith(undefined);
    expect(failedRecord.level).toHaveBeenLastCalledWith(LEVEL.ERROR);
  });

  test('performance mark records log at FINE', () => {
    boundTriton.startPerformanceMark('m');
    boundTriton.endPerformanceMark('m');

    expect(triton.logs).toHaveLength(2);
    const [opening, completion] = triton.logs;
    expect(opening.level).toHaveBeenLastCalledWith(LEVEL.FINE);
    expect(completion.level).toHaveBeenLastCalledWith(LEVEL.FINE);
  });

  test('lifecycle records log at FINER', () => {
    boundTriton.trackComponentLifecycle('connected');

    expect(triton.logs).toHaveLength(1);
    expect(triton.logs[0].level).toHaveBeenLastCalledWith(LEVEL.FINER);
  });

  test('render records log at FINEST', () => {
    boundTriton.trackComponentRender();

    expect(triton.logs).toHaveLength(1);
    expect(triton.logs[0].level).toHaveBeenLastCalledWith(LEVEL.FINEST);
  });

  test('profiling records start from the component template', () => {
    const template = new TritonBuilder();
    boundTriton.setTemplate(template);

    boundTriton.startPerformanceMark('m');

    expect(template.clone).toHaveBeenCalled();
    const opening = triton.logs[triton.logs.length - 1];
    expect(opening).toBe(template.clone.mock.results[0].value);
    expect(opening.level).toHaveBeenLastCalledWith(LEVEL.FINE);
  });

  test('every profiling record starts from the component template', async () => {
    // So each one inherits the component's Area, whichever helper wrote it.
    const template = new TritonBuilder();
    boundTriton.setTemplate(template);
    mockApexCall.mockResolvedValueOnce('ok').mockRejectedValueOnce(new Error('Backend error'));

    boundTriton.startPerformanceMark('m');
    boundTriton.endPerformanceMark('m');
    boundTriton.trackComponentLifecycle('connected');
    boundTriton.trackComponentRender();
    await boundTriton.timeBackendCall('loadData', mockApexCall).execute();
    await boundTriton.timeBackendCall('loadData', mockApexCall).withoutRethrow().execute();

    // mark open + close, lifecycle, render, call started + completed, call started + failed
    expect(triton.logs).toHaveLength(8);
    const clones = template.clone.mock.results.map(result => result.value);
    triton.logs.forEach(record => expect(clones).toContain(record));
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
    // The singleton keeps its failure count across tests
    triton.failedFlushes = 0;
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