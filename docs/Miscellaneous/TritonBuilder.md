---
layout: default
---
# TritonBuilder

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

Builder class for creating and configuring Pharos log records.
Provides a fluent interface to set various attributes like category, type, area,
related objects, and other metadata for logging purposes.

## Constants

### Field Names
Constants used for setting attributes on log records:

```apex
public static final String APEX_NAME = 'pharos__Apex_Name__c';
public static final String CREATED_TIMESTAMP = 'pharos__Created_Timestamp__c';
public static final String DURATION = 'pharos__Duration__c';
public static final String INTERVIEW_GUID = 'pharos__Interview_GUID_External__c';
public static final String LOG_LEVEL = 'Log_Level__c';
public static final String RELATED_ID = 'pharos__Related_Id__c';
public static final String RELATED_OBJECTS = 'pharos__Related_Objects__c';
public static final String STACKTRACE_PARSE_RESULT = 'pharos__Stacktrace_Parse_Result__c';
public static final String USER_ID = 'pharos__User_Id__c';
public static final String FLOW_API_NAME = 'pharos__Flow_API_Name__c';
public static final String DO_NOT_CREATE_ISSUE = 'pharos__Do_Not_Create_Issue__c';
public static final String REQUEST_ID = 'pharos__Request_Id_External__c';
```

## Methods

### Core Builder Methods

#### `public TritonBuilder cloneBuilder()`
Creates a deep clone of the builder instance.

**Returns**  
- `TritonBuilder` - A new builder instance with copied settings

**Example**
```apex
TritonBuilder original = new TritonBuilder()
    .category(TritonTypes.Category.Apex);
TritonBuilder clone = original.cloneBuilder();
```

### Classification Methods

#### `public TritonBuilder category(TritonTypes.Category c)`
Sets the log category from Category enum.

**Parameters**  
- `c` - `TritonTypes.Category` - The category to set

**Returns**  
- `TritonBuilder` - The builder instance for chaining

**Example**
```apex
builder.category(TritonTypes.Category.Apex);
```

#### `public TritonBuilder type(TritonTypes.Type t)`
Sets the log type from Type enum.

**Parameters**  
- `t` - `TritonTypes.Type` - The type to set

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder area(TritonTypes.Area a)`
Sets the log functional area from Area enum.

**Parameters**  
- `a` - `TritonTypes.Area` - The functional area to set

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder level(TritonTypes.Level l)`
Sets the log level from Level enum.

**Parameters**  
- `l` - `TritonTypes.Level` - The log level to set

**Returns**  
- `TritonBuilder` - The builder instance for chaining

### Content Methods

#### `public TritonBuilder operation(String operation)`
Sets the operation name (typically Class.Method).

**Parameters**  
- `operation` - `String` - The operation name to set

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder summary(String value)`
Sets the log summary message.

**Parameters**  
- `value` - `String` - The summary message

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder details(String value)`
Sets the detailed log message.

**Parameters**  
- `value` - `String` - The detailed message

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder stackTrace(String stack)`
Sets the stack trace for error tracking.

**Parameters**  
- `stack` - `String` - The stack trace string

**Returns**  
- `TritonBuilder` - The builder instance for chaining

### Processing Control Methods

#### `public TritonBuilder postProcessing(TritonHelper.PostProcessingControlsBuilder postProcessingBuilder)`
Sets post processing metadata for Pharos processing.

**Parameters**  
- `postProcessingBuilder` - `TritonHelper.PostProcessingControlsBuilder` - The post-processing configuration

**Returns**  
- `TritonBuilder` - The builder instance for chaining

**Example**
```apex
builder.postProcessing(new TritonHelper.PostProcessingControlsBuilder()
    .auditTrail(true)
    .stackTrace(true));
```

### Transaction Methods

#### `public TritonBuilder transactionId(String transactionId)`
Sets the transaction ID for grouping related logs.

**Parameters**  
- `transactionId` - `String` - The transaction ID to set

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder createIssue()`
Marks the log for issue creation in Pharos.

**Returns**  
- `TritonBuilder` - The builder instance for chaining

### Related Record Methods

#### `public TritonBuilder userId(Id userId)`
Sets the user ID associated with the log.

**Parameters**  
- `userId` - `Id` - The user's Salesforce ID

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder relatedObject(Id objectId)`
Adds a single related object ID to the log.

**Parameters**  
- `objectId` - `Id` - The Salesforce ID to relate

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder relatedObjects(List<Id> relatedObjectIds)`
Adds multiple related object IDs to the log.

**Parameters**  
- `relatedObjectIds` - `List<Id>` - The list of Salesforce IDs to relate

**Returns**  
- `TritonBuilder` - The builder instance for chaining

### Timing Methods

#### `public TritonBuilder createdTimestamp(Double timestamp)`
Sets the created timestamp for the log.

**Parameters**  
- `timestamp` - `Double` - The timestamp in milliseconds since epoch

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder duration(Decimal duration)`
Sets the duration value for performance tracking.

**Parameters**  
- `duration` - `Decimal` - The duration in milliseconds

**Returns**  
- `TritonBuilder` - The builder instance for chaining

### Integration Methods

#### `public TritonBuilder integrationPayload(HttpRequest request, HttpResponse response)`
Sets integration payload from HTTP request/response.

**Parameters**  
- `request` - `HttpRequest` - The HTTP request object
- `response` - `HttpResponse` - The HTTP response object

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder integrationPayload(RestRequest request, RestResponse response)`
Sets integration payload from REST request/response.

**Parameters**  
- `request` - `RestRequest` - The REST request object
- `response` - `RestResponse` - The REST response object

**Returns**  
- `TritonBuilder` - The builder instance for chaining

### Flow Methods

#### `public TritonBuilder interviewGuid(String guid)`
Sets the Flow interview GUID for flow tracking.

**Parameters**  
- `guid` - `String` - The Flow interview GUID

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder flowApiName(String apiName)`
Sets the Flow API name.

**Parameters**  
- `apiName` - `String` - The Flow API name

**Returns**  
- `TritonBuilder` - The builder instance for chaining

### Custom Methods

#### `public TritonBuilder attribute(String name, Object value)`
Sets a custom attribute on the log record.

**Parameters**  
- `name` - `String` - The field API name
- `value` - `Object` - The value to set

**Returns**  
- `TritonBuilder` - The builder instance for chaining

#### `public TritonBuilder limitInfo()`
Captures and sets all current transaction limits.

**Returns**  
- `TritonBuilder` - The builder instance for chaining

**Description**  
Captures current values and limits for:
- SOQL queries and rows
- DML statements and rows
- CPU time
- Heap size
- Callouts
- Email invocations
And more...

### Build Method

#### `public pharos__Log__c build()`
Builds and returns the final log record.

**Returns**  
- `pharos__Log__c` - The configured log record ready for insertion

**Throws**  
- `System.NullPointerException` - If required fields are missing

**Example**
```apex
pharos__Log__c log = new TritonBuilder()
    .category(TritonTypes.Category.Apex)
    .type(TritonTypes.Type.Backend)
    .area(TritonTypes.Area.Accounts)
    .level(TritonTypes.Level.INFO)
    .summary('Account processed')
    .build();
```

---
