---
layout: default
---
# Triton

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

The Triton class provides a robust logging framework for Salesforce applications.
It enables structured logging with different severity levels (ERROR, WARNING, DEBUG, INFO),
categories (Apex, Integration, Event, Debug), and functional areas.

Key features:
- Buffered and immediate logging options
- Automatic stack trace capture
- Transaction tracking across multiple Salesforce contexts
- Integration error logging with HTTP request/response details
- Configurable log levels via Custom Metadata
- Builder pattern for constructing log entries
- Runtime environment information capture
- Transaction caching for cross-component tracking

## Properties

### `public static Triton instance { get; private set; }`
Singleton instance of the Triton logger. Access this through `Triton.instance`.

### `public TritonBuilder template { get; private set; }`
Template builder for reuse. Used to create new log entries with predefined settings.

## Methods

### Transaction Management

#### `public String startTransaction()`
Generates and stores a new transaction ID for tracking related log entries.

**Description**  
Initializes a new logging transaction and starts monitoring. Use this when beginning a new
logical operation that may span multiple components or contexts.

**Returns**  
- `String` - The newly generated transaction ID

**Example**
```apex
String transactionId = Triton.instance.startTransaction();
```

#### `public void resumeTransaction(String transactionId)`
Resumes an existing transaction using a previously generated ID.

**Parameters**  
- `transactionId` - `String` - The transaction ID to resume

**Throws**  
- `IllegalArgumentException` - If the transaction ID is null or empty

**Example**
```apex
Triton.instance.resumeTransaction('550e8400-e29b-41d4-a716-446655440000');
```

#### `public void stopTransaction()`
Stops the current transaction, flushes remaining logs, and cleans up resources.

**Description**  
Should be called when the logical operation is complete. Will automatically flush
any buffered logs before stopping the transaction.

### Log Creation

#### `public TritonBuilder exception(Exception error)`
Creates an error log entry from a Salesforce Exception.

**Parameters**  
- `error` - `Exception` - The exception to log

**Returns**  
- `TritonBuilder` - A builder instance configured with the exception details

**Example**
```apex
try {
    // Some operation
} catch (Exception e) {
    Triton.instance.exception(e)
        .summary('Failed to process record')
        .build();
}
```

#### `public TritonBuilder error(TritonTypes.Type type, TritonTypes.Area area)`
Creates an error level log entry.

**Parameters**  
- `type` - `TritonTypes.Type` - The type of error (e.g., Backend, Frontend)
- `area` - `TritonTypes.Area` - The functional area where the error occurred

**Returns**  
- `TritonBuilder` - A builder instance configured with ERROR level

#### `public TritonBuilder warning(TritonTypes.Type type, TritonTypes.Area area)`
Creates a warning level log entry.

**Parameters**  
- `type` - `TritonTypes.Type` - The type of warning
- `area` - `TritonTypes.Area` - The functional area

**Returns**  
- `TritonBuilder` - A builder instance configured with WARNING level

#### `public TritonBuilder debug(TritonTypes.Type type, TritonTypes.Area area)`
Creates a debug level log entry.

**Parameters**  
- `type` - `TritonTypes.Type` - The type of debug entry
- `area` - `TritonTypes.Area` - The functional area

**Returns**  
- `TritonBuilder` - A builder instance configured with DEBUG level

#### `public TritonBuilder info(TritonTypes.Type type, TritonTypes.Area area)`
Creates an info level log entry.

**Parameters**  
- `type` - `TritonTypes.Type` - The type of info entry
- `area` - `TritonTypes.Area` - The functional area

**Returns**  
- `TritonBuilder` - A builder instance configured with INFO level

### Log Management

#### `public void flush()`
Flushes all buffered logs to the database.

**Description**  
Commits all pending log entries to the database. Should be called explicitly if
immediate persistence is required.

**Throws**  
- `DmlException` - If there's an error saving the logs
- `System.LimitException` - If governor limits are exceeded

#### `public void setTemplate(TritonBuilder builder)`
Sets a builder template for creating logs with common attributes.

**Parameters**  
- `builder` - `TritonBuilder` - The template builder to use

**Example**
```apex
TritonBuilder template = new TritonBuilder()
    .category(TritonTypes.Category.Apex)
    .area(TritonTypes.Area.Accounts);
Triton.instance.setTemplate(template);
```

#### `public TritonBuilder fromTemplate()`
Creates a new builder instance from the saved template.

**Returns**  
- `TritonBuilder` - A new builder instance with template settings

**Description**  
If no template exists, creates a new builder with default settings.

#### `public void log(TritonBuilder builder)`
Adds a log entry to the buffer for later flushing.

**Parameters**  
- `builder` - `TritonBuilder` - The configured builder instance

#### `public void logNow(TritonBuilder builder)`
Immediately persists a single log entry.

**Parameters**  
- `builder` - `TritonBuilder` - The configured builder instance

**Throws**  
- `DmlException` - If there's an error saving the log

## Enums

### `TritonTypes.Area`
Available log areas:
- `ACCOUNTS` - Account-related operations
- `COMMUNITY` - Community/portal operations
- `LEAD_CONVERSION` - Lead conversion processes
- `OPPORTUNITY_MANAGEMENT` - Opportunity-related operations
- `REST_API` - REST API interactions

### `TritonTypes.Category`
Available log categories:
- `APEX` - Server-side Apex code
- `LWC` - Lightning Web Components
- `AURA` - Aura Components
- `WARNING` - Warning messages
- `DEBUG` - Debug information
- `EVENT` - Platform events
- `INTEGRATION` - External integrations

### `TritonTypes.Level`
Available log levels (ordered from least to most verbose):
- `ERROR` - Error conditions
- `WARNING` - Warning conditions
- `INFO` - Informational messages
- `DEBUG` - Debug-level messages
- `FINE` - Detailed tracing
- `FINER` - More detailed tracing
- `FINEST` - Most detailed tracing

### `TritonTypes.Type`
Available log types:
- `BACKEND` - Server-side operations
- `FRONTEND` - Client-side operations
- `DML_RESULT` - Database operations
- `LONG_RUNNING_REQUEST` - Performance issues
- `CONCURRENT_REQUESTS_LIMIT` - Concurrency issues
- `ACCOUNT_TRIGGER` - Account trigger operations

---
