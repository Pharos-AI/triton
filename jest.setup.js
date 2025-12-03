// Global test setup
global.console = {
  ...console,
  warn: jest.fn(),
  error: jest.fn(),
  log: jest.fn()
};

// Mock DOM APIs that might not be available in test environment
Object.defineProperty(window, 'performance', {
  writable: true,
  value: {
    getEntriesByType: jest.fn(() => []),
    memory: {
      usedJSHeapSize: 1000000,
      jsHeapSizeLimit: 10000000
    }
  }
});

Object.defineProperty(window, 'navigator', {
  writable: true,
  value: {
    userAgent: 'test-agent',
    language: 'en-US',
    platform: 'test-platform',
    onLine: true,
    connection: {
      effectiveType: '4g',
      downlink: 10,
      rtt: 50,
      saveData: false
    }
  }
});

Object.defineProperty(window, 'screen', {
  writable: true,
  value: {
    width: 1920,
    height: 1080,
    orientation: {
      type: 'landscape-primary'
    }
  }
});

Object.defineProperty(window, 'location', {
  writable: true,
  value: {
    pathname: '/test',
    hostname: 'test.com'
  }
});

Object.defineProperty(document, 'documentElement', {
  writable: true,
  value: {
    getAttribute: jest.fn(() => 'light')
  }
});
