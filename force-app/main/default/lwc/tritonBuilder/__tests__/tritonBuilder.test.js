/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import TritonBuilder from '../tritonBuilder';

// Mock the tritonUtils module
jest.mock('c/tritonUtils', () => ({
  isNotTriton: jest.fn(),
  getFunctionName: jest.fn()
}));

import { isNotTriton, getFunctionName } from 'c/tritonUtils';

describe('TritonBuilder', () => {
  let builder;

  beforeEach(() => {
    builder = new TritonBuilder();
    jest.clearAllMocks();
  });

  describe('Constructor', () => {
    test('should create a new TritonBuilder instance', () => {
      expect(builder).toBeInstanceOf(TritonBuilder);
    });
  });

  describe('Setter Methods', () => {
    test('level() should set the log level and return builder for chaining', () => {
      const result = builder.level('ERROR');
      
      expect(result).toBe(builder);
      expect(builder._level).toBe('ERROR');
    });

    test('category() should set the log category and return builder for chaining', () => {
      const result = builder.category('SYSTEM');
      
      expect(result).toBe(builder);
      expect(builder._category).toBe('SYSTEM');
    });

    test('type() should set the log type and return builder for chaining', () => {
      const result = builder.type('PERFORMANCE');
      
      expect(result).toBe(builder);
      expect(builder._type).toBe('PERFORMANCE');
    });

    test('area() should set the log area and return builder for chaining', () => {
      const result = builder.area('FRONTEND');
      
      expect(result).toBe(builder);
      expect(builder._area).toBe('FRONTEND');
    });

    test('summary() should set the log summary and return builder for chaining', () => {
      const result = builder.summary('Test summary');
      
      expect(result).toBe(builder);
      expect(builder._summary).toBe('Test summary');
    });

    test('details() should set the log details and return builder for chaining', () => {
      const result = builder.details('Test details');
      
      expect(result).toBe(builder);
      expect(builder._details).toBe('Test details');
    });

    test('transactionId() should set the transaction ID and return builder for chaining', () => {
      const result = builder.transactionId('txn-123');
      
      expect(result).toBe(builder);
      expect(builder._transactionId).toBe('txn-123');
    });

    test('duration() should set the duration and return builder for chaining', () => {
      const result = builder.duration(1500);
      
      expect(result).toBe(builder);
      expect(builder._duration).toBe(1500);
    });

    test('action() should set the action and return builder for chaining', () => {
      const result = builder.action('button-click');
      
      expect(result).toBe(builder);
      expect(builder._action).toBe('button-click');
    });

    test('timestamp() should set the timestamp and return builder for chaining', () => {
      const timestamp = Date.now();
      const result = builder.timestamp(timestamp);
      
      expect(result).toBe(builder);
      expect(builder._createdTimestamp).toBe(timestamp);
    });

    test('userId() should set the user ID and return builder for chaining', () => {
      const result = builder.userId('user-456');
      
      expect(result).toBe(builder);
      expect(builder._userId).toBe('user-456');
    });

    test('runtimeInfo() should set runtime information and return builder for chaining', () => {
      const runtimeInfo = { browser: 'Chrome', version: '96.0' };
      const result = builder.runtimeInfo(runtimeInfo);
      
      expect(result).toBe(builder);
      expect(builder._runtimeInfo).toBe(runtimeInfo);
    });

    test('runtimeInfo() should handle undefined input with default empty object', () => {
      const result = builder.runtimeInfo();
      
      expect(result).toBe(builder);
      expect(builder._runtimeInfo).toEqual({});
    });
  });

  describe('relatedObjects()', () => {
    test('should handle single object ID', () => {
      const result = builder.relatedObjects('obj-123');
      
      expect(result).toBe(builder);
      expect(builder._relatedObjectIds).toEqual(['obj-123']);
    });

    test('should handle array of object IDs', () => {
      const ids = ['obj-123', 'obj-456', 'obj-789'];
      const result = builder.relatedObjects(ids);
      
      expect(result).toBe(builder);
      expect(builder._relatedObjectIds).toEqual(ids);
    });

    test('should filter out null/undefined/empty values', () => {
      const ids = ['obj-123', null, '', undefined, 'obj-456'];
      const result = builder.relatedObjects(ids);
      
      expect(result).toBe(builder);
      expect(builder._relatedObjectIds).toEqual(['obj-123', 'obj-456']);
    });

    test('should handle null input gracefully', () => {
      const result = builder.relatedObjects(null);
      
      expect(result).toBe(builder);
      expect(builder._relatedObjectIds).toBeUndefined();
    });

    test('should handle empty array', () => {
      const result = builder.relatedObjects([]);
      
      expect(result).toBe(builder);
      expect(builder._relatedObjectIds).toBeUndefined();
    });
  });

  describe('exception()', () => {
    beforeEach(() => {
      isNotTriton.mockReturnValue(true);
      getFunctionName.mockReturnValue('testFunction');
    });

    test('should handle error with body property (Salesforce format)', () => {
      const error = {
        body: {
          message: 'Salesforce error message',
          stackTrace: 'at testFunction (test.js:10:5)',
          exceptionType: 'System.DmlException'
        }
      };

      const result = builder.exception(error);

      expect(result).toBe(builder);
      expect(builder._error).toEqual({
        message: 'Salesforce error message',
        stack: 'at testFunction (test.js:10:5)',
        type: 'System.DmlException'
      });
      expect(builder._details).toBe('Salesforce error message');
      expect(builder._summary).toBe('Salesforce error message');
    });

    test('should handle standard JavaScript error', () => {
      const error = new Error('Standard error message');
      error.name = 'TypeError';
      error.stack = 'Error: Standard error message\n    at testFunction (test.js:10:5)';

      const result = builder.exception(error);

      expect(result).toBe(builder);
      expect(builder._error).toEqual({
        message: 'Standard error message',
        stack: 'Error: Standard error message\n    at testFunction (test.js:10:5)',
        type: 'TypeError'
      });
      expect(builder._details).toBe('Standard error message');
      expect(builder._summary).toBe('Standard error message');
    });

    test('should handle error with stacktrace property instead of stack', () => {
      const error = {
        message: 'Error with stacktrace',
        stacktrace: 'at testFunction (test.js:10:5)',
        name: 'CustomError'
      };

      const result = builder.exception(error);

      expect(result).toBe(builder);
      expect(builder._error).toEqual({
        message: 'Error with stacktrace',
        stack: 'at testFunction (test.js:10:5)',
        type: 'CustomError'
      });
    });

    test('should append to existing details and summary', () => {
      builder.details('Existing details. ');
      builder.summary('Existing summary');

      const error = new Error('New error');
      builder.exception(error);

      expect(builder._details).toBe('Existing details. New error');
      expect(builder._summary).toBe('Existing summary');
    });

    test('should handle error with missing properties gracefully', () => {
      const error = {};
      const result = builder.exception(error);

      expect(result).toBe(builder);
      expect(builder._error).toEqual({
        message: null,
        stack: null,
        type: null
      });
    });

    test('should call componentDetails with stack trace', () => {
      const error = new Error('Test error');
      error.stack = 'Error: Test error\n    at testFunction (test.js:10:5)';

      builder.exception(error);

      expect(isNotTriton).toHaveBeenCalled();
      expect(getFunctionName).toHaveBeenCalled();
    });
  });

  describe('componentDetails()', () => {
    beforeEach(() => {
      isNotTriton.mockImplementation(line => !line.includes('c/triton'));
      getFunctionName.mockReturnValue('extractedFunction');
    });

    test('should process stack trace and extract function name', () => {
      const stack = 'Error: Test error\n    at extractedFunction (component.js:10:5)\n    at caller (caller.js:20:10)';
      
      const result = builder.componentDetails(stack);

      expect(result).toBe(builder);
      expect(isNotTriton).toHaveBeenCalledWith('    at extractedFunction (component.js:10:5)');
      expect(getFunctionName).toHaveBeenCalledWith('    at extractedFunction (component.js:10:5)');
      expect(builder._componentInfo.function).toBe('extractedFunction');
      expect(builder._stack).toBe('    at extractedFunction (component.js:10:5)\n    at caller (caller.js:20:10)');
    });

    test('should filter out triton components from stack trace', () => {
      isNotTriton.mockImplementation(line => 
        !line.includes('c/triton') && !line.includes('c/tritonBuilder')
      );

      const stack = 'Error: Test error\n    at c/triton.js:50:10\n    at userFunction (user.js:10:5)';
      
      builder.componentDetails(stack);

      expect(builder._componentInfo.function).toBe('extractedFunction');
      expect(builder._stack).toBe('    at userFunction (user.js:10:5)');
    });

    test('should handle empty stack trace', () => {
      const result = builder.componentDetails('');

      expect(result).toBe(builder);
      expect(builder._componentInfo.function).toBe('');
      expect(builder._stack).toBeUndefined();
    });

    test('should handle single line stack trace', () => {
      isNotTriton.mockReturnValue(true);
      const stack = 'Error: Test error';
      
      builder.componentDetails(stack);

      expect(builder._componentInfo.function).toBe('');
    });

    test('should initialize componentInfo if not exists', () => {
      expect(builder._componentInfo).toBeUndefined();
      
      builder.componentDetails('test stack');
      
      expect(builder._componentInfo).toBeDefined();
      expect(typeof builder._componentInfo).toBe('object');
    });

    test('should preserve existing componentInfo properties', () => {
      builder._componentInfo = { existingProp: 'value' };
      
      builder.componentDetails('Error: Test\n    at func (file.js:1:1)');
      
      expect(builder._componentInfo.existingProp).toBe('value');
      expect(builder._componentInfo.function).toBeDefined();
    });
  });

  describe('clone()', () => {
    test('should create a deep clone of the builder', () => {
      // Set up original builder with various properties
      builder
        .level('ERROR')
        .category('SYSTEM')
        .type('PERFORMANCE')
        .area('FRONTEND')
        .summary('Original summary')
        .details('Original details')
        .transactionId('txn-123')
        .duration(1500)
        .action('click')
        .timestamp(12345)
        .userId('user-456')
        .relatedObjects(['obj-1', 'obj-2'])
        .runtimeInfo({ browser: 'Chrome' });

      builder._componentInfo = { function: 'testFunc' };
      builder._error = { message: 'test error' };
      builder._stack = 'test stack';

      const cloned = builder.clone();

      expect(cloned).toBeInstanceOf(TritonBuilder);
      expect(cloned).not.toBe(builder);
      
      // Check all properties are copied
      expect(cloned._level).toBe('ERROR');
      expect(cloned._category).toBe('SYSTEM');
      expect(cloned._type).toBe('PERFORMANCE');
      expect(cloned._area).toBe('FRONTEND');
      expect(cloned._summary).toBe('Original summary');
      expect(cloned._details).toBe('Original details');
      expect(cloned._transactionId).toBe('txn-123');
      expect(cloned._duration).toBe(1500);
      expect(cloned._action).toBe('click');
      expect(cloned._createdTimestamp).toBe(12345);
      expect(cloned._userId).toBe('user-456');
      expect(cloned._relatedObjectIds).toEqual(['obj-1', 'obj-2']);
      expect(cloned._runtimeInfo).toEqual({ browser: 'Chrome' });
      expect(cloned._componentInfo).toEqual({ function: 'testFunc' });
      expect(cloned._error).toEqual({ message: 'test error' });
      expect(cloned._stack).toBe('test stack');
    });

    test('should create independent objects (deep clone)', () => {
      builder._runtimeInfo = { browser: 'Chrome', version: '96' };
      builder._componentInfo = { function: 'testFunc', line: 10 };
      builder._error = { message: 'error', type: 'TypeError' };

      const cloned = builder.clone();

      // Modify original objects
      builder._runtimeInfo.browser = 'Firefox';
      builder._componentInfo.function = 'newFunc';
      builder._error.message = 'new error';

      // Cloned objects should remain unchanged
      expect(cloned._runtimeInfo.browser).toBe('Chrome');
      expect(cloned._componentInfo.function).toBe('testFunc');
      expect(cloned._error.message).toBe('error');
    });

    test('should handle builder with no properties set', () => {
      const cloned = builder.clone();

      expect(cloned).toBeInstanceOf(TritonBuilder);
      expect(cloned).not.toBe(builder);
    });

    test('should not copy function properties', () => {
      builder.testFunction = () => 'test';
      
      const cloned = builder.clone();

      expect(cloned.testFunction).toBeUndefined();
    });
  });

  describe('build()', () => {
    test('should return object with all builder properties', () => {
      const timestamp = Date.now();
      const runtimeInfo = { browser: 'Chrome' };
      const componentInfo = { function: 'testFunc' };
      const error = { message: 'test error' };

      builder
        .level('ERROR')
        .category('SYSTEM')
        .type('PERFORMANCE')
        .area('FRONTEND')
        .summary('Test summary')
        .details('Test details')
        .transactionId('txn-123')
        .duration(1500)
        .action('click')
        .timestamp(timestamp)
        .userId('user-456')
        .relatedObjects(['obj-1'])
        .runtimeInfo(runtimeInfo);

      builder._componentInfo = componentInfo;
      builder._error = error;
      builder._stack = 'test stack';

      const result = builder.build();

      expect(result).toEqual({
        level: 'ERROR',
        category: 'SYSTEM',
        type: 'PERFORMANCE',
        area: 'FRONTEND',
        summary: 'Test summary',
        details: 'Test details',
        transactionId: 'txn-123',
        componentInfo: componentInfo,
        duration: 1500,
        action: 'click',
        createdTimestamp: timestamp,
        error: error,
        stack: 'test stack',
        userId: 'user-456',
        runtimeInfo: runtimeInfo,
        relatedObjectIds: ['obj-1']
      });
    });

    test('should return object with undefined values for unset properties', () => {
      const result = builder.build();

      expect(result).toEqual({
        level: undefined,
        category: undefined,
        type: undefined,
        area: undefined,
        summary: undefined,
        details: undefined,
        transactionId: undefined,
        componentInfo: undefined,
        duration: undefined,
        action: undefined,
        createdTimestamp: undefined,
        error: undefined,
        stack: undefined,
        userId: undefined,
        runtimeInfo: undefined,
        relatedObjectIds: undefined
      });
    });

    test('should not modify the builder instance', () => {
      builder.level('INFO').summary('Test');
      const originalLevel = builder._level;
      const originalSummary = builder._summary;

      const result = builder.build();

      expect(builder._level).toBe(originalLevel);
      expect(builder._summary).toBe(originalSummary);
      expect(result).not.toBe(builder);
    });
  });

  describe('Method Chaining', () => {
    test('should allow full method chaining', () => {
      const result = builder
        .level('INFO')
        .category('USER')
        .type('ACTION')
        .area('FRONTEND')
        .summary('User clicked button')
        .details('User clicked the submit button on the form')
        .transactionId('txn-789')
        .duration(250)
        .action('button-click')
        .timestamp(12345)
        .userId('user-123')
        .relatedObjects(['form-1', 'button-1'])
        .runtimeInfo({ browser: 'Safari' });

      expect(result).toBe(builder);
      
      const built = result.build();
      expect(built.level).toBe('INFO');
      expect(built.category).toBe('USER');
      expect(built.type).toBe('ACTION');
      expect(built.area).toBe('FRONTEND');
      expect(built.summary).toBe('User clicked button');
      expect(built.details).toBe('User clicked the submit button on the form');
      expect(built.transactionId).toBe('txn-789');
      expect(built.duration).toBe(250);
      expect(built.action).toBe('button-click');
      expect(built.createdTimestamp).toBe(12345);
      expect(built.userId).toBe('user-123');
      expect(built.relatedObjectIds).toEqual(['form-1', 'button-1']);
      expect(built.runtimeInfo).toEqual({ browser: 'Safari' });
    });
  });

  describe('Edge Cases', () => {
    test('should handle falsy values correctly', () => {
      builder
        .level('')
        .category(null)
        .summary(0)
        .duration(0)
        .timestamp(0);

      const result = builder.build();

      expect(result.level).toBe('');
      expect(result.category).toBe(null);
      expect(result.summary).toBe(0);
      expect(result.duration).toBe(0);
      expect(result.createdTimestamp).toBe(0);
    });

    test('should handle special characters in strings', () => {
      const specialString = 'Test with "quotes" and \n newlines \t tabs';
      
      builder.summary(specialString).details(specialString);

      const result = builder.build();

      expect(result.summary).toBe(specialString);
      expect(result.details).toBe(specialString);
    });

    test('should handle very large numbers', () => {
      const largeNumber = Number.MAX_SAFE_INTEGER;
      
      builder.duration(largeNumber).timestamp(largeNumber);

      const result = builder.build();

      expect(result.duration).toBe(largeNumber);
      expect(result.createdTimestamp).toBe(largeNumber);
    });
  });
});
