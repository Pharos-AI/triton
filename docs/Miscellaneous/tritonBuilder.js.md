---
layout: default
---
# tritonBuilder.js

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

JavaScript implementation of the TritonBuilder class for constructing log entries.
Provides a fluent interface for configuring log attributes and capturing runtime context.

## Methods

### Log Level and Classification

#### `level(level)`
Sets the log level.
Returns the builder instance for chaining.

#### `category(category)`
Sets the log category.
Returns the builder instance for chaining.

#### `type(type)`
Sets the log type.
Returns the builder instance for chaining.

#### `area(area)`
Sets the log area.
Returns the builder instance for chaining.

### Content

#### `summary(summary)`
Sets the summary text.
Returns the builder instance for chaining.

#### `details(details)`
Sets the log details.
Returns the builder instance for chaining.

### Context

#### `transactionId(transactionId)`
Sets the transaction ID.
Returns the builder instance for chaining.

#### `componentInfo(component)`
Sets the component information.
Component object should contain:
- name: Component name
- function: Function name
- action: Action name
Returns the builder instance for chaining.

#### `duration(duration)`
Sets the duration value in milliseconds.
Returns the builder instance for chaining.

#### `timestamp(timestamp)`
Sets the created timestamp.
If no timestamp provided, uses current time.
Returns the builder instance for chaining.

### Error Handling

#### `exception(error)`
Sets the error information from an Error object.
Automatically extracts:
- Error message
- Stack trace
- Error type
Also calls `componentDetails()` with the stack trace.
Returns the builder instance for chaining.

#### `componentDetails(stack)`
Extracts and sets component details from stack trace.
Filters out Triton-related entries.
Extracts component name and function name.
Returns the builder instance for chaining.

### Related Data

#### `userId(userId)`
Sets the user ID.
Returns the builder instance for chaining.

#### `relatedObjects(objectIds)`
Adds related object(s) to the log.
Accepts single ID or array of IDs.
Returns the builder instance for chaining.

### Builder Management

#### `clone()`
Creates a deep clone of the builder.
Copies all properties except functions.
Returns a new builder instance.

### Runtime Information

#### `runtimeInfo(info)`
Sets runtime information about the execution environment.
Info object can include:
- Environment details (userAgent, platform, language)
- Viewport dimensions
- Theme settings
- Performance metrics
- Memory usage
- Network information
- Device details
Returns the builder instance for chaining.

--- 