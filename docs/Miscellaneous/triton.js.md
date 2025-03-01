---
layout: default
---
# triton.js

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

JavaScript implementation of the Triton logging framework for Lightning Web Components.
Provides a robust client-side logging system with transaction tracking, buffered logging,
and automatic runtime information capture.

## Properties

### `static instance` → `Triton`
Singleton instance of the Triton logger.

### `logs` → `Array`
Buffer to store logs before sending to server.

### `template` → `TritonBuilder`
Template builder for reuse.

### `category` → `String`
Current component category (LWC or AURA).

### `transactionId` → `String`
Current transaction ID.

## Methods

### Transaction Management

#### `startTransaction()`
Generates and stores a new transaction ID (UUID v4).
Also starts the auto-flush monitor.
Returns the generated transaction ID.

#### `resumeTransaction(transactionId)`
Resumes a transaction using an existing transaction ID.
Also starts the auto-flush monitor.

#### `stopTransaction()`
Stops the current transaction and auto-flush monitor.
Flushes any remaining logs.

### Log Creation

#### `exception(error)`
Creates an error log from an Exception.
Returns a new builder instance configured for the error.

#### `error(type, area)`
Creates an error level log.
Returns a new builder instance with ERROR level.

#### `warning(type, area)`
Creates a warning level log.
Returns a new builder instance with WARNING level.

#### `debug(type, area)`
Creates a debug level log.
Returns a new builder instance with DEBUG level.

#### `info(type, area)`
Creates an info level log.
Returns a new builder instance with INFO level.

### Log Management

#### `async flush()`
Flushes all logs in the buffer to the server.
Returns a Promise that resolves when logs are successfully saved.
Throws an Error if there's an error saving the logs.

#### `setTemplate(builder)`
Sets a builder template that can be re-used.

#### `fromTemplate()`
Creates a new builder from the saved template.
If no template exists, creates a new builder with default settings.
Returns a new builder instance.

#### `log(builder)`
Adds a log to the buffer.
Returns the builder instance for chaining.

#### `async logNow(builder)`
Immediately flushes a single log builder.
Returns a Promise that resolves when the log is flushed.

### Internal Methods

#### `makeBuilder()`
Creates a new builder with default settings and current context.
Automatically captures:
- User ID
- Transaction ID
- Component stack trace
- Runtime information
Returns a new builder instance.

## Constants

### AREA
Available log areas:
- `ACCOUNTS`
- `COMMUNITY`
- `LEAD_CONVERSION`
- `OPPORTUNITY_MANAGEMENT`
- `REST_API`

### CATEGORY
Available log categories:
- `LWC`
- `AURA`
- `WARNING`
- `DEBUG`
- `EVENT`

### LEVEL
Available log levels:
- `ERROR`
- `WARNING`
- `INFO`
- `DEBUG`
- `FINE`
- `FINER`
- `FINEST`

### TYPE
Available log types:
- `BACKEND`
- `FRONTEND`

## Internal Classes

### TransactionManager
Manages transaction lifecycle and storage.

#### Properties
- `STORAGE_KEY` → `String` - Key for storing transaction ID in session storage
- `AUTO_FLUSH_CHECK_INTERVAL` → `Number` - Interval for checking auto-flush (10 seconds)
- `AUTO_FLUSH_DELAY` → `Number` - Delay before auto-flushing (1 minute)

#### Methods
- `initialize()` - Initializes transaction management
- `start()` - Starts a new transaction
- `resume(transactionId)` - Resumes an existing transaction
- `stop()` - Stops current transaction and monitoring
- `startAutoFlushMonitor()` - Starts monitoring the logs array for auto-flushing
- `stopAutoFlushMonitor()` - Stops the auto-flush monitor

--- 