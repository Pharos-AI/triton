module.exports = {
  testEnvironment: 'jsdom',
  roots: ['<rootDir>/force-app/main/default/lwc'],
  moduleNameMapper: {
    '^c/(.*)$': '<rootDir>/force-app/main/default/lwc/$1/$1.js',
    '^@salesforce/apex/(.*)$': '<rootDir>/jest-mocks/@salesforce/apex/$1.js',
    '^@salesforce/user/(.*)$': '<rootDir>/jest-mocks/@salesforce/user/$1.js'
  },
  transform: {
    '^.+\\.js$': 'babel-jest'
  },
  collectCoverageFrom: [
    'force-app/main/default/lwc/**/*.js',
    '!force-app/main/default/lwc/**/*.test.js',
    '!force-app/main/default/lwc/**/jsconfig.json'
  ],
  coverageReporters: ['text', 'html', 'lcov'],
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  testMatch: [
    '**/lwc/**/__tests__/**/*.test.js',
    '**/lwc/**/*.test.js'
  ]
};
