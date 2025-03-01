---
layout: default
---
# TritonHelper

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

Utility methods and builder classes for the Triton logging framework.
This class provides core functionality for:
- Log level management and comparison
- UUID generation for transaction tracking
- HTTP request/response JSON serialization
- Pre and post-processing controls
- Message formatting and stack trace management
- Runtime information formatting

## Overview

The TritonHelper class serves as a central utility hub for the Triton logging system,
providing essential helper methods and builder patterns to enhance logging capabilities.

## Constants

### Transaction Cache
```apex
private static final String TRANSACTION_CACHE_KEY = 'tritonTransactionId';
private static final Integer DEFAULT_TRANSACTION_CACHE_DURATION = 300;
```

## Methods

### Transaction Management

#### `public static void cacheTransactionId(String transactionId)`
Saves transaction ID to platform cache with user-specific key.

**Parameters**  
- `transactionId` - `String` - The transaction ID to cache

**Example**
```apex
String transactionId = TritonHelper.generateUUID4();
TritonHelper.cacheTransactionId(transactionId);
```

#### `public static String getCachedTransactionId()`
Retrieves transaction ID from platform cache using user-specific key.

**Returns**  
- `String` - The cached transaction ID or null if not found

#### `public static void clearCachedTransactionId()`
Clears transaction ID from platform cache.

### Log Level Management

#### `public static String buildLogLevelKey(String category, String type, String area)`
Creates a composite key for log level lookup.

**Parameters**  
- `category` - `String` - Log category
- `type` - `String` - Log type
- `area` - `String` - Functional area

**Returns**  
- `String` - Key in format: "Category:{0};Type:{1};Area:{2}"

**Example**
```apex
String key = TritonHelper.buildLogLevelKey(
    TritonTypes.Category.APEX.name(),
    TritonTypes.Type.BACKEND.name(),
    TritonTypes.Area.ACCOUNTS.name()
);
```

#### `public static Boolean compareLevel(TritonTypes.Level value, TritonTypes.Level toCompare)`
Compares two log levels to determine if logging should occur.

**Parameters**  
- `value` - `TritonTypes.Level` - The level being checked
- `toCompare` - `TritonTypes.Level` - The level to compare against

**Returns**  
- `Boolean` - True if value is higher or equal to toCompare

**Example**
```apex
if (TritonHelper.compareLevel(TritonTypes.Level.DEBUG, TritonTypes.Level.INFO)) {
    // Log debug message
}
```

### Stack Trace Management

#### `public static String getCurrentStackTrace()`
Returns the current stack trace, excluding Triton-related entries.

**Returns**  
- `String` - Filtered stack trace with Triton entries removed

**Example**
```apex
String stackTrace = TritonHelper.getCurrentStackTrace();
builder.stackTrace(stackTrace);
```

#### `public static String getOperation(String stackTrace)`
Extracts the operation (Class.Method) from a stack trace.

**Parameters**  
- `stackTrace` - `String` - The stack trace to parse

**Returns**  
- `String` - Operation in format "ClassName.MethodName"

### Message Formatting

#### `public static String formatMessage(String template, String param)`
Formats a message by replacing {0} placeholder.

**Parameters**  
- `template` - `String` - Message template with {0} placeholder
- `param` - `String` - Value to replace placeholder

**Returns**  
- `String` - Formatted message

**Example**
```apex
String msg = TritonHelper.formatMessage('Processing account: {0}', account.Name);
```

#### `public static String formatMessage(String template, List<String> params)`
Formats a message by replacing multiple placeholders.

**Parameters**  
- `template` - `String` - Message template with {0}, {1}, etc.
- `params` - `List<String>` - Values to replace placeholders

**Returns**  
- `String` - Formatted message

### Integration Payload

#### `public static String toJson(RestRequest request, RestResponse response)`
JSON serialization for REST request/response.

**Parameters**  
- `request` - `RestRequest` - The REST request
- `response` - `RestResponse` - The REST response

**Returns**  
- `String` - JSON string containing request and response details

#### `public static String toJson(HttpRequest request, HttpResponse response)`
JSON serialization for HTTP request/response.

**Parameters**  
- `request` - `HttpRequest` - The HTTP request
- `response` - `HttpResponse` - The HTTP response

**Returns**  
- `String` - JSON string containing request and response details

### Runtime Information

#### `public static String formatLwcRuntimeInfo(TritonLwc.RuntimeInfo runtime)`
Formats runtime information into a readable string.

**Parameters**  
- `runtime` - `TritonLwc.RuntimeInfo` - Runtime information object

**Returns**  
- `String` - Formatted string with runtime details

## Classes

### IntegrationWrapper

Wrapper class for integration logs.

#### Properties
- `public Map<String,Object> request` - Request details
- `public Map<String,Object> response` - Response details

### PostProcessingControlsBuilder

Builder class for Pharos post-processing settings.

#### Methods

##### `public PostProcessingControlsBuilder auditTrail(Boolean value)`
Controls audit trail fetching.

##### `public PostProcessingControlsBuilder deployResult(Boolean value)`
Controls recent deployments fetching.

##### `public PostProcessingControlsBuilder installedPackages(Boolean value)`
Controls installed packages count fetching.

##### `public PostProcessingControlsBuilder area(Boolean value)`
Controls automatic area setting.

##### `public PostProcessingControlsBuilder pendingJobs(Boolean value)`
Controls pending jobs fetching.

##### `public PostProcessingControlsBuilder relatedObjects(Boolean value)`
Controls related objects name fetching.

##### `public PostProcessingControlsBuilder setAll(Boolean value)`
Sets all flags to the provided value.

##### `public PostProcessingControlsBuilder stackTrace(Boolean value)`
Controls stack trace enhancement.

##### `public PostProcessingControlsBuilder userInfo(Boolean value)`
Controls user name fetching.

##### `public PostProcessingControlsBuilder totalActiveSession(Boolean value)`
Controls active session count fetching.

##### `public String build()`
Returns JSON settings string.

**Example**
```apex
String settings = new TritonHelper.PostProcessingControlsBuilder()
    .auditTrail(true)
    .stackTrace(true)
    .userInfo(true)
    .build();
```

---
