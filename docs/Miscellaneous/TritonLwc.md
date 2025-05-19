---
layout: default
---
# TritonLwc

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

Provides logging capabilities for Lightning Web Components (LWC).
This class exposes an AuraEnabled method that can be called from LWC to create log records
with customizable attributes like category, type, area, and level.

## Overview

The TritonLwc class serves as a bridge between client-side Lightning Web Components and
the server-side logging infrastructure. It handles:

- Log creation with automatic level defaulting
- Transaction management across component boundaries
- Component context capture and validation
- Error details extraction and formatting
- User and record ID validation
- Runtime environment information capture

## Methods

### `@AuraEnabled public static void saveComponentLogs(List<ComponentLog> componentLogs)`

Creates and persists log records from Lightning Web Components.

**Description**  
Primary entry point for LWC logging. Processes a batch of component logs,
validates their contents, and persists them to the database.

**Parameters**  
- `componentLogs` - `List<ComponentLog>` - Collection of component logs to process

**Throws**  
- `AuraHandledException` - If there's an error processing or saving the logs
- `System.LimitException` - If governor limits are exceeded

**Example**
```javascript
import saveComponentLogs from '@salesforce/apex/TritonLwc.saveComponentLogs';

const logs = [{
    category: 'LWC',
    type: 'Frontend',
    area: 'Accounts',
    summary: 'Record loaded',
    componentInfo: {
        name: 'accountDetail',
        function: 'handleLoad'
    }
}];

saveComponentLogs({ componentLogs: logs })
    .then(() => console.log('Logs saved'))
    .catch(error => console.error('Failed to save logs', error));
```

## Classes

### Component

Wrapper class for component context information.

#### Properties

##### `@AuraEnabled public String category`
The component's logging category. Defaults to 'LWC' if not specified.

##### `@AuraEnabled public String name`
The component's name (e.g., 'accountDetail', 'opportunityList').

##### `@AuraEnabled public String function`
The function or method where the log was created.

**Example**
```javascript
const componentInfo = {
    name: 'accountDetail',
    function: 'handleSave'
};
```

### ComponentLog

Wrapper class for log entry data from LWC.

#### Properties

##### `@AuraEnabled public String level`
Log level from TritonTypes.Level.

##### `@AuraEnabled public String category`
Log category from TritonTypes.Category.

##### `@AuraEnabled public String type`
Log type from TritonTypes.Type.

##### `@AuraEnabled public String area`
Functional area from TritonTypes.Area.

##### `@AuraEnabled public String summary`
Brief summary of the log entry.

##### `@AuraEnabled public String details`
Detailed log message.

##### `@AuraEnabled public String transactionId`
Transaction ID for grouping related logs.

##### `@AuraEnabled public Component componentInfo`
Component context information.

##### `@AuraEnabled public Decimal duration`
Operation duration in milliseconds.

##### `@AuraEnabled public Decimal createdTimestamp`
Log creation timestamp in milliseconds since epoch.

##### `@AuraEnabled public Error error`
Error details if logging an exception.

##### `@AuraEnabled public String stack`
Stack trace for error tracking.

##### `@AuraEnabled public String userId`
ID of the user associated with the log.

##### `@AuraEnabled public RuntimeInfo runtimeInfo`
Runtime environment information.

##### `@AuraEnabled public List<String> relatedObjectIds`
IDs of records related to this log entry.

**Example**
```javascript
const log = {
    category: 'LWC',
    type: 'Frontend',
    area: 'Accounts',
    summary: 'Failed to save record',
    details: 'Validation error on Name field',
    componentInfo: {
        name: 'accountDetail',
        function: 'handleSave'
    },
    level: 'ERROR',
    relatedObjectIds: ['001xx000003DGb2AAG']
};
```

### Error

Wrapper class for error information.

#### Properties

##### `@AuraEnabled public String message`
The error message.

##### `@AuraEnabled public String stack`
The error stack trace.

##### `@AuraEnabled public String type`
The error type or name.

**Example**
```javascript
const error = {
    message: 'Invalid field value',
    stack: 'Error: Invalid field value\n    at handleSave',
    type: 'ValidationError'
};
```

### RuntimeInfo

Wrapper class for runtime environment information.

#### Properties

##### Environment Information
- `@AuraEnabled public String userAgent` - Browser user agent string
- `@AuraEnabled public String platform` - Operating system platform
- `@AuraEnabled public String language` - Browser language
- `@AuraEnabled public Boolean mobile` - Whether device is mobile
- `@AuraEnabled public List<Object> brands` - Browser brand information

##### Viewport Information
- `@AuraEnabled public Integer viewportWidth` - Browser viewport width
- `@AuraEnabled public Integer viewportHeight` - Browser viewport height
- `@AuraEnabled public String theme` - UI theme setting

##### Performance Metrics
- `@AuraEnabled public Double pageLoadTime` - Total page load time
- `@AuraEnabled public Double domInteractive` - Time until DOM is interactive
- `@AuraEnabled public Double domContentLoaded` - DOM content loaded time
- `@AuraEnabled public Double firstByte` - Time to first byte
- `@AuraEnabled public Double serverTime` - Server response time
- `@AuraEnabled public Double firstPaint` - First paint timing
- `@AuraEnabled public Double firstContentfulPaint` - First contentful paint timing
- `@AuraEnabled public Double memoryUsage` - JS heap memory usage
- `@AuraEnabled public Double memoryLimit` - JS heap memory limit

##### Network Information
- `@AuraEnabled public String connectionType` - Network connection type
- `@AuraEnabled public Double connectionSpeed` - Network connection speed
- `@AuraEnabled public Double connectionRtt` - Network round trip time
- `@AuraEnabled public Boolean saveData` - Data saver mode enabled
- `@AuraEnabled public String pathname` - Current page path
- `@AuraEnabled public String hostname` - Current hostname
- `@AuraEnabled public Boolean isOnline` - Online status

##### Device Information
- `@AuraEnabled public String formFactor` - Device form factor
- `@AuraEnabled public Integer screenWidth` - Screen width
- `@AuraEnabled public Integer screenHeight` - Screen height
- `@AuraEnabled public String orientation` - Screen orientation

**Example**
```javascript
const runtime = {
    userAgent: navigator.userAgent,
    platform: 'Windows',
    viewportWidth: window.innerWidth,
    viewportHeight: window.innerHeight,
    connectionType: 'wifi',
    formFactor: 'LARGE'
};
```

---
