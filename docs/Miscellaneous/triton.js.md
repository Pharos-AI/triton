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

### `instance` → `Triton`
Singleton instance of the Triton logger.

### `logs` → `Array`
Buffer to store logs before sending to server.

### `templates` → `Map`
Map to store component-specific templates.

### `category` → `String`
Current component category.

### `transactionId` → `String`
Current transaction ID.

## Methods

### Component Binding

#### `bindToComponent(componentId)`
Binds logger methods to a specific component context.
Returns a Proxy that scopes logger methods to the specified component.

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
Sends all buffered logs to the server and clears the buffer.
Returns a Promise that resolves when logs are flushed.

#### `log(builder)`
Adds a log builder to the buffer.
Returns the builder instance for chaining.

#### `async logNow(builder)`
Immediately flushes a single log builder.
Returns a Promise that resolves when the log is flushed.

### Builder Management

#### `makeBuilder()`
Creates a new builder with default settings.
Returns a new builder instance.

#### `refreshBuilder(builder)`
Updates a builder with the current context information.
Returns the updated builder instance.

## Internal Classes

### TransactionManager
Manages transaction lifecycle and storage.

#### Properties
- `STORAGE_KEY` → `String` - Key for storing transaction ID in session storage
- `AUTO_FLUSH_CHECK_INTERVAL` → `Number` - Interval for checking auto-flush (5 seconds)
- `AUTO_FLUSH_DELAY` → `Number` - Delay before auto-flushing (10 seconds)

#### Methods
- `initialize()` - Initializes transaction management
- `start()` - Starts a new transaction
- `resume(transactionId)` - Resumes an existing transaction
- `stop()` - Stops current transaction and monitoring
- `startAutoFlushMonitor()` - Starts monitoring the logs array for auto-flushing
- `stopAutoFlushMonitor()` - Stops the auto-flush monitor

--- 