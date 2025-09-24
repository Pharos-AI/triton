# Testing Guide for Triton

This guide covers how to run the Jest unit tests for the Triton Lightning Web Components.

## Setup

### Install Dependencies

First, install the required testing dependencies:

```bash
npm install
```

This will install Jest, Babel, and other testing utilities defined in `package.json`.

### Project Structure

The test files are organized as follows:

```
force-app/main/default/lwc/
├── tritonBuilder/
│   ├── __tests__/
│   │   └── tritonBuilder.test.js
│   ├── tritonBuilder.js
│   └── tritonBuilder.js-meta.xml
└── tritonUtils/
    ├── __tests__/
    │   └── tritonUtils.test.js
    ├── tritonUtils.js
    └── tritonUtils.js-meta.xml
```

## Running Tests

### Run All Tests

```bash
npm test
```

### Run Tests in Watch Mode

```bash
npm run test:watch
```

This will automatically re-run tests when files change.

### Run Tests with Coverage Report

```bash
npm run test:coverage
```

This generates a coverage report showing which lines of code are covered by tests.

### Run Specific Test Files

```bash
# Run only TritonBuilder tests
npx jest tritonBuilder

# Run only TritonUtils tests
npx jest tritonUtils
```

## Test Coverage

The test suite covers:

### TritonBuilder (`tritonBuilder.test.js`)

- ✅ Constructor and instance creation
- ✅ All setter methods (level, category, type, area, etc.)
- ✅ Method chaining functionality
- ✅ Exception handling with different error formats
- ✅ Component details extraction from stack traces
- ✅ Related objects handling (single IDs, arrays, filtering)
- ✅ Builder cloning (deep clone functionality)
- ✅ Build method (final object construction)
- ✅ Edge cases (falsy values, special characters, large numbers)

### TritonUtils (`tritonUtils.test.js`)

- ✅ `isNotTriton()` - Stack trace filtering
- ✅ `getFunctionName()` - Function name extraction
- ✅ `generateTransactionId()` - UUID v4 generation
- ✅ `captureRuntimeInfo()` - Runtime environment capture
- ✅ Error handling and graceful degradation
- ✅ Browser API mocking and edge cases

### Triton (`triton.test.js`)

- ✅ Constructor and singleton pattern
- ✅ Component binding with proxy pattern
- ✅ Template management (setTemplate/fromTemplate)
- ✅ Transaction management (start/resume/stop)
- ✅ Log level methods (error, warning, info, debug, exception)
- ✅ Builder creation and refresh functionality
- ✅ Logging methods (log, logNow, flush)
- ✅ Performance tracking integration
- ✅ Salesforce API integration with proper mocking
- ✅ Constants and enumerations (AREA, CATEGORY, LEVEL, TYPE)

### PerformanceCallBuilder (`triton.test.js`)

- ✅ Backend call timing and error handling
- ✅ User interaction timing and logging
- ✅ Custom error handlers
- ✅ Rethrow configuration
- ✅ Component binding requirements

### TransactionManager (`triton.test.js`)

- ✅ Transaction initialization and persistence
- ✅ Storage error handling (sessionStorage fallback)
- ✅ Auto-flush monitoring with timers
- ✅ Transaction lifecycle management

### PerformanceTracker (`triton.test.js`)

- ✅ Performance mark creation and timing
- ✅ Component lifecycle tracking
- ✅ Render performance monitoring
- ✅ Multiple component instance handling
- ✅ Browser API fallbacks (performance.now unavailability)

## Mocking Strategy

### Dependency Mocking

**TritonUtils**: Mocked in TritonBuilder and Triton tests:
```javascript
jest.mock('c/tritonUtils', () => ({
  isNotTriton: jest.fn(),
  getFunctionName: jest.fn(),
  generateTransactionId: jest.fn(() => 'mock-transaction-id'),
  captureRuntimeInfo: jest.fn(() => ({ mockRuntimeInfo: true }))
}));
```

**TritonBuilder**: Mocked in Triton tests with full method chaining:
```javascript
jest.mock('c/tritonBuilder', () => {
  return jest.fn().mockImplementation(() => ({
    level: jest.fn().mockReturnThis(),
    category: jest.fn().mockReturnThis(),
    // ... all builder methods
  }));
});
```

**Salesforce APIs**: Mocked using module name mapping in `jest.config.js`:
- `@salesforce/apex/TritonLwc.saveComponentLogs` → Mock file
- `@salesforce/user/Id` → Mock file

### Browser APIs

Browser APIs are mocked in `jest.setup.js` and individual tests:
- `window.performance` (with fallback handling)
- `window.navigator` (with connection info)
- `window.screen` (with orientation)
- `window.location` (with pathname/hostname)
- `window.sessionStorage` (with error handling)
- `document.documentElement` (with theme attributes)

## Configuration Files

### `jest.config.js`
- Configures Jest for Lightning Web Components
- Sets up module name mapping for `c/` imports
- Configures coverage collection
- Uses jsdom environment for browser API simulation

### `babel.config.js`
- Configures Babel for ES6+ syntax transformation
- Targets current Node.js version

### `jest.setup.js`
- Global test setup
- Browser API mocks
- Console method mocking

## Writing New Tests

When adding new test files:

1. Place them in a `__tests__` folder within the component directory
2. Name them with `.test.js` suffix
3. Import the component using the `c/componentName` format
4. Mock external dependencies using `jest.mock()`
5. Follow the existing test structure and naming conventions

### Example Test Structure

```javascript
import ComponentName from '../componentName';

// Mock dependencies
jest.mock('c/dependency', () => ({
  method: jest.fn()
}));

describe('ComponentName', () => {
  let instance;

  beforeEach(() => {
    instance = new ComponentName();
    jest.clearAllMocks();
  });

  describe('methodName()', () => {
    test('should do something specific', () => {
      // Arrange
      const input = 'test';
      
      // Act
      const result = instance.methodName(input);
      
      // Assert
      expect(result).toBe(expected);
    });
  });
});
```

## Troubleshooting

### Common Issues

1. **Module not found errors**: Check that the module path mapping in `jest.config.js` is correct
2. **Browser API errors**: Ensure APIs are mocked in `jest.setup.js`
3. **Import/Export errors**: Verify Babel configuration in `babel.config.js`
4. **Decorator syntax errors**: The coverage report may show errors about decorators (`@api`, `@track`, `@wire`) in other Lightning Web Components. This is expected and doesn't affect the `tritonBuilder` and `tritonUtils` tests, which run successfully. To add decorator support for other components, install `@babel/plugin-proposal-decorators`

### Debug Mode

Run Jest in debug mode to troubleshoot test issues:

```bash
node --inspect-brk node_modules/.bin/jest --runInBand
```

Then open Chrome DevTools and navigate to `chrome://inspect`.

## Best Practices

1. **Test Behavior, Not Implementation**: Focus on what the code should do, not how it does it
2. **Use Descriptive Test Names**: Test names should clearly describe what is being tested
3. **Arrange-Act-Assert Pattern**: Structure tests with clear setup, execution, and verification phases
4. **Mock External Dependencies**: Isolate the unit under test by mocking its dependencies
5. **Test Edge Cases**: Include tests for null values, empty inputs, and boundary conditions
6. **Maintain High Coverage**: Aim for 90%+ code coverage while ensuring meaningful tests

