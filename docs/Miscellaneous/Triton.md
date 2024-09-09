---
layout: default
---
# Triton

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

## Constructors
### `private Triton(pharos.Logger logger)`
---
## Fields

### `public APEX_NAME` → `String`


key field names for setting attributes on log records

### `public CREATED_TIMESTAMP` → `String`


### `public DURATION` → `String`


### `public INTERVIEW_GUID` → `String`


### `public LOG_LEVEL` → `String`


### `public RELATED_ID` → `String`


### `public RELATED_OBJECTS` → `String`


### `public STACKTRACE_PARSE_RESULT` → `String`


### `public USER_ID` → `String`


### `public FLOW_API_NAME` → `String`


### `public SPACE_SEP` → `String`


### `private logger` → `pharos.Logger`


### `private LOG_LEVELS_MDT` → `Log_Level__mdt`

`TESTVISIBLE` 

### `private stackOffset` → `Integer`


Stack trace offset.
In case no stack is provided, it will be obtained automatically for error and debug logs.
Use the offset to remove unwanted lines from top of the stack trace
such as util method invocations.

### `public TRANSACTION_ID` → `String`


This value can be passed around to trace a complex process spanning multiple Salesforce transactions
Can be used between LWC/Apex/Flow transitions when complex tracing is required.

---
## Properties

### `public instance` → `Triton`


### `private LOG_LEVELS` → `Map<String,TritonTypes.Level>`

`TESTVISIBLE` 

Helper map for storing current log levels

---
## Methods
### `public void add(pharos__Log__c log)`

Adds a log to the buffer.
Performs a check on current log level prior

#### Parameters

|Param|Description|
|---|---|
|`log`|-- Pharos log record|

### `public void flush()`

Persist Log records immediately.
Use this method to persist logs to the database right away.

### `private void incStackOffset()`
### `private void resetStackOffset()`
### `public static pharos.LogBuilder makeBuilder()`

Shorthand method for creating a new builder

### `public String startTransaction()`

Start new transaction
Autogenrated Transaction UUID
This method will obtain a new autogenrated transaction id or use the current one

### `public void resumeTransaction(String transactionId)`

Resumes a transaction
Assumes an existing transaction id
Use this method to tie together different Salesforce transactions.

### `public void stopTransaction()`

Stops a transaction
Resets the current transaction Id
Use this method to marking tracking logs with the current transaction Id

### `public void addError(TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

---------------------------
Log methods.
---------------------------

There are 2 types of log methods per each category: buffered and immediate
Buffered methods will add to the log collection without flush()'ing
Immediate methods will add to the log collection and call flush()

### `public void error(TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Immediate

### `public void addError(TritonTypes.Area area, Exception e, Set<String> relatedObjectIds)`

Add Log with Error Category and related records.
This method will automatically get the stacktrace from Exception.
Type will be obtained from Exception. If blank, a default Backend Type will be saved
Summary is the Exception message.
Details will be a combination of Exception String and stacktrace

#### Parameters

|Param|Description|
|---|---|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`e`|-- instance of an Exception|
|`relatedObjectIds`|-- a set of related records to associate with this log|

### `public void addError(TritonTypes.Area area, Exception e)`

Add Log with Error Category.
This method will automatically get the stacktrace from Exception.
Type will be obtained from Exception. If blank, a default Backend Type will be saved
Summary is the Exception message.
Details will be a combination of Exception String and stacktrace

#### Parameters

|Param|Description|
|---|---|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`e`|-- instance of an Exception|

### `public void error(TritonTypes.Area area, Exception e, Set<String> relatedObjectIds)`

Immediate

### `public void error(TritonTypes.Area area, Exception e)`
### `public void addWarning(TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Add Log with Warning Category.
This method will not save a stacktrace.

#### Parameters

|Param|Description|
|---|---|
|`type`|-- log record TritonTypes.Type (see Type enum)|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`summary`|-- summary of the issue. Saves to log record Summary field|
|`details`|-- details of the issue. Saves to log record Details field|

### `public void warning(TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Immediate

### `public void addDebug(TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Add Log with Debug Category.
This method will automatically get the stacktrace.

#### Parameters

|Param|Description|
|---|---|
|`type`|-- log record TritonTypes.Type (see Type enum)|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`summary`|-- summary of the issue. Saves to log record Summary field|
|`details`|-- details of the issue. Saves to log record Details field|

