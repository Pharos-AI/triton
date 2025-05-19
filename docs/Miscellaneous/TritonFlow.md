---
layout: default
---
# TritonFlow

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

Provides logging capabilities for Salesforce Flows and Process Builder.
This class exposes an invocable method that can be called directly from Flow Builder
to create log records with customizable attributes.

## Overview

The TritonFlow class serves as a bridge between declarative automation tools and the
Triton logging framework. It provides:

- Direct logging from Flow Builder and Process Builder
- Automatic transaction management
- Flow context capture (Interview GUID, Flow API Name)
- Custom field mapping through JSON
- Validation and fallback for enums
- Automatic INFO level defaulting

## Methods

### `@InvocableMethod public static List<FlowLogOutput> log(List<FlowLog> flowLogs)`

Creates log records from Flow Builder or Process Builder.

**Description**  
Primary entry point for Flow logging. Processes a batch of flow logs,
validates their contents, and persists them to the database.

**Category**: TritonLogging  
**Label**: Log  
**Description**: Creates a log for a flow or process builder

**Parameters**  
- `flowLogs` - `List<FlowLog>` - Collection of flow logs to process

**Returns**
- `List<FlowLogOutput>` - The list of FlowLogOutput instances after processing

**Example: Flow Builder Configuration**
```apex
FlowLog log = new FlowLog();
log.category = 'Flow';
log.type = 'Backend';
log.area = 'Accounts';
log.summary = 'Account processed';
log.interviewGUID = $Flow.InterviewGuid;
log.flowApiName = $Flow.Definition.Name;
```

**Example: Additional Fields JSON**
```json
{
    "pharos__Related_Id__c": "001xx000003DGb2AAG",
    "pharos__Duration__c": 150,
    "pharos__Custom_Field__c": "Custom Value"
}
```

## Classes

### FlowLog

Wrapper class for passing log data from Flow Builder.

#### Properties

##### `@InvocableVariable(Required=false Label='Category')`
##### `global String category`
Log category from TritonTypes.Category. Defaults to 'Flow' if not specified.

##### `@InvocableVariable(Required=false Label='Type')`
##### `global String type`
Log type from TritonTypes.Type.

##### `@InvocableVariable(Required=true Label='Area')`
##### `global String area`
Functional area from TritonTypes.Area.

##### `@InvocableVariable(Required=false Label='Operation')`
##### `global String operation`
Name of the operation being performed.

##### `@InvocableVariable(Required=true Label='Summary')`
##### `global String summary`
Brief summary of the log entry.

##### `@InvocableVariable(Required=false Label='Details')`
##### `global String details`
Detailed log message.

##### `@InvocableVariable(Required=true Label='Interview GUID')`
##### `global String interviewGUID`
Flow interview GUID for tracking flow execution.

##### `@InvocableVariable(Required=false Label='Flow API Name')`
##### `global String flowApiName`
API name of the flow being executed.

##### `@InvocableVariable(Required=false Label='Level')`
##### `global String level`
Log level from TritonTypes.Level. Defaults to 'INFO' if not specified.

##### `@InvocableVariable(Required=false Label='Transaction ID')`
##### `global String transactionId`
Transaction ID for grouping related logs.

##### `@InvocableVariable(Required=false Label='Additional Fields')`
##### `global String additionalFields`
JSON string mapping field API names to values for custom fields.

##### `@InvocableVariable(Required=false Label='Stacktrace')`
##### `global String stacktrace`
Stack trace for error tracking.

##### `@InvocableVariable(Required=false Label='Full Stacktrace')`
##### `global String fullStacktrace`
Complete stack trace for error tracking.

### FlowLogOutput

Wrapper class for returning log data from flow.

#### Properties

##### `@InvocableVariable(Required=false Label='Stacktrace')`
##### `global String stacktrace`
Stack trace returned after processing.

##### `@InvocableVariable(Required=false Label='Full Stacktrace')`
##### `global String fullStacktrace`
Complete stack trace returned after processing.

## Usage Notes

1. **Transaction Management**
   - Automatically starts a transaction if none exists
   - Uses existing transaction if one is in progress
   - Resumes a transaction if transactionId is provided
   - Flushes logs after processing

2. **Field Validation**
   - Validates category against TritonTypes.Category
   - Validates level against TritonTypes.Level
   - Uses defaults for invalid values

3. **Additional Fields**
   - Must be valid JSON string
   - Field API names must include namespace prefix
   - Values must match field types

4. **Best Practices**
   - Always provide Interview GUID for tracking
   - Use Flow API Name for context
   - Group related operations in same transaction
   - Use appropriate log levels

---

---
