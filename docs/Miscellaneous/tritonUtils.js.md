---
layout: default
---
# tritonUtils.js

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

Utility functions for the Triton logging framework's JavaScript implementation.
Provides helper functions for stack trace analysis, transaction ID generation,
and runtime information capture.

## Constants

### `TRITON_COMPONENTS`
Array of internal Triton component names used for stack trace filtering.
Values: `['triton', 'tritonBuilder', 'tritonHelper', 'tritonUtils']`

### `TRITON_METHOD_NAMES`
Array of internal Triton method names used for stack trace filtering.
Values: `['makeBuilder', 'refreshBuilder', 'debug', 'info', 'warning', 'error', 'exception', 'log', 'logNow']`

## Functions

### Stack Trace Analysis

#### `isNotTriton(stackTraceLine)`
Checks if a stack trace line is from internal Triton files.
Returns `true` if the line is NOT from internal Triton files.

Parameters:
- `stackTraceLine` (string) - Line from stack trace to check

#### `getFunctionName(stackTraceLine)`
Extracts the function name from a stack trace line.
Returns the function name as a string.

Parameters:
- `stackTraceLine` (string) - Line from stack trace to extract function name from

### Transaction Management

#### `generateTransactionId()`
Generates a UUID v4 (random UUID).
Returns the generated UUID in format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx

Example:
```javascript
const uuid = generateTransactionId(); // e.g. "550e8400-e29b-41d4-a716-446655440000"
```

### Runtime Information

#### `captureRuntimeInfo()`
Captures comprehensive runtime information about the current environment.
Returns an object containing:
- Environment info (userAgent, language, platform)
- Viewport dimensions
- Theme settings
- Performance metrics (page load, paint times, memory usage)
- Network info (connection type, speed)
- Device info (screen size, orientation)

Throws a warning to console if any info capture fails.

The returned object includes:

##### Environment Information
- `userAgent` - Browser user agent string
- `language` - Browser language
- `platform` - Operating system platform
- `mobile` - Whether device is mobile
- `brands` - Browser brand information

##### Viewport Information
- `viewportWidth` - Browser viewport width
- `viewportHeight` - Browser viewport height
- `theme` - UI theme setting

##### Performance Metrics
- `pageLoadTime` - Total page load time
- `domInteractive` - Time until DOM is interactive
- `domContentLoaded` - DOM content loaded time
- `firstByte` - Time to first byte
- `serverTime` - Server response time
- `firstPaint` - First paint timing
- `firstContentfulPaint` - First contentful paint timing
- `memoryUsage` - JS heap memory usage
- `memoryLimit` - JS heap memory limit

##### Network Information
- `connectionType` - Network connection type
- `connectionSpeed` - Network connection speed
- `connectionRtt` - Network round trip time
- `saveData` - Data saver mode enabled
- `pathname` - Current page path
- `hostname` - Current hostname
- `isOnline` - Online status

##### Device Information
- `formFactor` - Device form factor (SMALL/MEDIUM/LARGE)
- `screenWidth` - Screen width
- `screenHeight` - Screen height
- `orientation` - Screen orientation

--- 