### `public void debug(TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Immediate

### `public void addDebug(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, Decimal duration)`

Add Log with Debug Category.
This method will automatically get the stacktrace.

#### Parameters

|Param|Description|
|---|---|
|`type`|-- log record TritonTypes.Type (see Type enum)|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`summary`|-- summary of the issue. Saves to log record Summary field|
|`details`|-- details of the issue. Saves to log record Details field|

### `public void debug(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, Decimal duration)`

Immediate

### `public void addEvent(TritonTypes.Level level, TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Add Log with Event Category.
Default INFO log level

#### Parameters

|Param|Description|
|---|---|
|`level`|-- log TritonTypes.Level (see Level enum)|
|`type`|-- log record TritonTypes.Type (see Type enum)|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`summary`|-- summary of the issue. Saves to log record Summary field|
|`details`|-- details of the issue. Saves to log record Details field|

### `public void event(TritonTypes.Level level, TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Immediate

### `public void addEvent(TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Add Log with Event Category.
Default INFO log level

#### Parameters

|Param|Description|
|---|---|
|`type`|-- log record TritonTypes.Type (see Type enum)|
|`area`|-- log record Functional Area (see Area enum)|
|`summary`|-- summary of the issue. Saves to log record Summary field|
|`details`|-- details of the issue. Saves to log record Details field|

### `public void event(TritonTypes.Type type, TritonTypes.Area area, String summary, String details)`

Immediate

### `public void addIntegrationError(TritonTypes.Area area, Exception e, HttpRequest request, HttpResponse response)`

Add Log with Integration Category.
This method will automatically get the stacktrace from Exception.

#### Parameters

|Param|Description|
|---|---|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`e`|-- instance of an Exception|
|`request`|-- HttpRequest of the issue. Saves to log record Details field|
|`response`|-- HttpResponse of the issue. Saves to log record Details field|

### `public void integrationError(TritonTypes.Area area, Exception e, HttpRequest request, HttpResponse response)`

Immediate

### `public void addIntegrationError(TritonTypes.Area area, Exception e, RestRequest request, RestResponse response)`

Add Log with Integration Category.
This method will automatically get the stacktrace from Exception.

#### Parameters

|Param|Description|
|---|---|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`e`|-- instance of an Exception|
|`request`|-- RestRequest of the issue. Saves to log record Details field|
|`response`|-- RestResponse of the issue. Saves to log record Details field|

### `public void integrationError(TritonTypes.Area area, Exception e, RestRequest request, RestResponse response)`

Immediate

### `public void addIntegrationError(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, HttpRequest request, HttpResponse response)`

Add Log with Integration Category.
This method will automatically get the stacktrace.

#### Parameters

|Param|Description|
|---|---|
|`type`|-- log record TritonTypes.Type (see Type enum)|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`summary`|-- summary of the issue. Saves to log record Summary field|
|`details`|-- details of the issue. Saves to log record Details field|
|`request`|-- HttpRequest of the issue. Saves to log record Details field|
|`response`|-- HttpResponse of the issue. Saves to log record Details field|

### `public void integrationError(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, HttpRequest request, HttpResponse response)`

Immediate

### `public void addIntegrationError(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, RestRequest request, RestResponse response)`

Add Log with Integration Category.
This method will automatically get the stacktrace.

#### Parameters

|Param|Description|
|---|---|
|`type`|-- log record TritonTypes.Type (see Type enum)|
|`area`|-- log record Functional TritonTypes.Area (see Area enum)|
|`summary`|-- summary of the issue. Saves to log record Summary field|
|`details`|-- details of the issue. Saves to log record Details field|
|`request`|-- RestRequest of the issue. Saves to log record Details field|
|`response`|-- RestResponse of the issue. Saves to log record Details field|

### `public void integrationError(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, RestRequest request, RestResponse response)`

Immediate

### `public static Boolean isLogAllowedForLogLevel(pharos__Log__c log)`

Checks if a log should be persisted based on the current log level

#### Parameters

|Param|Description|
|---|---|
|`log`|-- Pharos log record to be saved|

#### Returns

|Type|Description|
|---|---|
|`Boolean`|-- true if current log's level is below the level set in the settings, false otherwise|

---
