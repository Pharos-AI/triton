---
layout: default
---
# TritonTypes

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

The TritonTypes class provides enums and constants for the Triton logging framework.
It defines the classification system used to categorize and filter log entries.

## Overview

The TritonTypes class serves as a central hub for all enumerated values used throughout
the Triton logging framework. These enums enable consistent categorization and filtering
of log entries across different contexts.

## Enums

### `public enum Area`

Represents the functional area from a business perspective. This value is written to
the Functional Area field on log records.

**Values**
- `OpportunityManagement` - Opportunity-related operations and workflows
- `LeadConversion` - Lead conversion processes and triggers
- `Community` - Community/portal user interactions and operations
- `RestAPI` - REST API endpoints and integrations
- `Accounts` - Account-related operations and triggers
- `LWC` - Lightning Web Component operations
- `Flow` - Flow and Process Builder operations

**Example**
```apex
TritonBuilder builder = new TritonBuilder()
    .area(TritonTypes.Area.Accounts)
    .summary('Account updated');
```

### `public enum Category`

Provides high-level classification of log entries. This value is written to
the Category field on log records.

**Values**
- `Apex` - Server-side Apex code execution
- `Flow` - Flow and Process Builder execution
- `LWC` - Lightning Web Component lifecycle
- `Aura` - Aura Component lifecycle
- `Warning` - Warning messages across contexts
- `Event` - Platform event operations
- `Debug` - Debug information
- `Integration` - External system integrations

**Example**
```apex
TritonBuilder builder = new TritonBuilder()
    .category(TritonTypes.Category.Apex)
    .type(TritonTypes.Type.Backend);
```

### `public enum Level`

Defines log severity levels from least to most verbose. Used to control
logging granularity and filtering.

**Values**
- `ERROR` - Error conditions that need immediate attention
- `WARNING` - Warning conditions that might need attention
- `INFO` - Informational messages about normal operation
- `DEBUG` - Debug-level messages for troubleshooting
- `FINE` - Detailed tracing information
- `FINER` - More detailed tracing information
- `FINEST` - Most detailed tracing information

**Example**
```apex
TritonBuilder builder = new TritonBuilder()
    .level(TritonTypes.Level.ERROR)
    .summary('Failed to process record');
```

**Usage Notes**
- Log levels are ordered from least verbose (ERROR) to most verbose (FINEST)
- Each level includes all levels above it in the hierarchy
- Use `TritonHelper.compareLevel()` to compare log levels

### `public enum Type`

Provides technical classification of log entries. This value is written to
the Type field on log records.

**Values**
- `Backend` - Server-side operations in Apex
- `Frontend` - Client-side operations in LWC/Aura
- `DMLResult` - Database operation results
- `LongRunningRequest` - Performance monitoring for long operations
- `ConcurrentRequestsLimit` - Concurrency limit violations
- `AccountTrigger` - Account-specific trigger operations

**Example**
```apex
TritonBuilder builder = new TritonBuilder()
    .type(TritonTypes.Type.Backend)
    .area(TritonTypes.Area.Accounts);
```

## Usage

These enums are used throughout the Triton framework to provide consistent
categorization and filtering capabilities. They enable:

1. **Structured Logging**
   - Consistent categorization across different contexts
   - Clear hierarchy of log levels
   - Business-focused area classification

2. **Filtering and Analysis**
   - Filter logs by category, type, area, or level
   - Group related operations by area
   - Identify patterns in specific operation types

3. **Runtime Control**
   - Control log verbosity through levels
   - Enable/disable logging for specific areas
   - Monitor specific operation types

**Example: Complete Log Entry**
```apex
Triton.instance
    .error(TritonTypes.Type.Backend, TritonTypes.Area.Accounts)
    .category(TritonTypes.Category.Apex)
    .summary('Failed to update account')
    .build();
```

---
