/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import { 
  isNotTriton, 
  getFunctionName, 
  generateTransactionId, 
  captureRuntimeInfo 
} from '../tritonUtils';

describe('tritonUtils', () => {
  
  describe('isNotTriton()', () => {
    test('should return false for triton component stack traces', () => {
      const tritonLines = [
        'at someFunction (c/triton.js:123:45)',
        'at anotherFunction (c/tritonBuilder.js:67:89)',
        'at helperFunction (c/tritonHelper.js:12:34)',
        'at utilFunction (c/tritonUtils.js:56:78)'
      ];

      tritonLines.forEach(line => {
        expect(isNotTriton(line)).toBe(false);
      });
    });

    test('should return false for triton method names', () => {
      const tritonMethodLines = [
        'at makeBuilder (someFile.js:123:45)',
        'at refreshBuilder (someFile.js:67:89)',
        'at debug (someFile.js:12:34)',
        'at info (someFile.js:56:78)',
        'at warning (someFile.js:90:12)',
        'at error (someFile.js:34:56)',
        'at exception (someFile.js:78:90)',
        'at log (someFile.js:23:45)',
        'at logNow (someFile.js:67:89)'
      ];

      tritonMethodLines.forEach(line => {
        expect(isNotTriton(line)).toBe(false);
      });
    });

    test('should return true for non-triton stack traces', () => {
      const nonTritonLines = [
        'at userFunction (c/userComponent.js:123:45)',
        'at customMethod (c/customHelper.js:67:89)',
        'at businessLogic (c/businessComponent.js:12:34)',
        'at handleClick (c/buttonComponent.js:56:78)',
        'at processData (utils/dataProcessor.js:90:12)'
      ];

      nonTritonLines.forEach(line => {
        expect(isNotTriton(line)).toBe(true);
      });
    });

    test('should handle empty or undefined input', () => {
      expect(isNotTriton('')).toBe(true);
      expect(isNotTriton(undefined)).toBe(true);
      expect(isNotTriton(null)).toBe(true);
    });

    test('should be case sensitive', () => {
      expect(isNotTriton('at someFunction (c/TRITON.js:123:45)')).toBe(true);
      expect(isNotTriton('at MAKEBUILDER (someFile.js:123:45)')).toBe(true);
    });
  });

  describe('getFunctionName()', () => {
    test('should extract function name from standard stack trace format', () => {
      const testCases = [
        {
          input: 'at functionName (file.js:123:45)',
          expected: 'functionName'
        },
        {
          input: 'at Object.methodName (component.js:67:89)',
          expected: 'Object.methodName'
        },
        {
          input: 'at ClassName.prototype.methodName (class.js:12:34)',
          expected: 'ClassName.prototype.methodName'
        },
        {
          input: '    at deeply.nested.function.name (nested.js:56:78)',
          expected: 'deeply.nested.function.name'
        }
      ];

      testCases.forEach(({ input, expected }) => {
        expect(getFunctionName(input)).toBe(expected);
      });
    });

    test('should handle anonymous functions', () => {
      expect(getFunctionName('at <anonymous> (file.js:123:45)')).toBe('<anonymous>');
    });

    test('should return empty string for malformed stack traces', () => {
      const malformedLines = [
        'malformed stack trace line',
        'at functionName file.js:123:45', // missing parentheses
        '',
        'at functionName'
      ];

      malformedLines.forEach(line => {
        expect(getFunctionName(line)).toBe('');
      });
    });

    test('should handle stack traces without closing parentheses', () => {
      expect(getFunctionName('functionName (file.js:123:45')).toBe('');
    });

    test('should trim whitespace from extracted function names', () => {
      expect(getFunctionName('at   spacedFunction   (file.js:123:45)')).toBe('spacedFunction');
    });

    test('should handle complex function names with special characters', () => {
      const testCases = [
        'at $specialFunction (file.js:123:45)',
        'at _privateMethod (file.js:123:45)',
        'at function123 (file.js:123:45)',
        'at my-function (file.js:123:45)'
      ];

      testCases.forEach(line => {
        const functionName = getFunctionName(line);
        expect(functionName).toBeTruthy();
        expect(functionName.length).toBeGreaterThan(0);
      });
    });
  });

  describe('generateTransactionId()', () => {
    test('should generate a valid UUID v4 format', () => {
      const uuid = generateTransactionId();
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      
      expect(uuid).toMatch(uuidRegex);
    });

    test('should generate unique UUIDs', () => {
      const uuids = new Set();
      const iterations = 100;

      for (let i = 0; i < iterations; i++) {
        uuids.add(generateTransactionId());
      }

      expect(uuids.size).toBe(iterations);
    });

    test('should always have version 4 in the correct position', () => {
      const uuid = generateTransactionId();
      expect(uuid.charAt(14)).toBe('4');
    });

    test('should have correct variant bits', () => {
      const uuid = generateTransactionId();
      const variantChar = uuid.charAt(19);
      expect(['8', '9', 'a', 'b']).toContain(variantChar);
    });

    test('should return string of correct length', () => {
      const uuid = generateTransactionId();
      expect(uuid).toHaveLength(36);
    });
  });

  describe('captureRuntimeInfo()', () => {
    let consoleSpy;

    beforeEach(() => {
      consoleSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    });

    afterEach(() => {
      consoleSpy.mockRestore();
    });

    test('should return an object', () => {
      const info = captureRuntimeInfo();
      expect(typeof info).toBe('object');
      expect(info).not.toBeNull();
    });

    test('should capture available browser information', () => {
      const info = captureRuntimeInfo();
      
      // Test that the function runs without throwing
      expect(info).toBeDefined();
      
      // Test that it captures some of the expected properties that should be available in jsdom
      if (typeof navigator !== 'undefined') {
        expect(info.userAgent).toBeDefined();
        expect(info.language).toBeDefined();
      }
      
      if (typeof window !== 'undefined') {
        expect(info.viewportWidth).toBeDefined();
        expect(info.viewportHeight).toBeDefined();
      }
    });

    test('should handle missing APIs gracefully without throwing', () => {
      // Mock navigator to throw an error
      const originalNavigator = global.navigator;
      Object.defineProperty(global, 'navigator', {
        get() {
          throw new Error('Navigator not available');
        },
        configurable: true
      });

      expect(() => {
        const info = captureRuntimeInfo();
        expect(typeof info).toBe('object');
      }).not.toThrow();

      // Restore original navigator
      Object.defineProperty(global, 'navigator', {
        value: originalNavigator,
        configurable: true,
        writable: true
      });
    });

    test('should capture theme information when available', () => {
      const info = captureRuntimeInfo();
      
      // Should have theme property (either from document or default)
      if (typeof document !== 'undefined' && document.documentElement) {
        expect(info.theme).toBeDefined();
      }
    });

    test('should capture performance metrics when available', () => {
      const info = captureRuntimeInfo();
      
      // Check if performance metrics are captured when available
      if (typeof window !== 'undefined' && window.performance) {
        // These might be defined if performance API is available
        expect(info.memoryUsage).toBeDefined();
        expect(info.memoryLimit).toBeDefined();
      }
    });

    test('should capture network information when available', () => {
      const info = captureRuntimeInfo();
      
      // Test online status
      if (typeof navigator !== 'undefined') {
        expect(typeof info.isOnline).toBe('boolean');
      }
      
      // Test location info when available
      if (typeof window !== 'undefined' && window.location) {
        expect(info.pathname).toBeDefined();
        expect(info.hostname).toBeDefined();
      }
    });

    test('should determine form factor based on screen width', () => {
      const info = captureRuntimeInfo();
      
      if (typeof window !== 'undefined' && window.screen) {
        expect(['SMALL', 'MEDIUM', 'LARGE']).toContain(info.formFactor);
        expect(typeof info.screenWidth).toBe('number');
        expect(typeof info.screenHeight).toBe('number');
      }
    });

    test('should not crash when APIs are partially available', () => {
      // This test ensures the function is robust
      expect(() => {
        const info = captureRuntimeInfo();
        expect(info).toBeDefined();
      }).not.toThrow();
    });
  });
});