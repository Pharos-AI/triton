---
layout: default
---
# TritonFlow

Provides logging capabilities for Salesforce Flows and Process Builder.
This class exposes an invocable method that can be called directly from Flow Builder
to create log records with customizable attributes like category, type, area, and level.

The class handles:
- Log creation with default INFO level if not specified
- Automatic transaction management
- Custom field mapping through JSON
- Flow context capture (Interview GUID, Flow API Name)
- Validation and fallback for category and log level enums

## Fields

### `private INVALID_LOG_LEVEL` → `String`


### `private INVALID_CATEGORY` → `String`


---
## Methods
### `public static void log(List<FlowLog> flowLogs)`

`INVOCABLEMETHOD`

Invocable method, that can be called via flow.
Defaults to INFO log level

#### Parameters

|Param|Description|
|---|---|
|`flowLogs`|The list of FlowLog instances to save|

### `private static void processFlowLog(FlowLog flowLog)`
---
## Classes
### FlowLog

A wrapper class for passing log data from flow

#### Fields

##### `public category` → `String`

`INVOCABLEVARIABLE` 

##### `public type` → `String`

`INVOCABLEVARIABLE` 

##### `public area` → `String`

`INVOCABLEVARIABLE` 

##### `public summary` → `String`

`INVOCABLEVARIABLE` 

##### `public details` → `String`

`INVOCABLEVARIABLE` 

##### `public interviewGUID` → `String`

`INVOCABLEVARIABLE` 

##### `public flowApiName` → `String`

`INVOCABLEVARIABLE` 

##### `public level` → `String`

`INVOCABLEVARIABLE` 

##### `public additionalFields` → `String`

`INVOCABLEVARIABLE` 

---

---
