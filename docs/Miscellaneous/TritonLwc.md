---
layout: default
---
# TritonLwc

Provides logging capabilities for Lightning Web Components (LWC).
This class exposes an AuraEnabled method that can be called from LWC to create log records
with customizable attributes like category, type, area, and level.

The class handles:
- Log creation with default INFO level if not specified
- Automatic transaction management
- Component context capture (name, function, action)
- Error details capture (message, stack trace, type)
- User and record ID validation
- Validation and fallback for category, area and log level enums
- Timestamp and duration tracking

## Methods
### `public static void saveComponentLogs(List<ComponentLog> componentLogs)`

`AURAENABLED`

Create component logs from LWC
Use this method to persist logs generated from LWC components

#### Parameters

|Param|Description|
|---|---|
|`componentLogs`|-- a collection of ComponentLog objects|

---
## Classes
### Component

A wrapper class for passing component info data from LWC

#### Properties

##### `public category` → `String`

`AURAENABLED` 

##### `public name` → `String`

`AURAENABLED` 

##### `public function` → `String`

`AURAENABLED` 

##### `public action` → `String`

`AURAENABLED` 

---

### ComponentLog

A wrapper class for passing log data from LWC

#### Properties

##### `public category` → `String`

`AURAENABLED` 

##### `public type` → `String`

`AURAENABLED` 

##### `public area` → `String`

`AURAENABLED` 

##### `public summary` → `String`

`AURAENABLED` 

##### `public details` → `String`

`AURAENABLED` 

##### `public totalTime` → `Decimal`

`AURAENABLED` 

##### `public userId` → `String`

`AURAENABLED` 

##### `public recordId` → `String`

`AURAENABLED` 

##### `public objectApiName` → `String`

`AURAENABLED` 

##### `public stack` → `String`

`AURAENABLED` 

##### `public error` → `Error`

`AURAENABLED` 

##### `public component` → `Component`

`AURAENABLED` 

##### `public transactionId` → `String`

`AURAENABLED` 

##### `public createdTimestamp` → `Decimal`

`AURAENABLED` 

##### `public level` → `String`

`AURAENABLED` 

##### `public duration` → `Decimal`

`AURAENABLED` 

---

### Error

A wrapper class for passing error log data from LWC

#### Properties

##### `public message` → `String`

`AURAENABLED` 

##### `public stack` → `String`

`AURAENABLED` 

##### `public type` → `String`

`AURAENABLED` 

---

---
